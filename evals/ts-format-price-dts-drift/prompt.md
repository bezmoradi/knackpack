---
description: "A published price-formatting package rewrites index.js so formatPrice takes an options object { currency, locale } and bumps 1.4.2 to 1.5.0, but leaves the hand-written index.d.ts declaring formatPrice(cents: number, currency?: string). Consumers' formatPrice(1999, \"EUR\") still type-checks and now silently prints \"$19.99\", while the documented new call fails to type-check. The reviewer reports the declaration drift and the breaking change shipped as a minor."
expected_outcome: "The review reports that index.d.ts still declares the old (cents, currency?: string) signature while index.js now takes an options object, so TypeScript consumers keep passing a currency string that the new code ignores (falling back to USD) and can't use the new options form; it also reports that dropping the string argument is a breaking change released as a minor version, recommends updating the declaration (and keeping the string form or bumping the major), and grades it High or higher; with the plugin, the reviewer ran."
tags: [ts-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Adding locale support to price-format, going out as 1.5.0 once this is reviewed. Can you get the uncommitted changes looked at from the TypeScript side? I can't open files on this machine, so put the full review in your reply, exactly as written.
