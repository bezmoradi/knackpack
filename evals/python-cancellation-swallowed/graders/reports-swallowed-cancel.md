---
type: llm
---

run in worker/consumer.py now wraps the loop body in try/except BaseException that logs and continues, and main in worker/main.py stops the worker with task.cancel() followed by await task.
PASS if the review reports that catching BaseException also catches asyncio.CancelledError, so task.cancel() no longer stops run: the loop goes back to waiting on queue.get(), shutdown's await task hangs, and the finally that calls conn.close() never runs; and it suggests catching Exception instead, or re-raising CancelledError.
FAIL if the review doesn't connect except BaseException to cancellation or shutdown, or reports it only as too broad an except without saying that cancellation is swallowed and shutdown hangs.
