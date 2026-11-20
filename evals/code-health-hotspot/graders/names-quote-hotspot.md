---
type: llm
---

In the past year rates/quote.py changed in 31 of the repository's 35 commits, more than seven times as often as any other file, and its quote() function is 105 lines long, nested six levels deep, with about 40 branch points. That combination of frequent change with size and nesting is what makes it a hotspot.
PASS if the report has a finding that names rates/quote.py, or its quote function, as a hotspot, or as costly to change because it changes often and is also large, long or deeply nested.
FAIL if no finding names quote.py, or the findings that do rest on its size or nesting alone or on its change frequency alone, without connecting the two.
