#!/bin/bash
# rebuild-index.sh — Regenerate docs/index.html from published pages
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCS_DIR="$REPO_ROOT/docs"
PAGES_DIR="$DOCS_DIR/pages"

# Build page list (newest first by filename)
PAGE_LIST=""
if [ -d "$PAGES_DIR" ] && [ "$(ls -A "$PAGES_DIR" 2>/dev/null)" ]; then
  for f in $(ls -r "$PAGES_DIR"/*.html 2>/dev/null); do
    FNAME="$(basename "$f")"
    # Extract title from the HTML <title> tag
    TITLE="$(sed -n 's/.*<title>\(.*\) — Phez<\/title>.*/\1/p' "$f")"
    [ -z "$TITLE" ] && TITLE="$FNAME"
    # Extract date from the meta div
    PDATE="$(sed -n 's/.*<div class="meta">\([0-9-]*\).*/\1/p' "$f")"
    [ -z "$PDATE" ] && PDATE="—"
    PAGE_LIST="${PAGE_LIST}    <li><span class=\"date\">${PDATE}</span> <a href=\"pages/${FNAME}\">${TITLE}</a></li>
"
  done
fi

if [ -z "$PAGE_LIST" ]; then
  PAGE_LIST="    <li class=\"empty\">No pages published yet.</li>
"
fi

cat > "$DOCS_DIR/index.html" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Phez</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      max-width: 600px;
      margin: 80px auto;
      padding: 0 20px;
      background: #0d1117;
      color: #e6edf3;
    }
    h1 { color: #58a6ff; }
    p { line-height: 1.6; color: #8b949e; }
    .status { color: #3fb950; font-weight: bold; }
    h2 { color: #58a6ff; margin-top: 2em; }
    ul { list-style: none; padding: 0; }
    li { padding: 8px 0; border-bottom: 1px solid #21262d; }
    li.empty { color: #8b949e; border: none; }
    a { color: #58a6ff; text-decoration: none; }
    a:hover { text-decoration: underline; }
    .date { color: #8b949e; font-size: 0.85em; margin-right: 8px; }
  </style>
</head>
<body>
  <h1>Phez</h1>
  <p>Personal AI agent running on an always-on Mac, accessed remotely via SSH.</p>
  <p class="status">Status: Online</p>
  <h2>Published</h2>
  <ul>
${PAGE_LIST}  </ul>
</body>
</html>
HTMLEOF

echo "Index rebuilt: $DOCS_DIR/index.html"
