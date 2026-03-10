#!/usr/bin/env python3
"""X Feed Skill — Fetch all original tweets from followed accounts with full storm capture.

Usage: python3 skills/x/fetch.py

Outputs: skills/x/output/{YYYY-MM-DD}/raw.json
"""

import json
import os
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

import requests
from dotenv import load_dotenv

SKILL_DIR = Path(__file__).parent
REPO_ROOT = SKILL_DIR.parent.parent
FOLLOWS_PATH = SKILL_DIR / "follows.json"
OUTPUT_ROOT = SKILL_DIR / "output"
LOOKBACK_HOURS = 48
MAX_QUERY_LEN = 512
API_BASE = "https://api.x.com/2"


def load_env():
    load_dotenv(REPO_ROOT / ".env", override=True)
    token = os.getenv("X_BEARER_TOKEN")
    if not token:
        print("Error: X_BEARER_TOKEN not set in .env")
        sys.exit(1)
    return token


def load_accounts():
    with open(FOLLOWS_PATH) as f:
        return json.load(f)["accounts"]


def batch_usernames(accounts):
    """Batch usernames into groups that fit within X search query length limits."""
    batches = []
    current = []
    # Query structure: (from:x OR from:y) -is:retweet
    suffix = " -is:retweet"

    for acct in accounts:
        candidate = current + [acct["username"]]
        query = "(" + " OR ".join(f"from:{u}" for u in candidate) + ")" + suffix
        if len(query) > MAX_QUERY_LEN and current:
            batches.append(current)
            current = [acct["username"]]
        else:
            current = candidate

    if current:
        batches.append(current)
    return batches


def api_request(endpoint, params, bearer_token):
    """Make an X API request with rate limit handling."""
    headers = {"Authorization": f"Bearer {bearer_token}"}
    resp = requests.get(f"{API_BASE}/{endpoint}", headers=headers, params=params)

    if resp.status_code == 429:
        reset = int(resp.headers.get("x-rate-limit-reset", 0))
        wait = max(reset - int(time.time()), 10)
        print(f"  Rate limited. Waiting {wait}s...")
        time.sleep(wait)
        resp = requests.get(f"{API_BASE}/{endpoint}", headers=headers, params=params)

    resp.raise_for_status()
    return resp.json()


def fetch_batch(usernames, bearer_token, since):
    """Fetch all tweets for a batch of usernames, paginating through all results."""
    query = "(" + " OR ".join(f"from:{u}" for u in usernames) + ") -is:retweet"

    params = {
        "query": query,
        "max_results": 100,
        "start_time": since.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "tweet.fields": "created_at,text,note_tweet,public_metrics,author_id,conversation_id,referenced_tweets",
        "expansions": "author_id",
        "user.fields": "username,name",
    }

    all_tweets = []
    all_users = {}
    page = 0

    while True:
        page += 1
        response = api_request("tweets/search/recent", params, bearer_token)

        # Collect users from includes
        for user in response.get("includes", {}).get("users", []):
            all_users[user["id"]] = user

        tweets = response.get("data", [])
        all_tweets.extend(tweets)

        # Check for next page
        next_token = response.get("meta", {}).get("next_token")
        if not next_token:
            break

        params["next_token"] = next_token

    return all_tweets, all_users


def is_self_reply(tweet, users):
    """Check if a tweet is a reply to someone other than the author."""
    refs = tweet.get("referenced_tweets", [])
    if not refs:
        return False
    # Has a "replied_to" reference — it's a reply
    for ref in refs:
        if ref["type"] == "replied_to":
            return True
    return False


def filter_non_self_replies(tweets, users):
    """Keep original tweets and self-replies only. Remove replies to other users."""
    # Group tweets by author
    author_tweet_ids = {}
    for tweet in tweets:
        author_id = tweet["author_id"]
        author_tweet_ids.setdefault(author_id, set()).add(tweet["id"])

    # Build conversation_id -> author_id map from original tweets (no referenced_tweets)
    convo_author = {}
    for tweet in tweets:
        if not tweet.get("referenced_tweets"):
            convo_author[tweet.get("conversation_id", tweet["id"])] = tweet["author_id"]

    filtered = []
    for tweet in tweets:
        refs = tweet.get("referenced_tweets", [])
        if not refs:
            # Original tweet — keep
            filtered.append(tweet)
            continue

        # It's a reply. Keep only if it's a self-reply (same author as conversation starter)
        convo_id = tweet.get("conversation_id", "")
        if convo_id in convo_author and convo_author[convo_id] == tweet["author_id"]:
            filtered.append(tweet)

    return filtered


def fetch_thread(conversation_id, username, bearer_token):
    """Fetch the full self-reply chain for a conversation, with pagination."""
    query = f"conversation_id:{conversation_id} from:{username}"
    params = {
        "query": query,
        "max_results": 100,
        "tweet.fields": "created_at,text,note_tweet",
    }

    all_replies = []
    while True:
        try:
            response = api_request("tweets/search/recent", params, bearer_token)
        except Exception:
            break  # Thread enrichment is best-effort

        data = response.get("data", [])
        all_replies.extend(data)

        next_token = response.get("meta", {}).get("next_token")
        if not next_token:
            break
        params["next_token"] = next_token

    return all_replies


def enrich_threads(items, bearer_token):
    """Fetch complete self-reply chains for tweets that have replies."""
    candidates = [i for i in items if i.get("metrics", {}).get("reply_count", 0) > 0]
    if not candidates:
        return

    print(f"  Enriching {len(candidates)} potential threads...")
    enriched = 0

    for item in candidates:
        tweet_id = item["tweet_id"]
        username = item["username"]

        try:
            replies = fetch_thread(tweet_id, username, bearer_token)
            # Filter out the original tweet, sort by created_at
            thread_tweets = [t for t in replies if t["id"] != tweet_id]
            thread_tweets.sort(key=lambda t: t.get("created_at", ""))

            if thread_tweets:
                item["thread"] = [
                    {
                        "tweet_id": t["id"],
                        "text": t.get("note_tweet", {}).get("text") or t["text"],
                        "created_at": t.get("created_at", ""),
                    }
                    for t in thread_tweets
                ]
                enriched += 1
        except Exception:
            pass  # Best-effort

    print(f"  Enriched {enriched} threads")


def parse_tweets(tweets, users):
    """Convert raw API tweets into the output data model."""
    items = []
    for tweet in tweets:
        author_info = users.get(tweet["author_id"], {})
        username = author_info.get("username", "unknown")
        full_text = tweet.get("note_tweet", {}).get("text") or tweet["text"]

        items.append({
            "source": "x",
            "author": author_info.get("name", "Unknown"),
            "username": username,
            "tweet_id": tweet["id"],
            "text": full_text,
            "url": f"https://x.com/{username}/status/{tweet['id']}",
            "created_at": tweet["created_at"],
            "metrics": tweet.get("public_metrics", {}),
        })

    return items


def deduplicate(items):
    """Remove duplicate tweets by tweet_id."""
    seen = set()
    unique = []
    for item in items:
        tid = item["tweet_id"]
        if tid not in seen:
            seen.add(tid)
            unique.append(item)
    return unique


def main():
    bearer_token = load_env()
    accounts = load_accounts()
    batches = batch_usernames(accounts)
    since = datetime.now(timezone.utc) - timedelta(hours=LOOKBACK_HOURS)

    print(f"Fetching tweets from {len(accounts)} accounts (last {LOOKBACK_HOURS}h)")
    print(f"Batched into {len(batches)} API query groups")

    all_tweets = []
    all_users = {}

    for i, batch in enumerate(batches):
        print(f"  Batch {i+1}/{len(batches)} ({len(batch)} accounts)...")
        try:
            tweets, users = fetch_batch(batch, bearer_token, since)
            all_tweets.extend(tweets)
            all_users.update(users)
            print(f"    Got {len(tweets)} tweets")
        except requests.exceptions.HTTPError as e:
            print(f"    Batch failed ({e}), skipping...")
        except Exception as e:
            print(f"    Batch failed ({e}), skipping...")

    if not all_tweets:
        print("No tweets fetched. Check your credentials and try again.")
        return

    # Filter out replies to other users (keep originals + self-replies)
    print(f"\nTotal raw tweets: {len(all_tweets)}")
    filtered = filter_non_self_replies(all_tweets, all_users)
    print(f"After filtering non-self-replies: {len(filtered)}")

    # Parse into output format
    items = parse_tweets(filtered, all_users)
    items = deduplicate(items)
    print(f"After dedup: {len(items)}")

    # Enrich threads
    enrich_threads(items, bearer_token)

    # Sort by created_at descending
    items.sort(key=lambda x: x.get("created_at", ""), reverse=True)

    # Write output
    date_str = datetime.now().strftime("%Y-%m-%d")
    run_dir = OUTPUT_ROOT / date_str
    run_dir.mkdir(parents=True, exist_ok=True)

    raw_path = run_dir / "raw.json"
    with open(raw_path, "w") as f:
        json.dump(items, f, indent=2, default=str)

    print(f"\nSaved {len(items)} tweets to {raw_path}")


if __name__ == "__main__":
    main()
