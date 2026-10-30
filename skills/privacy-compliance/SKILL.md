---
name: privacy-compliance
description: The privacy and user-safety baseline a change must keep — every personal-data field has a purpose and is in the user's export and deletion, kept out of logs, and retained only as long as promised; user rights work as product features; children's data, consent on every sign-up path, processors, AI input, payments and user content are handled as the published policy says. Use when adding or changing a field or table that holds data about a person, a sign-up or consent path, an export, deletion or purge, logging, a third-party SDK or API, child profiles, AI inputs, payments, user content, or the privacy policy or terms. Do not use for a whole-project sweep — use find-compliance-issues, which checks against this baseline. Not legal advice.
---

# Privacy compliance

**State no legal requirement from memory.** The project's compliance doc holds the
regimes, deadlines and counsel decisions. When it is silent, read the law or store
policy text, or mark the point `needs-counsel` and put the exact question in the
owner's queue.

Read the project's agent guide first. It names the compliance doc and its launch
checklist, the published legal documents, the schema source, the export, deletion and
consent docs, any legal-version check, and where the owner's tasks go.

## What does the change touch? (decide first)

    a field or table holding data about a person?
        → all five: inventory it in the compliance doc with its purpose; include it in
          the export; make deletion and purge reach it; check the policy lists the
          category; keep it out of logs
    a third-party SDK or API that receives user data?
        → add it to the policy's processor list and the compliance doc; transfer
          terms → owner's queue
    a sign-up, invite, single-sign-on or agent path?
        → write a consent record on it; re-consent when the document version changes
    children or child profiles?
        → stop: read the compliance doc's children section; anything it doesn't answer → needs-counsel
    a published promise (policy or terms)?
        → the project's document-version process and legal-version check
    none of these?
        → this skill does not apply

## The baseline

- Collect only what a feature needs; each field has a stated purpose.
- Rights are product features: export, correction, in-app deletion with no support
  call, objection, and withdrawing consent as easily as giving it.
- Deletion reaches every table, every processor, and backups on the stated schedule.
- Each retention period in the policy has a purge job that keeps it, pinned by a test.
- Logs, errors and analytics carry no personal data, tokens or secrets.
- Children: age captured at profile creation, a parental-consent path, no profiling or
  marketing aimed at them.
- AI: input sent to a model provider is disclosed; output is a draft a person approves.
- Payments: card data never touches our servers; paid tiers are not marketed to children.
- User content: a report path and a takedown process; deleting a creator purges their
  personal data and leaves others' copies.
- A breach runbook exists with a named owner.
- App stores: privacy labels match what the code collects; read the store's current
  account-deletion policy.

## Done means

- A table in your report: each personal field touched → export / deletion / policy /
  logs, each with its `file:line`.
- Export and deletion tests cover the new field; quote the tally.
- A published document changed: the legal-version check passes; quote it.
- Each `needs-counsel` point is in the owner's queue with its question.
