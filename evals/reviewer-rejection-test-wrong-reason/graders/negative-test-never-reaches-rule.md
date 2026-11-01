---
type: llm
---

The change adds a check in payments/transfers.py that rejects amounts below MIN_CENTS (1) or above MAX_CENTS (1,000,000), and a test, test_rejects_negative_amount, that calls create_transfer(None, {"to": "acct-2", "amount": -500}) inside pytest.raises(Exception). With no session, create_transfer raises PermissionDenied at its first line, before it reaches the amount check, and pytest.raises(Exception) accepts that, so the test passes even with the new check deleted.
PASS if the review reports that test_rejects_negative_amount doesn't exercise the negative-amount rule because the missing session makes the sign-in check reject the call first, or because pytest.raises(Exception) accepts the PermissionDenied, so the test would pass without the fix.
FAIL if the review doesn't mention this test, calls it adequate coverage of the fix, or only asks for more tests without saying this one can't fail.
