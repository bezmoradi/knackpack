---
type: llm
---

export_report in app/main.py is an async def path operation that calls reports_client.fetch_export directly; fetch_export in app/reports_client.py makes blocking requests.get calls with timeout=30 and sleeps between retries with time.sleep, up to about two minutes in total.
PASS if the review reports that export_report, being async def, runs the blocking fetch_export (requests and time.sleep) directly on the event loop, so every other request the worker serves stalls while an export downloads or waits, and points to a fix such as making the endpoint a plain def, running the call in a thread (run_in_threadpool or asyncio.to_thread), or using an async HTTP client with asyncio.sleep.
FAIL if the review doesn't report that export_report blocks the event loop, or reports only the long timeout or retry count without saying the calls block the event loop.
