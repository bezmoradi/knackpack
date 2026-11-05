---
description: "A new Upload type is one object with a state field and optional url and error, and the gallery renders upload.url! when state is \"done\". The retry path marks an upload done from a cache of stored file hashes without setting url, so the photo renders as <img src=\"undefined\">. The reviewer reports that the type allows the invalid state and that a discriminated union would make the compiler catch it."
expected_outcome: "The review reports that Upload lets state \"done\" exist without a url, that retryUpload's cache path produces exactly that so renderUpload's url! yields src=\"undefined\" (a broken photo), recommends a union keyed on state with url required for done, and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [ts-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

The listing gallery now shows uploads in progress, failed ones and a retry button. Mind getting a TypeScript review on my uncommitted changes? I can't open files on this machine, so put the full review in your reply, exactly as written.
