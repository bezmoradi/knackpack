---
type: regex
target: { source: file, path: main.go }
pattern: 'flag\.Duration(Var\([^,]+,)?\(?\s*"timeout"\s*,\s*(30\s*\*\s*time\.Second|time\.Second\s*\*\s*30)'
---
