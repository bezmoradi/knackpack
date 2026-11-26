---
type: tool_used
tool: Write
# A diagram has a text alternative: an element with role="img" and an
# accessible name, from aria-label, aria-labelledby or, on an <svg>, a
# <title> as its first child.
# The input is the call's JSON, so a double quote in the page is \" and a
# newline is \n. A tag counts only when it opens with a real <, outside an
# HTML comment and outside another tag's attribute values, so markup shown
# escaped (&lt;script&gt;) or quoted inside an attribute doesn't count.
input_match: '(?<!<!--(?:(?!-->)[\s\S])*)(?<!<[a-zA-Z][^<>]*)<[a-zA-Z][a-zA-Z0-9-]*(?=[\s/\\])(?=[^<>]*(?:\s|\\[nrt])role(?:\s|\\[nrt])*=(?:\s|\\[nrt])*(?:\\"|'')?img\b)(?:[^<>]*(?:\s|\\[nrt])aria-label(?:ledby)?(?:\s|\\[nrt])*=(?:\s|\\[nrt])*(?:\\"|'')?[^\s"''\\>]|[^<>]*>(?:\s|\\[nrt])*<title[\s>])'
min: 1
---
