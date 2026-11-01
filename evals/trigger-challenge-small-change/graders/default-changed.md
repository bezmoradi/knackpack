---
type: regex
target: { source: file, path: main.go }
pattern: 'flag\.Duration\(\s*"timeout"\s*,\s*(2\s*\*\s*time\.Minute|time\.Minute\s*\*\s*2|120\s*\*\s*time\.Second|time\.Second\s*\*\s*120)'
---
