---
type: llm
---

The project is plain JavaScript: no Python, Go or TypeScript, and no installed tools in node_modules. The reviewer's function-level recipes (length, nesting depth and branch count per function) cover only Python and Go, so for this code those numbers can't be measured; file sizes and history still can be.
PASS if the report says that per-function complexity (function length, nesting or branches) wasn't measured, or had no tool or recipe, for this JavaScript code, for example by marking structural complexity not_measured or by saying it was only read, not measured.
FAIL if the report presents per-function complexity of the JavaScript as measured, or calls the structural complexity healthy or fine without saying that the function metrics weren't measured. Also FAIL if it doesn't address structural complexity at all.
