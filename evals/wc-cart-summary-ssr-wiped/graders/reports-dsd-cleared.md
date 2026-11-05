---
type: llm
---

The server renders `cart-summary` with a declarative shadow root (`<template shadowrootmode="open">`). The uncommitted class calls `this.attachShadow({ mode: 'open' })` in its constructor without checking `this.shadowRoot`; on a host with a declarative root of the same mode, `attachShadow` returns that root after removing all its children. So on upgrade the server-rendered count, total and checkout link disappear, and the header stays blank until `/api/cart` responds, or for good if the request fails, since nothing handles that error.
PASS if the review reports that calling `attachShadow` on the server-rendered host clears the declarative shadow root's content, so the summary or checkout link disappears after upgrade (a blank or flashing header, or one left empty when the fetch fails), and grades it Medium or higher. Fixes that reuse the existing root (`this.shadowRoot` or `internals.shadowRoot`) and update it in place are fine.
FAIL if it misses that the server-rendered content is wiped, says `attachShadow` throws or keeps the existing content, or grades it Low.
