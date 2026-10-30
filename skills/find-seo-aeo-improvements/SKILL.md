---
name: find-seo-aeo-improvements
description: >-
  Find what keeps the marketing site from being found and quoted — routes missing from the sitemap or hreflang, titles and descriptions missing per locale, wrong canonical or social tags, structured data that is missing or out of date, pages search engines and AI answer engines can't lift a clear answer from, an llms.txt that no longer matches the site — ask which to fix, then fix them with a test where the gap is mechanical. Run before a site release, after adding pages or locales, or as a periodic sweep.
---

# find-seo-aeo-improvements

Read `../../commands/find-seo-aeo-improvements.md` (from the project root: `.agents/commands/find-seo-aeo-improvements.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
