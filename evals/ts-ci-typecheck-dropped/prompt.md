---
description: "A Vite app's change removes the CI type-check step and the tsc --noEmit from its build script, so nothing type-checks any more (Vite and Vitest strip types without checking, and the vitest config sets no typecheck). The same change passes the select's string value to shiftAppointment's days: number, which tsc reports as TS2345 and which at run time concatenates into the day of the month, moving a 'tomorrow' appointment months ahead. The reviewer reports both."
expected_outcome: "The review reports that after the change no step in CI or the build runs tsc, since vite build and vitest don't type-check, and grades that Medium or higher; and it reports that applyReschedule passes the string days to shiftAppointment (a type error tsc reports), so getDate() + days concatenates and appointments move to wrong dates, graded High or Critical; with the plugin, the TypeScript reviewer ran."
tags: [ts-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

This adds rescheduling to the front desk app. Please review the TypeScript in my uncommitted changes before I open the PR. I can't open files on this machine, so put the full review in your reply, exactly as written.
