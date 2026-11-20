---
type: regex
target: last_message
flags: i
# The report gives internal/common's fan-in, 8: as a number beside fan-in or
# the packages importing it, or as a package table row.
pattern: '(fan[-_ ]?in|imported by|importers|import(s|ed)? it|depend(s|ed)? on it)[^\n]{0,80}\b(8|eight)\b|\b(8|eight)\b[^\n]{0,80}(fan[-_ ]?in|importers|packages? (that )?imports?|import(s|ed)? it|depend on it)|internal/common[^\n]{0,60}\|\s*8\s*\|'
---
