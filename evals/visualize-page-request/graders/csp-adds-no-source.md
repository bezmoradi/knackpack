---
type: tool_used
tool: Write
# The page's Content-Security-Policy adds nothing beyond inline styles and
# data: images: no script-src other than 'none', no connect-, frame-,
# child-, worker- or object-src other than 'none', no http(s) or ws(s)
# source, no *, and no 'unsafe-eval', 'strict-dynamic' or blob:. A page
# with no policy at all passes here and fails sets-csp.
input_match: '(?<!<!--(?!-?>)(?:(?!--!?>)[\s\S])*)(?<!<[a-zA-Z][^<>]*)<meta(?=[\s/\\])(?=[^<>]*[Cc]ontent-[Ss]ecurity-[Pp]olicy)[^<>]*content(?:\s|\\[nrt])*=(?:\s|\\[nrt])*\\"(?:(?!\\")[^<>])*?(?:script-src(?!(?:\s|\\[nrt])+''none''(?:\s|\\[nrt])*(?:;|\\"))|(?:connect|frame|child|worker|object)-src(?!(?:\s|\\[nrt])+''none'')|https?:|wss?:|(?:^|(?:\s|\\[nrt]))\*|''unsafe-eval''|''wasm-unsafe-eval''|''strict-dynamic''|blob:)'
min: 0
max: 0
arm: both
---
