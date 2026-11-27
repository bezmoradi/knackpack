---
type: tool_used
tool: Write
# The page fits a screen 320 CSS pixels wide: no CSS width or min-width
# (max-width is fine) wider than 320px in a <style> element or a style
# attribute, apart from an @media or @container condition such as
# (min-width: 700px) and the rules inside a block whose condition is a
# minimum width, and no <svg> without a viewBox.
# The input is the call's JSON, so a double quote in the page is \" and a
# newline is \n. A tag counts only when it opens with a real <, outside an
# HTML comment and outside another tag's attribute values, so markup shown
# escaped (&lt;script&gt;) or quoted inside an attribute doesn't count.
input_match: '(?=<style)(?<!<!--(?!-?>)(?:(?!--!?>)[\s\S])*)(?<!<[a-zA-Z][^<>]*)<style(?=[\s>/\\])[^<>]*>(?:(?!</style)[\s\S])*?(?=(?:min-)?width)(?<!\((?:\s|\\[nrt])*)(?<!@(?:media|container)[^{};]*(?:min-width|width(?:\s|\\[nrt])*>|<=?(?:\s|\\[nrt])*width)[^{};]*\{(?:[^{}]*\{[^{}]*\})*[^{}]*\{[^{}]*)(?=(?:min-)?width)(?:(?<![\w-])|(?<=\\[nrt]))(?:min-)?width(?:\s|\\[nrt])*:(?:\s|\\[nrt])*0*(?:(?:32[1-9]|3[3-9]\d|[4-9]\d\d|[1-9]\d{3,})(?:\.\d+)?|320\.\d*[1-9]\d*)[pP][xX](?![\w-])|(?=<[a-zA-Z])(?<!<!--(?!-?>)(?:(?!--!?>)[\s\S])*)(?<!<[a-zA-Z][^<>]*)<[a-zA-Z][a-zA-Z0-9:-]*(?=[\s>/\\])(?:(?:\s|\\[nrt])+[^\s"''<>/=\\]+(?:(?:\s|\\[nrt])*=(?:\s|\\[nrt])*(?:\\"(?:(?!\\")[\s\S])*\\"|''[^'']*''|[^\s"''<>\\=`]+))?)*(?:\s|\\[nrt])+style(?:\s|\\[nrt])*=(?:\s|\\[nrt])*(?:\\"(?:(?!\\")[^<>])*?|''[^''<>]*?)(?=(?:min-)?width)(?:(?<![\w-])|(?<=\\[nrt]))(?:min-)?width(?:\s|\\[nrt])*:(?:\s|\\[nrt])*0*(?:(?:32[1-9]|3[3-9]\d|[4-9]\d\d|[1-9]\d{3,})(?:\.\d+)?|320\.\d*[1-9]\d*)[pP][xX](?![\w-])|(?=<svg)(?<!<!--(?!-?>)(?:(?!--!?>)[\s\S])*)(?<!<[a-zA-Z][^<>]*)<svg(?=[\s>/\\])(?!(?:(?:\s|\\[nrt])+[^\s"''<>/=\\]+(?:(?:\s|\\[nrt])*=(?:\s|\\[nrt])*(?:\\"(?:(?!\\")[\s\S])*\\"|''[^'']*''|[^\s"''<>\\=`]+))?)*(?:\s|\\[nrt])+[vV][iI][eE][wW][bB][oO][xX](?:\s|\\[nrt])*=)'
min: 0
max: 0
---
