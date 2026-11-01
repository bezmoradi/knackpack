---
type: llm
---

pyproject.toml sets [tool.pytest.ini_options] python_files = ["test_*.py"]. The change adds its regression tests in tests/proration_rounding_test.py, a name that pattern doesn't match, so pytest never collects them; tests/test_proration.py, which pytest does run, has no half-cent case.
PASS if the review reports that the new test file isn't collected or run because its name doesn't match the configured python_files pattern, so the rounding fix has no regression test that actually runs and a green pytest run doesn't cover it.
FAIL if the review doesn't notice that the new tests never run, or treats the passing pytest run or the presence of the test file as covering the fix.
