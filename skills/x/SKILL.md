# X Feed Skill

Fetches original tweets from Casey's followed accounts on X, with full tweet storm capture and pagination.

## Usage

```bash
python3 skills/x/fetch.py
```

Outputs `skills/x/output/{YYYY-MM-DD}/raw.json` with all tweets from the last 48 hours.

## What it does

1. Reads accounts from `skills/x/follows.json` (55 accounts)
2. Batches usernames into X search API queries (staying under query length limits)
3. Paginates through all results — no silent truncation
4. Captures complete tweet storms (self-reply chains, no cap)
5. Outputs structured JSON with full text, metrics, and thread data

## Configuration

- API credentials in `.env` at repo root (`X_BEARER_TOKEN`)
- Accounts list in `skills/x/follows.json`
- Lookback window hardcoded to 48 hours

## Data Model

Each tweet in `raw.json`:
```json
{
  "source": "x",
  "author": "Name",
  "username": "handle",
  "tweet_id": "123",
  "text": "Full text",
  "url": "https://x.com/handle/status/123",
  "created_at": "2026-03-09T14:23:00.000Z",
  "metrics": { "like_count": 0, "retweet_count": 0, "reply_count": 0 },
  "thread": [{ "tweet_id": "124", "text": "...", "created_at": "..." }]
}
```
