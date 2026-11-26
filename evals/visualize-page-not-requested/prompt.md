---
description: A TypeScript dashboard with two layouts, src/layouts/classic.ts and src/layouts/focus.ts, each a set of grid areas per breakpoint. On desktop classic has a 240px nav sidebar, an alerts banner, kpis and chart with activity beside it; focus has no sidebar (nav in the header menu), alerts behind the header bell, activity in a drawer, and the chart with kpis beside it. A dense comparison of two layouts at three breakpoints, with no page asked for, so with the skill Claude draws it in the reply and writes no file.
expected_outcome: No Write call names an .html file and no Edit is made; the reply itself compares both layouts at phone, tablet and desktop, and shows focus on desktop without a sidebar and with activity in a drawer.
tags: [visualize, visualize-dev]
runs: 1
max_turns: 20
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Edit, Skill]
---

/knackpack:visualize compare the classic and focus dashboard layouts in src/layouts: where every panel sits on phone, tablet and desktop in each, and what moves or disappears between them. Product wants focus to be the default for new users and I need the full picture.
