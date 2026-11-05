---
description: "An ESM importer (type: module, module nodenext) switches from a default import of the CommonJS package legacy-csv to import { parse, toObjects } from \"legacy-csv\". The package builds module.exports with Object.assign, which Node's CommonJS named-export detection can't see, so both import commands crash at startup with a SyntaxError about the missing named export, while tsc passes. The reviewer reports the ESM/CJS interop failure."
expected_outcome: "The review reports that the named imports from legacy-csv fail at run time in Node because the CommonJS package assigns its exports dynamically (Object.assign(module.exports, ...)), so Node can't detect parse and toObjects as named exports and the CLI, including the existing supplier import, crashes on load with a SyntaxError, although tsc accepts the import; it recommends the default import with destructuring (as the committed code did) and grades it High or higher; with the plugin, the reviewer ran."
tags: [ts-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Added the stock-level import to the importer CLI. tsc is happy. Can you review the TypeScript in my uncommitted changes? I can't open files on this machine, so put the full review in your reply, exactly as written.
