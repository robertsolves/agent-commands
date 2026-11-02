# @admin.hidden
# Runs only inside a trial sandbox (run_agent_trials.sh), never in the real repo.
# Plants an unused, documented helper the dead-code sweep should find.
set -euo pipefail
cat >>shared/lib/src/achievements/streak_repair_limits.dart <<'DART'

/// How many streak repairs a profile has left this month, after
/// [usedThisMonth] of its [allowedPerMonth] were spent. Never below zero.
int streakRepairsLeftAfter(int usedThisMonth, int allowedPerMonth) {
  final left = allowedPerMonth - usedThisMonth;
  return left < 0 ? 0 : left;
}
DART
