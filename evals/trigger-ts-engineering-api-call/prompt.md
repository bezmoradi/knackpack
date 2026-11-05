---
description: A small TypeScript library-catalog client asks for a new function that fetches a book's availability from the catalog API, whose sample response is in docs/. Writing TypeScript starts the TypeScript engineering skill on its own, and the new function checks the response's shape before using it rather than casting the JSON to a type.
expected_outcome: The typescript-engineering skill loads, src/catalog.ts exports getAvailability, and the function validates the parsed response (checks the fields it uses) instead of only asserting or annotating its type.
tags: [trigger]
runs: 1
max_turns: 20
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Edit, Skill]
---

Can you add a getAvailability(isbn) to src/catalog.ts? It should call GET /books/{isbn}/availability on the catalog API (same base URL as the other calls) and return how many copies are on the shelf and when the next one is due back. docs/availability-sample.json has what the API sends.
