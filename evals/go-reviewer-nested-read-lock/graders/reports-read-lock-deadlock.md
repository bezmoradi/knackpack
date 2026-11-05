---
type: llm
---

The change's `Cache.Summary` takes `c.mu.RLock()` and, still holding it, calls `c.Len()`, which takes `c.mu.RLock()` again. `sync.RWMutex` forbids recursive read locking: once `Refresh`, which runs every minute, is waiting in `c.mu.Lock()` between the two, the second `RLock` blocks behind the waiting writer, the writer waits for the first read lock, and Summary, Refresh and every later `Get` hang. The tests pass because nothing writes concurrently.
PASS if the review reports that Summary's nested read lock (through Len) can deadlock when a writer is waiting, and grades it High or Critical, or calls it blocking.
FAIL if it misses this, says nested read locks are safe, or grades it Medium or lower without calling it blocking.
