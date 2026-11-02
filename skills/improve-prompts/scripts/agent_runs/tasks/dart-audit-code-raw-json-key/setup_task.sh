# @admin.hidden
# Runs only inside a trial sandbox (run_agent_trials.sh), never in the real repo.
# Plants a raw JSON key where a generated FieldNames constant belongs.
set -euo pipefail
cat >>shared/lib/src/items/items_window.dart <<'DART'

/// The group an items-window request is scoped to, read from its JSON body.
String? itemsWindowGroupIdOf(Map<String, Object?> json) =>
    json['group_id'] as String?;
DART
