# @admin.hidden
# Runs only inside a trial sandbox (run_agent_trials.sh), never in the real repo.
# shellcheck source=../../check_lib.sh
source "$CHECK_LIB"
expect_changed_only read_only
expect_mention flags_raw_key 1 'group_id'
expect_mention names_field_names 1 'FieldNames'
expect_mention has_summary 1 '^#+ *Summary'
