---
type: tool_used
tool: Write
# No written file loads or links anything remote: no scheme:// or
# protocol-relative // URL in a src, href, srcset, action, data or similar
# attribute of a real tag, in a style attribute's url(), or in a <style>
# element's url() or @import. data: URLs and #fragments are fine.
# The input is the call's JSON, so a double quote in the page is \" and a
# newline is \n. A tag counts only when it opens with a real <, outside an
# HTML comment and outside another tag's attribute values, so markup shown
# escaped (&lt;script&gt;) or quoted inside an attribute doesn't count.
input_match: '(?<!<!--(?:(?!-->)[\s\S])*)(?<!<[a-zA-Z][^<>]*)<[a-zA-Z][a-zA-Z0-9:-]*(?=[\s>/\\])(?:(?:\s|\\[nrt])+[^\s"''<>/=\\]+(?:(?:\s|\\[nrt])*=(?:\s|\\[nrt])*(?:\\"(?:(?!\\")[\s\S])*\\"|''[^'']*''|[^\s"''<>\\=`]+))?)*(?:\s|\\[nrt])+(?:src|href|xlink:href|srcset|poster|action|formaction|data|background|cite|ping|manifest|codebase)(?:\s|\\[nrt])*=(?:\s|\\[nrt])*(?:\\"|'')?(?:\s|\\[nrt])*(?:[a-zA-Z][a-zA-Z0-9+.-]*:)?//|(?<!<!--(?:(?!-->)[\s\S])*)(?<!<[a-zA-Z][^<>]*)<[a-zA-Z][a-zA-Z0-9:-]*(?=[\s>/\\])(?:(?:\s|\\[nrt])+[^\s"''<>/=\\]+(?:(?:\s|\\[nrt])*=(?:\s|\\[nrt])*(?:\\"(?:(?!\\")[\s\S])*\\"|''[^'']*''|[^\s"''<>\\=`]+))?)*(?:\s|\\[nrt])+style(?:\s|\\[nrt])*=(?:\s|\\[nrt])*(?:\\"(?:(?!\\")[^<>])*?|''[^'']*?)url\((?:\s|\\[nrt])*(?:''|&quot;)?(?:\s|\\[nrt])*(?:[a-zA-Z][a-zA-Z0-9+.-]*:)?//|(?<!<!--(?:(?!-->)[\s\S])*)(?<!<[a-zA-Z][^<>]*)<style(?=[\s>/\\])[^<>]*>(?:(?!</style)[\s\S])*?(?:url\(|@import)(?:\s|\\[nrt])*(?:url\()?(?:\s|\\[nrt])*(?:\\"|'')?(?:\s|\\[nrt])*(?:[a-zA-Z][a-zA-Z0-9+.-]*:)?//'
min: 0
max: 0
arm: both
---
