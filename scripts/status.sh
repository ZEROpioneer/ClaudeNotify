#!/bin/bash
j=$(cat)
n=$(echo "$j"|sed 's/.*"cwd":"\([^"]*\)".*/\1/'|sed 's/.*[/\]//')
m=$(echo "$j"|sed 's/.*"display_name":"\([^"]*\)".*/\1/')
p=$(echo "$j"|sed 's/.*"remaining_percentage":\([0-9]*\).*/\1/')
dir=$(echo "$j"|sed 's/.*"cwd":"\([^"]*\)".*/\1/')
dir_unix="${dir//\\//}"

sid=$(echo "$j"|sed 's/.*"session_id":"\([^"]*\)".*/\1/')

# Auto-detect Python: $PYTHON_PATH > python3 > python > common paths
if [ -n "$PYTHON_PATH" ] && command -v "$PYTHON_PATH" >/dev/null 2>&1; then
  PY="$PYTHON_PATH"
elif command -v python3 >/dev/null 2>&1; then
  PY="python3"
elif command -v python >/dev/null 2>&1; then
  PY="python"
else
  for py_path in \
    "$HOME/AppData/Local/Programs/Python/Python314/python.exe" \
    "$HOME/AppData/Local/Programs/Python/Python313/python.exe" \
    "$HOME/AppData/Local/Programs/Python/Python312/python.exe" \
    "/c/Python314/python.exe" \
    "/c/Python313/python.exe"; do
    if [ -f "$py_path" ]; then PY="$py_path"; break; fi
  done
fi

if [ -z "$PY" ]; then
  echo " $n | $m | $p% "
  exit 0
fi

names_file="$dir_unix/.claude/session-names.json"

# priority 1: session_name from JSON (/rename command) — sync to file for notify.ps1
sname=$(echo "$j"|grep -o '"session_name":"[^"]*"' 2>/dev/null|sed 's/"session_name":"//;s/"$//')
if [ -n "$sname" ] && [ "$sname" != "null" ] && [ -n "$sid" ] && [ "$sid" != "$j" ]; then
  $PY -c "
import json
names = {}
try:
    with open(r'$names_file', 'r', encoding='utf-8') as f:
        names = json.load(f)
except: pass
if names.get('$sid') != '$sname':
    names['$sid'] = '$sname'
    with open(r'$names_file', 'w', encoding='utf-8') as f:
        json.dump(names, f, ensure_ascii=False)
"
  echo " $n | $m | $p% | $sname "
  exit 0
fi

# check pending rename
pending_file="$dir_unix/.claude/pending-name.txt"
if [ -f "$pending_file" ]; then
  new_name=$(head -1 "$pending_file")
  if [ -n "$new_name" ] && [ -n "$sid" ] && [ "$sid" != "$j" ]; then
    if [ -f "$names_file" ]; then
      $PY -c "
import json
names = {}
try:
    with open(r'$names_file', 'r', encoding='utf-8') as f:
        names = json.load(f)
except:
    names = {}
names['$sid'] = '$new_name'
with open(r'$names_file', 'w', encoding='utf-8') as f:
    json.dump(names, f, ensure_ascii=False)
"
    else
      echo "{\"$sid\": \"$new_name\"}" > "$names_file"
    fi
  fi
  rm -f "$pending_file"
fi

# priority 2: per-session name from session-names.json
if [ -n "$sid" ] && [ "$sid" != "$j" ] && [ -f "$names_file" ]; then
  sname=$($PY -c "
import json
try:
    with open(r'$names_file', 'r', encoding='utf-8') as f:
        names = json.load(f)
    print(names.get('$sid', ''))
except:
    pass
")
fi

# priority 3: project-level session-name.txt (fallback)
if [ -z "$sname" ]; then
  sname=$(head -1 "$dir/.claude/session-name.txt" 2>/dev/null)
fi

if [ -n "$sname" ] && [ "$sname" != "null" ]; then
  echo " $n | $m | $p% | $sname "
else
  echo " $n | $m | $p% "
fi
