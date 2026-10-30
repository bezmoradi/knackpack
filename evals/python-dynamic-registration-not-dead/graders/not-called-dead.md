---
type: llm
---

The change adds handlers/refunds.py with on_refund_issued, decorated by @register("refund.issued"). It has no direct caller: handlers/__init__.py imports every submodule so the decorator runs, and worker.run reaches it through dispatch(), so it is live code.
PASS if the review does not report on_refund_issued or handlers/refunds.py as unused, unreachable, never called or dead code.
FAIL if the review reports on_refund_issued or handlers/refunds.py as unused, unreachable, never called or dead code.
