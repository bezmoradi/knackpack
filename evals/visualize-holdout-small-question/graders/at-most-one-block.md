---
type: regex
target: last_message
match: not_contains
# A quick question gets at most one diagram. A diagram block is a fenced
# block in a diagram language (mermaid, dot, ...) or one whose body holds an
# arrow or box-drawing character, as no-diagram-block in visualize-prose-enough
# defines it; a fenced block of quoted code, such as the call itself, doesn't
# count. Fence lines pair up from the reply's start, opener then closer, and
# the reply fails when two or more blocks are diagrams.
pattern: '^(?:(?![ \t]*(?:```|~~~))[^\n]*\n|[ \t]*(?:```|~~~)[^\n]*\n(?:(?![ \t]*(?:```|~~~))[^\n]*\n)*[ \t]*(?:```|~~~)[^\n]*(?:\n|$))*?[ \t]*(?:```|~~~)(?:[ \t]*(?:mermaid|dot|graphviz|plantuml|puml|d2)\b[^\n]*\n(?:(?![ \t]*(?:```|~~~))[^\n]*\n)*|[^\n]*\n(?:(?![ \t]*(?:```|~~~))[^\n]*\n)*?(?![ \t]*(?:```|~~~))(?:[^\n]*(?:-->|==>|<--|[┌┐└┘│─├┤┬┴┼╭╮╯╰▼▲►◄▶◀→←↓↑]|[^)\s][ \t]*->)[^\n]*|[ \t]*[|v][ \t]*)\n(?:(?![ \t]*(?:```|~~~))[^\n]*\n)*)[ \t]*(?:```|~~~)[^\n]*(?:\n|$)(?:(?![ \t]*(?:```|~~~))[^\n]*\n|[ \t]*(?:```|~~~)[^\n]*\n(?:(?![ \t]*(?:```|~~~))[^\n]*\n)*[ \t]*(?:```|~~~)[^\n]*(?:\n|$))*?[ \t]*(?:```|~~~)(?:[ \t]*(?:mermaid|dot|graphviz|plantuml|puml|d2)\b[^\n]*\n(?:(?![ \t]*(?:```|~~~))[^\n]*\n)*|[^\n]*\n(?:(?![ \t]*(?:```|~~~))[^\n]*\n)*?(?![ \t]*(?:```|~~~))(?:[^\n]*(?:-->|==>|<--|[┌┐└┘│─├┤┬┴┼╭╮╯╰▼▲►◄▶◀→←↓↑]|[^)\s][ \t]*->)[^\n]*|[ \t]*[|v][ \t]*)\n(?:(?![ \t]*(?:```|~~~))[^\n]*\n)*)[ \t]*(?:```|~~~)[^\n]*(?:\n|$)'
---
