---
type: regex
target: last_message
match: not_contains
# A quick question gets at most one fenced block. Three fence lines mean a
# second block has opened, so the reply holds two or more.
pattern: '(^|\n)[ \t]*(```|~~~)[\s\S]*\n[ \t]*(```|~~~)[\s\S]*\n[ \t]*(```|~~~)'
---
