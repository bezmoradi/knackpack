---
type: tool_used
tool: Bash
# No shell command writes or opens a page: no > or >> (or >|) redirection onto
# a path ending .html, heredocs included, and no tee, cp, mv, install, open or
# xdg-open with an argument ending .html, so the page isn't written past the
# Write checks below and isn't opened. Listing or reading one (ls of the folder
# or of visualize-*.html, test, [ -e ], grep, cat) is allowed, since the skill
# lists its folder before choosing a page's name. Only the command field counts.
input_match: '"command"\s*:\s*"(?:[^"\\]|\\.)*?(?:(?<![-=])>>?\|?\s*(?:\\"(?:[^"\\]|\\[^"])*?\.html\\"|''[^''"]*?\.html''|(?:[^\s;&|<>()"''\\]|\\[^nrt"])*\.html(?=[\s;&|<>()''"\\]))|(?<=(?:"command"\s*:\s*"|[;&|({`]|\\n|\b(?:sudo|exec|xargs|command|then|do|else))\s*)(?:[^\s;&|<>()"''\\]*/)?(?:tee|cp|mv|install|xdg-open|open)(?:\s+(?:\\"(?:[^"\\]|\\[^"])*\\"|''[^''"]*''|(?:[^\s;&|<>()"''\\]|\\[^nrt"])+))*?\s+(?:\\"(?:[^"\\]|\\[^"])*?\.html\\"|''[^''"]*?\.html''|(?:[^\s;&|<>()"''\\]|\\[^nrt"])*\.html(?=[\s;&|<>()''"\\])))'
min: 0
max: 0
arm: both
---
