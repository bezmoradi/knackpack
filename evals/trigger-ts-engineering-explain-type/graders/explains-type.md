---
type: llm
---

`DeepReadonly<T>` in src/types.ts returns function types unchanged, turns arrays into `ReadonlyArray` of `DeepReadonly` elements, maps objects to the same keys with `readonly` and recurses into each property, and leaves primitives as they are. It changes only the type: nothing is frozen at run time, and `freezeSettings` returns the same mutable object.
PASS if the reply explains that it makes nested properties readonly recursively, including arrays' elements, and that functions are left alone (or that the function branch stops the recursion).
FAIL if it misdescribes the type (for example, says it freezes the object at run time or skips nested objects), or doesn't explain it.
