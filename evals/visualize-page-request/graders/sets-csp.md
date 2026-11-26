---
type: tool_used
tool: Write
# A written file has a Content-Security-Policy meta element whose policy
# starts with default-src 'none', in either attribute order.
# The input is the call's JSON, so a double quote in the page is \" and a
# newline is \n. A tag counts only when it opens with a real <, outside an
# HTML comment and outside another tag's attribute values, so markup shown
# escaped (&lt;script&gt;) or quoted inside an attribute doesn't count.
input_match: '(?<!<!--(?:(?!-->)[\s\S])*)(?<!<[a-zA-Z][^<>]*)<meta(?=[\s/\\])(?=[^<>]*[Hh][Tt][Tt][Pp]-[Ee][Qq][Uu][Ii][Vv](?:\s|\\[nrt])*=(?:\s|\\[nrt])*(?:\\"|'')?[Cc]ontent-[Ss]ecurity-[Pp]olicy)(?=[^<>]*content(?:\s|\\[nrt])*=(?:\s|\\[nrt])*(?:\\"|'')(?:\s|\\[nrt])*default-src(?:\s|\\[nrt])+''none'')'
min: 1
---
