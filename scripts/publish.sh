#!/bin/bash
# publish.sh — Convert a markdown file to HTML and publish to GitHub Pages
# Usage: ./scripts/publish.sh <markdown-file> [slug]
# Example: ./scripts/publish.sh memory/x/2026-03-09.md x-digest-2026-03-09

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCS_DIR="$REPO_ROOT/docs"
PAGES_DIR="$DOCS_DIR/pages"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <markdown-file> [slug]"
  exit 1
fi

MD_FILE="$1"
if [ ! -f "$MD_FILE" ]; then
  echo "Error: File not found: $MD_FILE"
  exit 1
fi

# Generate slug from filename if not provided
if [ $# -ge 2 ]; then
  SLUG="$2"
else
  SLUG="$(basename "$MD_FILE" .md)"
fi

OUTPUT="$PAGES_DIR/$SLUG.html"
TITLE="$(head -1 "$MD_FILE" | sed 's/^#* *//')"
DATE="$(date +%Y-%m-%d)"

# Simple markdown to HTML conversion (no dependencies)
convert_md() {
  awk '
  BEGIN { in_code=0; in_list=0 }
  /^```/ {
    if (in_code) { print "</code></pre>"; in_code=0 }
    else { print "<pre><code>"; in_code=1 }
    next
  }
  in_code { gsub(/&/, "\\&amp;"); gsub(/</, "\\&lt;"); gsub(/>/, "\\&gt;"); print; next }
  /^$/ {
    if (in_list) { print "</ul>"; in_list=0 }
    next
  }
  /^### / { sub(/^### /, ""); print "<h3>" $0 "</h3>"; next }
  /^## /  { sub(/^## /, "");  print "<h2>" $0 "</h2>"; next }
  /^# /   { sub(/^# /, "");   print "<h1>" $0 "</h1>"; next }
  /^- / {
    if (!in_list) { print "<ul>"; in_list=1 }
    sub(/^- /, "")
    print "<li>" $0 "</li>"
    next
  }
  { print "<p>" $0 "</p>" }
  END { if (in_list) print "</ul>" }
  '
}

# Build HTML
BODY="$(convert_md < "$MD_FILE")"

cat > "$OUTPUT" << HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${TITLE} — Phez</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      max-width: 700px;
      margin: 60px auto;
      padding: 0 20px;
      background: #0d1117;
      color: #e6edf3;
    }
    h1 { color: #58a6ff; }
    h2 { color: #58a6ff; margin-top: 1.5em; }
    h3 { color: #79c0ff; }
    p { line-height: 1.6; color: #c9d1d9; }
    li { line-height: 1.6; color: #c9d1d9; }
    pre { background: #161b22; padding: 16px; border-radius: 6px; overflow-x: auto; }
    code { color: #e6edf3; font-size: 0.9em; }
    a { color: #58a6ff; text-decoration: none; }
    a:hover { text-decoration: underline; }
    .meta { color: #8b949e; font-size: 0.9em; margin-bottom: 2em; }
    .back { margin-top: 3em; }
  </style>
</head>
<body>
  <div class="meta">${DATE} · <a href="../index.html">← Phez</a></div>
${BODY}
  <div class="back"><a href="../index.html">← Back to index</a></div>
</body>
</html>
HTMLEOF

echo "Published: $OUTPUT"

# Rebuild index
"$REPO_ROOT/scripts/rebuild-index.sh"
