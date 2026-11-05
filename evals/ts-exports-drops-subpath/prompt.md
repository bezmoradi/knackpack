---
description: "A workspace library, @acme/ui-kit, gains an exports map listing only \".\" in a minor release, while its README documents importing @acme/ui-kit/tokens.js and the storefront package does so. With exports present, Node throws ERR_PACKAGE_PATH_NOT_EXPORTED for the tokens subpath and tsc under nodenext reports TS2307. The reviewer reports the breaking change."
expected_outcome: "The review reports that the new exports map hides ./tokens.js, so the storefront's import of @acme/ui-kit/tokens.js (and the README's documented usage) fails at run time with ERR_PACKAGE_PATH_NOT_EXPORTED and at type-check time under nodenext, that this breaks consumers in a minor release, proposes adding the subpath (with its types) to exports, and grades it High or Critical; with the plugin, the TypeScript reviewer ran."
tags: [ts-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

I'm getting ui-kit 3.3.0 ready to publish. Mind reviewing my uncommitted TypeScript and packaging changes first? I can't open files on this machine, so put the full review in your reply, exactly as written.
