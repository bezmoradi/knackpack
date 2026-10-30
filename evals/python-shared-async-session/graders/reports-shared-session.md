---
type: llm
---

load_dashboard in app/repos.py passes one AsyncSession to asyncio.gather, so load_orders, load_invoices and load_tickets run their await session.execute calls concurrently on the same session.
PASS if the review reports that a single AsyncSession is used by concurrent tasks through gather, which SQLAlchemy does not support, and suggests using one session per task or awaiting the loaders sequentially.
FAIL if the review does not report the shared-session concurrency problem in load_dashboard.
