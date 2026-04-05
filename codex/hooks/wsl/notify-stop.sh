#!/bin/bash
# Notify when Codex finishes a task
input="$(cat)"

transcript_path="$(
  printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("transcript_path",""))' 2>/dev/null
)"

if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  if python3 - "$transcript_path" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    first_line = fh.readline()

if not first_line:
    raise SystemExit(1)

payload = json.loads(first_line).get("payload", {})
source = payload.get("source", {})
raise SystemExit(0 if isinstance(source, dict) and "subagent" in source else 1)
PY
  then
    exit 0
  fi
fi

pwsh.exe -Command "Import-Module BurntToast; New-BurntToastNotification -Text 'Codex', 'Task finished'" 2>/dev/null
