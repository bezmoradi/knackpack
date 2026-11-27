---
type: regex
target: last_message
match: not_contains
# A yes-or-no question about one counter needs no diagram. A fenced block of
# quoted code is fine; a fenced block in a diagram language, or one that holds
# arrows or box-drawing characters, is a diagram. Python's return annotation,
# ") -> int", is not counted as an arrow.
pattern: '(^|\n)[ \t]*(```|~~~)[ \t]*(mermaid|dot|graphviz|plantuml|puml|d2)\b|(^|\n)[ \t]*(```|~~~)[^\n]*\n((?!```|~~~)[\s\S])*?(-->|==>|<--|[┌┐└┘│─├┤┬┴┼╭╮╯╰▼▲►◄▶◀→←↓↑]|[^)\s][ \t]*->|\n[ \t]*[|v][ \t]*\n)'
---
