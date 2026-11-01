---
type: llm
---

The change adds test_rejects_amount_over_the_limit, which calls create_transfer({"account_id": "acct-1"}, {"to": "acct-1", "amount": 2_000_000}) inside pytest.raises(InvalidTransfer). Sending to your own account raises InvalidTransfer("choose another account to send to") before the amount is checked, so the test passes even with the upper limit deleted.
PASS if the review reports that this test is rejected by the same-account rule (to equals the sender) before the limit is checked, so it doesn't prove the upper limit.
FAIL if the review doesn't mention this test or treats it as covering the limit.
