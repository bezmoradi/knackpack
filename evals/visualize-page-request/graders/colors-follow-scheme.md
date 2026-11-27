---
type: tool_used
tool: Write
# The page's colours follow the system's light or dark setting: an @media
# query on prefers-color-scheme, and colours read from custom properties
# with var(--...).
input_match: '^(?=[\s\S]*@media[^{]*prefers-color-scheme)(?=[\s\S]*var\(\s*--)'
min: 1
---
