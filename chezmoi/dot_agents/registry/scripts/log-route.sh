#!/usr/bin/env bash
# Append one capability-routing outcome line to agents-routing-log.md (top of journal).
# Part of the local-first cascade self-learning loop (see CAPABILITY-PLANNING.md).
#
# Usage:
#   log-route.sh "<task class>" "<capability used>" "<✅|⚠️|❌>" "<note: local=… fell_back=… adopted=…>"
# Example:
#   log-route.sh "react hooks bug" "react-reviewer" "✅" "local=strong fell_back=no adopted=–"
set -euo pipefail

LOG="${HOME}/.claude/references/agents-routing-log.md"
if [ $# -lt 4 ]; then
  echo "usage: log-route.sh <task class> <capability> <✅|⚠️|❌> <note>" >&2
  exit 2
fi

D="$(date +%F)"
LINE="$D | $1 | $2 | $3 | $4"
MARK="<!-- append below, newest on top -->"

python3 - "$LOG" "$MARK" "$LINE" <<'PY'
import sys
path, mark, line = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding="utf-8") as fh:
    s = fh.read()
i = s.find(mark)
if i == -1:                       # marker missing -> append at end
    s = s.rstrip() + "\n\n" + line + "\n"
else:                              # insert right after marker (newest on top)
    j = i + len(mark)
    s = s[:j] + "\n\n" + line + s[j:]
with open(path, "w", encoding="utf-8") as fh:
    fh.write(s)
print("logged:", line)
PY
