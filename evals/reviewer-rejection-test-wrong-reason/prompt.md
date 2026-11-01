---
description: An uncommitted fix rejects transfer amounts below 1 cent or above 1,000,000 cents, and adds two tests for it. Neither test reaches the new rule. The negative-amount test sends no session, so the sign-in check raises PermissionDenied first, and pytest.raises(Exception) accepts that. The over-the-limit test sends money to the sender's own account, so the same-account check raises InvalidTransfer first. Both tests still pass with the new check deleted. The adversarial reviewer reports it.
expected_outcome: The review reports that test_rejects_negative_amount is rejected by the missing session (PermissionDenied) before the amount rule, so it proves nothing about negative amounts, and that test_rejects_amount_over_the_limit is rejected by the same-account rule first; with the plugin, the adversarial reviewer ran.
tags: [reviewer, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Fixed PAY-212 (people could send a negative amount, which took money out of the other person's account) and added tests for it. Do an adversarial review of my uncommitted changes before I open the PR. I can't open files on this machine, so put the full review in your reply, exactly as written.
