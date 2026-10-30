# Bugs and why-comments met along the way

## Contents

1. Fix every bug you find
2. Add missing why-comments

## 1. Fix every bug you find

Reading every file of a kind side by side surfaces real defects: a handler that skips its permission check, a client write that bypasses the offline queue, a script that exits 0 on failure, a test that asserts nothing. Fix each one, not just document it.

- **Verify first.** Try to refute the suspected bug: open the lines, the callers, the guards, the DB constraints and any test that pins the behaviour. A pinning test or a documented rule means the behaviour is a decision, not a bug. Fix only what survives.
- **Fix each confirmed bug as its own change, never inside a refactor diff.** One bug class per change (for example "validate body UUIDs" across every route that skips it). Each fix gets a test that fails before the fix and passes after, and a changelog line when behaviour changes.
- **Log only what cannot be fixed now** in the open-bug record, marked as found by `/unify-patterns` with the family id. That covers a fix that needs an owner decision (intended behaviour unclear, or the fix changes the wire for existing clients), a root cause in a package the project does not own, or a fix that needs a credential. A fixed bug is never an open-bug entry: its changelog line is the record.
- **Everything else** with no failure mode (an inconsistency outside the current family, dead code, a missing test, a doc that disagrees with the code, a rename that needs a decision) goes to the deferred-work record. Things only the owner can do go to the owner's task record.
- Follow each record's header format, and grep it (capped) first to avoid a duplicate.
- In discovery, a bug is a finding even when its family is "consistent".

## 2. Add missing why-comments

Every time a file is open for a change, check it for a missing critical comment and add it in the same change. Write the why, never the what.

A comment is critical when a careful reader would otherwise:

- "fix" something deliberate: a 404 that is not a 403, a skipped soft-delete filter, an online-only write that bypasses the offline queue, `set -u` without `-e`;
- not know where a number came from: a limit, TTL, timeout, debounce, retry count or page size;
- reorder steps whose order matters: audit before broadcast, claim before sweep in a purge, replay order;
- miss an external constraint: a vendor API quirk, store policy, browser bug, database behaviour or legal requirement;
- not know why a sanctioned exception exists (use the exception marker);
- wonder why two near-identical things both exist: two delete verbs, two guards, two scripts.

How to write it:

- One or two sentences at the point of use, leading with the reason. Example: `// Clamped, not rejected: old clients send limit=500 and must keep working.`
- No history narration ("used to", "previously", "no longer"). When a touched file has a history comment, rewrite it into a why, or delete it if no why remains.
- No restating the code, no session references, no dates unless the date is the reason.

Where to find the why, in order: surrounding code and its tests, then `git log -L` or `git blame` on the lines, then the doc that owns the subsystem, then past session transcripts (grep the symbol), then the owner.

Never invent a reason. If you cannot find it, leave the code uncommented and add a deferred-work entry: `<file:line> — reason unknown for <decision>; needs owner`.

Only touch files the current change already touches, and only add critical comments. Comments change no behaviour, so they may ride in a migration diff.
