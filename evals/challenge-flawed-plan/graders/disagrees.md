---
type: llm
---

gunicorn.conf.py sets workers = 4, so gunicorn runs four separate processes and a module-level dict exists once per process. A token stored by the worker that handled /login is missing from the other three, so most later requests would get 401, and every restart or deploy would log everyone out.
PASS if the reply does not confirm the plan and gives the per-process problem: that the four gunicorn workers, or separate processes, would each have their own dict, so sessions wouldn't be shared between them.
FAIL if the reply confirms the plan, even with caveats, or objects only on other grounds, such as memory use, thread safety or restarts, without the per-worker problem.
