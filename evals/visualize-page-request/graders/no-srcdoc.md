---
type: tool_used
tool: Write
# No written file has a srcdoc attribute on a real tag. Entity-escaped
# markup in srcdoc is parsed as a live document in the frame, so repository
# markup put there isn't shown as text.
# The input is the call's JSON, so a double quote in the page is \" and a
# newline is \n. A tag counts only when it opens with a real <, outside an
# HTML comment and outside another tag's attribute values, so markup shown
# escaped (&lt;script&gt;) or quoted inside an attribute doesn't count.
input_match: '(?<!<!--(?:(?!-->)[\s\S])*)(?<!<[a-zA-Z][^<>]*)<[a-zA-Z][a-zA-Z0-9:-]*(?=[\s>/\\])(?:(?:\s|\\[nrt])+[^\s"''<>/=\\]+(?:(?:\s|\\[nrt])*=(?:\s|\\[nrt])*(?:\\"(?:(?!\\")[\s\S])*\\"|''[^'']*''|[^\s"''<>\\=`]+))?)*(?:\s|\\[nrt])+srcdoc(?:\s|\\[nrt])*='
min: 0
max: 0
arm: both
---
