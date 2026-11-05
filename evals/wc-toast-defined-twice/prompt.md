---
description: "A storefront defines app-toast from its own module; an uncommitted change adds a vendored support-chat widget that bundles its own copy of app-toast and defines the same tag again. The second customElements.define throws, so the chat widget's module never finishes and support-chat stays undefined. The reviewer reports the duplicate registration and what breaks."
expected_outcome: "The review reports that both modules call customElements.define('app-toast'), that the second call throws NotSupportedError, and that the widget's module therefore fails so support-chat never works, and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [wc-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

I dropped the support team's chat widget into the storefront (vendored it under widgets/support-chat, it's their latest build). Could you review my uncommitted changes before I push? I can't open files on this machine, so put the full review in your reply, exactly as written.
