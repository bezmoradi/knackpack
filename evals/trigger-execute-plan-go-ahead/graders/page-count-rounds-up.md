---
type: regex
target: { source: file, path: pages.py }
pattern: '(math\.ceil\(\s*total\s*/\s*per_page\s*\)|-\(\s*-\s*total\s*//\s*per_page\s*\)|\(\s*total\s*\+\s*per_page\s*-\s*1\s*\)\s*//\s*per_page)'
---
