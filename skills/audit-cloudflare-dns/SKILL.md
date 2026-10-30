---
name: audit-cloudflare-dns
description: >-
  Audit every Cloudflare DNS zone the project owns through the signed-in Chrome browser — records missing, stale or dangling against what the project expects, wrong proxy status, mail authentication (SPF, DKIM, DMARC, MX), CAA and DNSSEC — cross-checked with public lookups, then make only the dashboard changes the owner confirms one by one. Run before launch, after moving a domain or host, after adding a mail or hosting provider, or as a periodic sweep. Not for Cloudflare cache, WAF or bot settings.
---

# audit-cloudflare-dns

Read `../../commands/audit-cloudflare-dns.md` (from the project root: `.agents/commands/audit-cloudflare-dns.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
