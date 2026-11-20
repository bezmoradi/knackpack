---
type: regex
target: last_message
flags: i
# The report says which stretch of history its churn covers: two dates on a
# line about the window or history, or the window's length.
pattern: '(window|history|churn|commits|period)[^\n]{0,160}\b20\d\d-\d\d-\d\d[^\n]{0,80}\b20\d\d-\d\d-\d\d|(window|history|churn|commits|period|last|past|over|covering|covers)[^\n]{0,40}\b(365[ -]days?|(12|twelve)[ -]months?)\b'
---
