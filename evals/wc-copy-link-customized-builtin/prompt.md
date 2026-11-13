---
description: "A docs site whose browserslist includes Safari 17 and iOS 17 gets an uncommitted copy-link button written as a customized built-in (class extends HTMLButtonElement, used as button is=\"copy-link\"). Safari doesn't implement customized built-ins, so there the button stays a plain button and copying does nothing. The reviewer reports the compatibility limitation against the declared targets."
expected_outcome: "The review reports that customized built-in elements (the is attribute, extends HTMLButtonElement) aren't supported in Safari, a declared target, so the copy buttons do nothing there without a polyfill or an autonomous element, and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [wc-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Added copy-to-clipboard buttons to the code samples in our docs. I extended the native button so we keep its keyboard and form behavior for free. Can you review the uncommitted changes? I can't open files on this machine, so put the full review in your reply, exactly as written.
