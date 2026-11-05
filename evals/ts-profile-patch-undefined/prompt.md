---
description: "A new PATCH /profiles/:id handler copies the four editable fields from the body into a ProfilePatch, so every field the client didn't send is present with the value undefined. updateProfile spreads the patch over the stored profile, so a name-only update from the app wipes the user's bio, website and favourite cuisine. tsc accepts it because exactOptionalPropertyTypes is off. The reviewer reports the present-but-undefined keys and the data loss."
expected_outcome: "The review reports that building the patch as { displayName: body.displayName?.trim(), bio: body.bio, ... } creates keys whose value is undefined, which the spread in updateProfile writes over the stored values, so a PATCH that sends one field (as each settings screen does) erases the others, contrary to the documented 'absent means unchanged'; it recommends copying only keys that are present (or enabling exactOptionalPropertyTypes) and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [ts-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

The profile PATCH endpoint is finally done, the settings screens in the app are waiting on it. Can someone review the TS before I commit? I can't open files on this machine, so put the full review in your reply, exactly as written.
