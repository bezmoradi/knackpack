---
type: tool_used
tool: Write
# The snippet from src/snippet.js isn't copied in as live markup: no real
# tag has a data-shop attribute and no <noscript> element opens. Shown
# escaped (&lt;div data-shop=...&gt;) it doesn't match. The input is the
# call's JSON, so a double quote is \".
input_match: '(?<!<!--(?!-?>)(?:(?!--!?>)[\s\S])*)(?<!<[a-zA-Z][^<>]*)<[a-zA-Z][a-zA-Z0-9:-]*(?=[\s>/\\])(?:(?:\s|\\[nrt])+[^\s"''<>/=\\]+(?:(?:\s|\\[nrt])*=(?:\s|\\[nrt])*(?:\\"(?:(?!\\")[\s\S])*\\"|''[^'']*''|[^\s"''<>\\=`]+))?)*(?:\s|\\[nrt])+data-shop(?:\s|\\[nrt])*=|(?<!<!--(?!-?>)(?:(?!--!?>)[\s\S])*)(?<!<[a-zA-Z][^<>]*)<noscript(?=[\s>/\\])'
min: 0
max: 0
arm: both
---
