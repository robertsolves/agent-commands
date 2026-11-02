# @admin.hidden
# Runs only inside a trial sandbox (run_agent_trials.sh), never in the real repo.
# Points a doc at a script that does not exist (the real one is check_screen_folders.sh).
set -euo pipefail
f=doc/guides/creating_screens.md
grep -q 'scripts/check_screen_folders.sh' "$f"
python3 -I - "$f" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
open(p, 'w').write(s.replace('check_screen_folders.sh', 'check_screen_layout.sh', 1))
PY
grep -q 'check_screen_layout.sh' "$f"
