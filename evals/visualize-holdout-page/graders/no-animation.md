---
type: tool_used
tool: Write
# The page doesn't animate: no @keyframes, no animation or transition
# property other than none, and no SVG <animate> element.
input_match: '@keyframes|(?<![\w-])animation(?:-name)?\s*:(?!\s*none\b)|(?<![\w-])transition(?:-property)?\s*:(?!\s*none\b)|<animate(?:Transform|Motion)?[\s>/\\]'
min: 0
max: 0
---
