---
type: llm
---

PASS if the review reports that notify/push_android.go is compiled only when the target OS is Android, because its name ends in `_android.go`, so the Linux build the Dockerfile produces (or any build for another OS) leaves the file out and the android-push provider never registers.
FAIL if it misses this, or treats the file name as harmless.
