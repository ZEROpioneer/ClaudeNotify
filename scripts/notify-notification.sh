#!/bin/bash
QUEUE_DIR="$HOME/.claude/notify-queue"
mkdir -p "$QUEUE_DIR"
j=$(cat)
sid=$(echo "$j"|sed 's/.*"session_id":"\([^"]*\)".*/\1/')
[ "$sid" = "$j" ] && sid=""
echo "{\"type\":\"notification\",\"projectDir\":\"$PWD\",\"sessionId\":\"$sid\"}" > "$QUEUE_DIR/notify-$(date +%s%N).json"
