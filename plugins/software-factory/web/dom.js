export function el(tag, cls, text) {
  const node = document.createElement(tag)
  if (cls) node.className = cls
  if (text !== undefined) node.textContent = text
  return node
}

const INVISIBLE = /[\u0000-\u0008\u000b-\u001f\u007f-\u009f\u200b-\u200f\u2028-\u202e\u2060-\u2069\ufeff]/g

export function visible(text) {
  return String(text).replace(INVISIBLE, c => `\\u{${c.codePointAt(0).toString(16).padStart(4, '0')}}`)
}
