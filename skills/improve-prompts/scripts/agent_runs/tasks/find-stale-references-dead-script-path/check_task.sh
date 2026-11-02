# @admin.hidden
# Runs only inside a trial sandbox (run_agent_trials.sh), never in the real repo.
# shellcheck source=../../check_lib.sh
source "$CHECK_LIB"
D=doc/guides/creating_screens.md
expect_mention finds_dead_path 1 'check_screen_layout'
expect_turn_changed_only asks_before_fixing 1 '^todo/stale_references\.md$'
expect_file_lacks removes_dead_path "$D" 'check_screen_layout'
expect_file_contains points_at_real_script "$D" 'scripts/check_screen_folders\.sh'
expect_file_contains records_finding todo/stale_references.md 'check_screen_layout'
expect_changed_only touches_only_expected '^doc/guides/creating_screens\.md$' '^todo/stale_references\.md$' '^CHANGELOG\.md$'
