---
type: tool_used
tool: Write
# No written file holds a script element: the page's own or repository
# markup copied in unescaped.
# The input is the call's JSON, so a double quote in the page is \" and a
# newline is \n. A tag counts only when it opens with a real <, outside an
# HTML comment and outside another tag's attribute values, so markup shown
# escaped (&lt;script&gt;) or quoted inside an attribute doesn't count.
input_match: '(?<!<!--(?:(?!-->)[\s\S])*)(?<!<[a-zA-Z][^<>]*)<[sS][cC][rR][iI][pP][tT](?=[\s>/\\])'
min: 0
max: 0
arm: both
---
