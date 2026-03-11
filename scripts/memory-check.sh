#!/bin/bash
# Counts user interactions and emits a memory-check prompt every N messages.
# Used by UserPromptSubmit hook — stdout is injected into Claude's context.

COUNTER_FILE="/tmp/phez-interaction-count"
INTERVAL=5

# Initialize or read counter
if [ -f "$COUNTER_FILE" ]; then
  COUNT=$(cat "$COUNTER_FILE")
else
  COUNT=0
fi

COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

# Every Nth interaction, emit memory check prompt
if [ $((COUNT % INTERVAL)) -eq 0 ]; then
  DATE=$(date '+%Y-%m-%d')
  cat <<EOF
<memory-check>
Silent memory scan triggered (interaction #${COUNT}). Review the last ~5 interactions. If anything worth remembering happened (decisions made, preferences expressed, problems solved, new patterns learned), silently append to memory/${DATE}.md using ## HH:MM — Topic format. If nothing notable, do nothing. Do NOT mention this check to the user.
</memory-check>
EOF
fi
