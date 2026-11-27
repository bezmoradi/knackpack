---
type: tool_used
tool: Write
# A diagram is followed by a list or table giving its nodes and edges as
# text: a closing </svg> tag and, somewhere after it, a <ul>, <ol>, <table>
# or <dl> element.
# The input is the call's JSON, so a double quote in the page is \" and a
# newline is \n. A tag counts only when it opens with a real <, outside an
# HTML comment and outside another tag's attribute values, so markup shown
# escaped (&lt;script&gt;) or quoted inside an attribute doesn't count.
input_match: '(?=</svg)(?<!<!--(?!-?>)(?:(?!--!?>)[\s\S])*)(?<!<[a-zA-Z][^<>]*)</svg(?:\s|\\[nrt])*>[\s\S]*?(?=<(?:ul|ol|table|dl)[\s>/\\])(?<!<!--(?!-?>)(?:(?!--!?>)[\s\S])*)(?<!<[a-zA-Z][^<>]*)<(?:ul|ol|table|dl)(?=[\s>/\\])'
min: 1
---
