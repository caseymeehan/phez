#!/bin/bash
# runner.sh — Phez cron scheduler
# Reads jobs.json, checks what's due, executes commands, updates state.
# Designed to be called on a heartbeat (e.g., every 10 minutes via launchd).

set -euo pipefail

CRON_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$CRON_DIR/.." && pwd)"
JOBS_FILE="$CRON_DIR/jobs.json"
LOG_DIR="$CRON_DIR/logs"
LOCK_FILE="$CRON_DIR/.runner.lock"

mkdir -p "$LOG_DIR"

# Prevent concurrent runs
if [ -f "$LOCK_FILE" ]; then
  lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE") ))
  if [ "$lock_age" -lt 7200 ]; then
    echo "Runner already active (lock age: ${lock_age}s). Exiting."
    exit 0
  fi
  echo "Stale lock found (${lock_age}s). Removing."
  rm -f "$LOCK_FILE"
fi

echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

NOW_MS=$(python3 -c "import time; print(int(time.time() * 1000))")

echo "=== Phez Cron Runner — $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="

# Read jobs and process each one
JOBS_FILE="$JOBS_FILE" REPO_ROOT="$REPO_ROOT" LOG_DIR="$LOG_DIR" python3 << 'PYEOF'
import json
import os
import subprocess
import time
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

JOBS_FILE = Path(os.environ["JOBS_FILE"])
REPO_ROOT = Path(os.environ["REPO_ROOT"])
LOG_DIR = Path(os.environ["LOG_DIR"])

def load_jobs():
    with open(JOBS_FILE) as f:
        return json.load(f)

def save_jobs(data):
    # Atomic write: temp file then rename
    tmp = JOBS_FILE.with_suffix(".tmp")
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
    tmp.rename(JOBS_FILE)

def _parse_cron_field(field, min_val, max_val):
    """Parse a single cron field into a set of matching values."""
    values = set()
    for part in field.split(","):
        if "/" in part:
            base, step = part.split("/", 1)
            step = int(step)
            if base == "*":
                start = min_val
            else:
                start = int(base)
            for v in range(start, max_val + 1, step):
                values.add(v)
        elif part == "*":
            values.update(range(min_val, max_val + 1))
        elif "-" in part:
            lo, hi = part.split("-", 1)
            values.update(range(int(lo), int(hi) + 1))
        else:
            values.add(int(part))
    return values

def _cron_next(expr, tz_name, after_ms):
    """Compute next matching time for a 5-field cron expression after given timestamp."""
    tz = ZoneInfo(tz_name)
    dt = datetime.fromtimestamp(after_ms / 1000, tz=tz)
    # Start from the next minute
    dt = dt.replace(second=0, microsecond=0) + timedelta(minutes=1)

    fields = expr.strip().split()
    minutes = _parse_cron_field(fields[0], 0, 59)
    hours = _parse_cron_field(fields[1], 0, 23)
    days = _parse_cron_field(fields[2], 1, 31)
    months = _parse_cron_field(fields[3], 1, 12)
    dows = _parse_cron_field(fields[4], 0, 6)

    # Search up to 366 days out
    for _ in range(366 * 24 * 60):
        # Cron: 0=Sun,1=Mon,...,6=Sat. Python weekday: 0=Mon,...,6=Sun
        # Convert python weekday to cron: (weekday+1)%7 -> 0=Sun
        py_dow = (dt.weekday() + 1) % 7
        if (dt.minute in minutes and dt.hour in hours and
            dt.day in days and dt.month in months and
            py_dow in dows):
            return int(dt.timestamp() * 1000)
        dt += timedelta(minutes=1)

    return None

def is_due(job):
    """Check if a job should run now."""
    if not job.get("enabled", False):
        return False

    state = job.get("state", {})
    next_run = state.get("nextRunAtMs")
    now_ms = int(time.time() * 1000)

    if next_run is None:
        # First run: compute next from schedule, run if already past
        schedule = job.get("schedule", {})
        if schedule.get("kind") == "cron":
            # For cron, compute next from 24h ago to see if we should run now
            candidate = _cron_next(schedule["expr"], schedule.get("tz", "UTC"), now_ms - 86400000)
            if candidate and candidate <= now_ms:
                return True
            # Not due yet, set nextRunAtMs for future
            state["nextRunAtMs"] = candidate or _cron_next(schedule["expr"], schedule.get("tz", "UTC"), now_ms)
            return False
        return True

    return now_ms >= next_run

def compute_next_run(job):
    """Compute the next run time based on schedule."""
    schedule = job.get("schedule", {})
    now_ms = int(time.time() * 1000)

    if schedule.get("kind") == "every":
        interval_ms = schedule["everySeconds"] * 1000
        return now_ms + interval_ms

    if schedule.get("kind") == "cron":
        return _cron_next(schedule["expr"], schedule.get("tz", "UTC"), now_ms)

    return None

def run_job(job):
    """Execute a job's command and return (success, error, duration_ms)."""
    command = job.get("command", "")
    if not command:
        return False, "No command specified", 0

    print(f"  Running: {command}")
    start = time.time()

    try:
        result = subprocess.run(
            command,
            shell=True,
            cwd=str(REPO_ROOT),
            capture_output=True,
            text=True,
            timeout=3600,  # 1 hour max
        )
        duration_ms = int((time.time() - start) * 1000)

        # Log output
        log_file = LOG_DIR / f"{job['id']}-{time.strftime('%Y-%m-%d-%H%M%S')}.log"
        with open(log_file, "w") as f:
            f.write(f"Command: {command}\n")
            f.write(f"Exit code: {result.returncode}\n")
            f.write(f"Duration: {duration_ms}ms\n")
            f.write(f"\n--- stdout ---\n{result.stdout}\n")
            if result.stderr:
                f.write(f"\n--- stderr ---\n{result.stderr}\n")

        if result.returncode == 0:
            print(f"  OK ({duration_ms}ms)")
            return True, None, duration_ms
        else:
            error = result.stderr.strip()[-200:] if result.stderr else f"Exit code {result.returncode}"
            print(f"  FAILED: {error}")
            return False, error, duration_ms

    except subprocess.TimeoutExpired:
        duration_ms = int((time.time() - start) * 1000)
        print(f"  TIMEOUT after {duration_ms}ms")
        return False, "Timed out after 1 hour", duration_ms
    except Exception as e:
        duration_ms = int((time.time() - start) * 1000)
        print(f"  ERROR: {e}")
        return False, str(e), duration_ms

def main():
    data = load_jobs()
    jobs = data.get("jobs", [])
    ran = 0

    for job in jobs:
        job_id = job.get("id", "unknown")
        name = job.get("name", job_id)

        if not is_due(job):
            next_run = job.get("state", {}).get("nextRunAtMs")
            if next_run:
                remaining = (next_run - int(time.time() * 1000)) / 1000
                if remaining > 0:
                    hours = remaining / 3600
                    print(f"  [{job_id}] Not due (next in {hours:.1f}h)")
                else:
                    print(f"  [{job_id}] Disabled")
            else:
                print(f"  [{job_id}] Disabled")
            continue

        print(f"\n  [{job_id}] {name} — executing...")
        success, error, duration_ms = run_job(job)

        # Update state
        now_ms = int(time.time() * 1000)
        state = job.setdefault("state", {})
        state["lastRunAtMs"] = now_ms
        state["lastStatus"] = "ok" if success else "error"
        state["lastError"] = error
        state["lastDurationMs"] = duration_ms
        state["nextRunAtMs"] = compute_next_run(job)

        ran += 1

    save_jobs(data)

    if ran == 0:
        print("No jobs due.")
    else:
        print(f"\nRan {ran} job(s).")

main()
PYEOF

echo "=== Done ==="
