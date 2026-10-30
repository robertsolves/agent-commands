---
name: production-readiness
description: Checks whether ONE change, feature or handler is safe for real users ("is this ready to ship?") against the standard — server-side authorization, secrets, abuse and cost limits, safe migrations, idempotent retries, backups that restore, release checks, health checks and rollback, visibility, an owner — plus how to change something already live and the questions every release answers. Use when building or changing anything that touches auth, money, personal data, a migration, the deploy pipeline, a background job, a webhook or external call, limits or a dev-only switch, or when asked whether a change, endpoint or feature is ready to ship. Do not use for a GO / NO-GO verdict on launching the whole project — use check-production-readiness, which checks against this standard — or for one release's deploy procedure — use the project's deploy command.
---

# Production readiness

Read the project's agent guide first. It names the readiness checklist (the record of
each decision and its evidence), the production-safety doc (what is dangerous once real
users exist), the dev-only switch, the release gates, and where open work is queued.

## The rule

Every item your change touches gets a decision and evidence: a `file:line`, a test, a
config value, a dashboard. An item that does not apply is `N/A: <reason>`. "Looks fine"
is not evidence. These are a starting point, not a mandate to adopt every technology.

## P0 — before real users or sensitive data

- Cost ceiling: budgets sized to what the owner can absorb; alerts reach a person; a tested switch turns expensive features off. A billing-budget email is not a spending cap.
- Capacity: limits set from a load test at expected peak and burst, not guessed.
- Every billable call (AI, provider) is metered or bounded, setup, follow-ups and retries included.
- Overload rejects or defers work before memory, connections or quotas run out.
- Every sensitive action is authorized on the server for this user, resource and role.
- Secrets stay out of code, logs, images and client bundles; credentials least-privilege and rotatable.
- Data encrypted in transit and at rest.
- Sessions and tokens: redirects, scopes, state/nonce, storage, expiry, signature checks, key rotation.
- Injection, XSS, SSRF, CSRF and CORS origins addressed.
- Sign-up, recovery, uploads and paid actions rate-limited at the right scope.
- Body size, file type and size, page size and expensive inputs bounded.
- Old and new versions overlap safely during a deploy; applied migrations never change.
- Invariants enforced in the database; retried writes idempotent; races handled.
- Backups protected and retained, and a restore actually tested.
- Release checks block a bad build; the deployed artifact is the one that was tested.
- A bad release is detected and rolled back without losing data.
- User-facing errors and security events visible, without personal data in logs.
- A named owner with dashboards, runbooks and an escalation path.

## Changing something already live

1. Wire changes are additive; the server deploys before the client.
2. Remove a field or route only after every client still using it is gone.
3. Retried or queued requests send absolute values and succeed on replay.
4. Schema changes expand, migrate, then contract, across separate releases.
5. Every dev-only surface hangs off the project's one dev switch, never ungated.

## P1–P4

Load `references/priorities.md` when the change touches timeouts, retries, caching,
indexes, pooling, jobs, webhooks, monitoring, scaling, flags, rollout or infrastructure.

## Release decision (every release answers)

- The highest-impact ways it could fail, and how each is detected.
- How to stop or roll back without losing data or stranding users.
- Backups, migrations, permissions and integrations checked for this release.
- Who watches it, where the dashboards and runbooks are, what triggers a rollback.
- Which items are N/A, and the evidence for each.

## Done means

- Your report lists each P0 item touched: `<item>: <evidence>` or `N/A: <reason>`.
- The release gates the agent guide names have run; quote each result.
- Anything left open is queued where the agent guide says, by item.
