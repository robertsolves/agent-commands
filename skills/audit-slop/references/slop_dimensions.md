# Slop dimensions

## Contents

1. Hallucinated APIs and slopsquatting
2. Authorization, IDOR and broken access control
3. Hardcoded secrets and token leaks
4. Happy-path bias and missing edge cases
5. The vibe doom loop
6. Swallowed errors and silent failures
7. Tautological tests and fake verification
8. Architectural drift and code rot
9. State, UI and business-logic mismatches
10. Prose slop

## 1. Hallucinated APIs and slopsquatting
- Imports or calls to packages that do not exist
- Methods invented on real SDKs or frameworks that do not exist in the installed version
- Conflated or outdated package names
- Fake commit hashes, made-up docs, or claimed "tests passed" when they were never run

## 2. Authorization, IDOR and broken access control
- Authentication present but no ownership check (`req.user.id === resource.ownerId`)
- Any endpoint that accepts an ID and returns or mutates data without verifying the caller owns it
- Client-supplied user IDs, roles or tenant IDs trusted without server-side verification
- Client-side-only auth or paywalls

## 3. Hardcoded secrets and token leaks
- API keys, JWT secrets, database credentials or private endpoints in source
- Secrets in `NEXT_PUBLIC_*`, client bundles, committed `.env` or browser-visible config

## 4. Happy-path bias and missing edge cases
- Missing null, empty-array or undefined checks
- No validation of request body shape or types
- No timeouts, rate-limit handling or network error paths
- Negative quantities, negative prices, zero-division or other business-logic edge cases left open
- Missing rate limits or cost caps on expensive or AI endpoints

## 5. The vibe doom loop
- Empty `catch {}` blocks or `catch (e) { console.log(e) }` that swallow errors
- Defensive fallbacks (`?? ''`, `|| []`, long optional chaining) that hide missing upstream data instead of fixing the root cause
- Layered AI patches that bypass earlier validation
- Over-engineering: excessive try/catch, null checks for impossible cases, unnecessary abstractions or class hierarchies for simple tasks

## 6. Swallowed errors and silent failures
- Async functions that catch, log, and then return `success: true` or `200`
- API routes that never surface the real error to the caller
- Code that continues in a corrupted state after a failure

## 7. Tautological tests and fake verification
- Tests that re-implement the exact same logic as the function under test
- 100% mocked external dependencies so the test verifies nothing real
- Claims that tests passed when they were never executed

## 8. Architectural drift and code rot
- Method signature or return-type changes that silently break callers
- Reimplementing existing project utilities instead of reusing them
- Duplicate utility functions or inconsistent error-handling or state-management patterns
- Unrelated changes or scope creep mixed into a single diff
- Backward-compatibility cruft in greenfield code
- Comment noise, emoji, or verbose docstrings on trivial code that bury real logic
- Dependency bloat or outdated/abandoned packages pulled in without need

## 9. State, UI and business-logic mismatches
- State management that drifts from the actual UI or data model
- Business rules implemented incorrectly or incompletely (especially around roles, pricing, ownership)
- Verbose error messages that leak internal details to clients

## 10. Prose slop

Agents write words as well as code, and the words have tells too. A hit from the word-list search is slop when the word stands in for a fact: "robust retry logic" says nothing that "retries 3 times with backoff" does not say better. It is fine when the word is literal (a `comprehensive` test-mode enum, `streamline` in a quoted user message).

Also flag, by reading rather than searching:
- Comments that narrate the code ("This function seamlessly handles…") instead of saying why. A comment should explain the constraint or reason the code cannot show.
- Puffed-up significance ("a crucial part of the offline story") and `-ing` tails that add a vague claim ("…, ensuring a smooth experience").
- Chatbot leakage in committed text: "Certainly!", "Great question", "I hope this helps", "Let me know if…".
- UI strings in a voice other than the product brief's (the agent guide names it): marketing gloss, exclamation-mark cheer, "Oops!".

Not slop by default: em dashes, bold lead-ins on list items, and absolute words (`never`, `always`, `every`). Many projects use all three on purpose; follow the agent guide if it says otherwise. Report prose findings as Minor, unless a UI string misleads the user about what happened.
