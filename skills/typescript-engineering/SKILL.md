---
name: typescript-engineering
description: "Guide writing or changing TypeScript, or JavaScript checked with JSDoc, so its types make real guarantees: learn the project's TypeScript version, tsconfig, runtime and module system first, then validate untrusted data at the boundary instead of casting it, model states with discriminated unions, keep generics that relate something, configure tsconfig and package exports for what actually loads the code, keep declarations in step with runtime behavior, and verify with the project's own type check. Also assesses, on request, whether and how a JavaScript project should adopt TypeScript. Use whenever you create or edit .ts, .tsx, .mts or .cts files, type declarations, a tsconfig, or JSDoc types, even when the user doesn't say TypeScript. It adds no library, upgrade or migration unasked. Not for reviewing code already written (the knackpack:typescript-code-reviewer agent, started only on request), React's own semantics, custom element behavior, or choosing between technologies in general (the research skill)."
argument-hint: "[change or question]"
---

# TypeScript engineering

Write TypeScript the way the project already writes it, so that its types say what the code actually does, and so that nothing breaks at run time that the compiler appeared to accept. Types are erased: every rule here is about the gap between what the compiler checks and what runs. These rules hold for every edit, including a one-line cast.

## Rules that hold throughout

- **The project's setup wins.** Its TypeScript version (from the lockfile), compiler flags, module system, lint rules, validation library, naming and error-handling style decide, even where you'd choose differently. Never add a library, a stricter flag across the project, a compiler upgrade or a migration unless the user asks; suggest them separately if they'd help.
- **A type is not a check.** `as`, `!`, a generic argument, an annotation and a `.d.ts` make claims the compiler believes without proof. Make a claim only when something in reach establishes it, and validate data from outside before typing it.
- **Prefer inference; annotate boundaries.** Let the compiler infer locals and internal return types. Annotate exported functions, public types and anything whose inferred type would expose internals or change silently, and follow the project's rule where it has one.
- **Simple beats clever.** Use the plainest type that prevents the mistakes that matter here. Type-level machinery earns its place only by protecting a contract callers rely on.
- **Install no package the user didn't ask for, and never run `npx`** (with no terminal attached it downloads and runs missing packages without asking), and never run a fixing or formatting mode over files you didn't change. Use the tools already in `node_modules`, by path.
- **Say what you didn't verify.** Code that hasn't been type-checked with the project's configuration, and run where behavior matters, is unverified; name the checks that remain.

## 1. Learn the project

Read before writing:

- **Version and compiler:** the `typescript` version the lockfile resolves. From 7.0 it is the native compiler (still `tsc`), which has no stable compiler API; 6.0 changed defaults (`strict` on, `module: esnext`, `target: es2025`, `types: []`, `rootDir` the tsconfig's folder) and 7.0 removed `baseUrl`, `moduleResolution: node10`/`classic`, `target: es5`, `outFile` and AMD/UMD/System. Write code and config for the version installed.
- **The tsconfig that applies** to the files you touch: follow `extends` and `references`, and note `strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `module`, `moduleResolution`, `target`, `lib`, `isolatedModules`, `verbatimModuleSyntax`, `erasableSyntaxOnly`, `allowJs` and `checkJs`.
- **How the code runs:** `tsc` output run by Node, a bundler that strips types (Vite, esbuild, SWC, Babel), Node's own type stripping, `tsx`, Bun or Deno. Only `tsc` checks types.
- **Application or library:** for a package, `exports`, `types`, `type`, `files`, `peerDependencies` and whether declarations are generated or hand-written.
- **Conventions:** the validation library or guard style at boundaries, how errors are returned or thrown, typescript-eslint and its typed rules, the test runner and any type tests, and what CI runs.

## 2. Validate at the boundary

Data from outside has whatever shape the sender chose: `JSON.parse`, `fetch` responses, request bodies and parameters, form data, `process.env`, files, storage, messages, untyped JavaScript modules.

- Parse it once where it enters, into a trusted type, and handle failure there. Use the project's schema library if it has one; otherwise write a guard that checks every field the code relies on. Don't add a library for one boundary unless the user wants it.
- Accept `unknown` from the source and narrow it; never `as` it to the domain type.
- Validate environment variables once at startup; don't declare them as always present in a global `ProcessEnv` augmentation.
- Beware coercion that turns bad input into plausible values: `Number("")` is `0`, `Boolean("false")` is `true`.
- Don't copy parsed objects with `Object.assign` or a deep merge into existing objects: a `__proto__` key pollutes the prototype. Use spread, `structuredClone`, `Map`, or objects created with `Object.create(null)`.

## 3. Model states, not bags of fields

- When a value has distinct states, use a discriminated union whose members carry exactly their own fields, with a required literal discriminant. Constructing an impossible combination then fails to compile, and narrowing gives each branch its fields without `!`.
- Handle every member: in a `switch` over a closed union, end with `default: { const unreachable: never = value; … }` so adding a member breaks the build until it's handled. For open sets (values a server may add later), keep that check and add a runtime fallback that logs, rather than throwing in production.
- Prefer literal unions to enums when code may run under Node's type stripping or `erasableSyntaxOnly`, or a per-file transpiler (never export a `const enum` from a library: consumers see it as ambient, which `isolatedModules` rejects); otherwise follow the project.
- Use a branded type only with a single constructor that validates; casting to a brand at call sites makes it meaningless.
- Know the difference between `p?: T` (may be absent) and `p: T | undefined` (present, possibly undefined). Without `exactOptionalPropertyTypes` the compiler mixes them, so when absence means something to the consumer, build the object without the key rather than with `undefined`.

## 4. Functions, generics and async code

- Write callback and handler types with property syntax (`onPick: (item: Item) => void`), not method shorthand, so the compiler checks handler parameters contravariantly.
- Give a function overloads only when callers truly get different return types for different inputs, and make sure every result the implementation can produce is declared in some overload; otherwise use one signature with a union.
- A type parameter must relate inputs to outputs or to each other. Never write a generic used only in the return type (`load<T>(): T`): it's a cast every caller makes unchecked. Constrain to what the body needs: for a key whose value becomes a string or property key, take a function returning the key (`(item: T) => K` with `K extends PropertyKey`) rather than `keyof T`.
- Await every promise or hand it to something that handles its rejection; never pass an `async` function where a `void` callback is expected and its completion or errors matter (`forEach(async …)`).
- Catch as `unknown` and narrow (`err instanceof Error`) before reading properties.
- Use `satisfies` to check an object against a type while keeping its literal types, and `as const` for literal lookup tables.

## 5. Compiler and module configuration

Change configuration only as the task needs, and only for what actually runs the code:

- **Resolution must match the runtime.** `tsc` output run by Node needs `module: nodenext` (or `node20`) and relative imports with `.js` extensions; `moduleResolution: bundler` is for code a bundler loads. Node running `.ts` directly needs `.ts` extensions (with `rewriteRelativeImportExtensions`, or `allowImportingTsExtensions` and `noEmit`), `erasableSyntaxOnly` and `verbatimModuleSyntax`, and no decorators.
- **Per-file transpilers** (Vite, esbuild, SWC, Babel) need `isolatedModules` (or `verbatimModuleSyntax`), and import types with `import type`.
- **`lib` doesn't polyfill:** don't use an API newer than the oldest runtime the project supports just because `lib` includes it.
- **Strictness:** for new projects use `strict` plus `noUncheckedIndexedAccess` and consider `exactOptionalPropertyTypes`; in existing ones, raise flags only on request, one at a time, fixing what each reveals.
- **`skipLibCheck`** skips every `.d.ts`, the project's own included. Don't add it to make an error go away; fix the error, or keep hand-written declarations checked another way.
- **Package exports:** once `exports` exists it's the whole public surface, so list every subpath consumers import; put `types` first in each condition; give ESM and CommonJS entry points their own declarations. Importing named exports from a CommonJS package into ESM works only if Node can detect them statically; when unsure, import the default and destructure.

## 6. Libraries, declarations and public API

- Keep declarations in step with runtime behavior. Generate them with `tsc --declaration` where possible; when they're hand-written, update them in the same change as the code, and treat a changed signature as breaking.
- Annotate exported functions and types so inference can't leak internal types or widen silently; `isolatedDeclarations` enforces this where the project uses it.
- A public change is breaking when it removes or renames an export, narrows a parameter, widens a return type, adds a required input property, adds a union member consumers switch over, changes a generic's parameters, raises the minimum TypeScript version consumers need, or changes module kind. Say so and follow the project's versioning.
- Types from dependencies that appear in public signatures make those dependencies part of the API: list them in `dependencies` or `peerDependencies`.
- Put global augmentations (`declare global`) in a module file, and remember that `declare module "pkg"` in a file without imports or exports replaces the package's types rather than extending them.

## 7. JavaScript and migration

**In JavaScript files,** follow the project: if it checks JS (`checkJs`, `// @ts-check`), write accurate JSDoc (`@param`, `@returns`, `@typedef`, `@type`) whose types say exactly what the code returns, including `null` and failure cases. TypeScript 7 dropped `@enum`, constructor-function patterns and Closure-style types in JSDoc. Don't convert files to TypeScript unless asked.

**When asked whether a JavaScript project should adopt TypeScript,** assess before recommending. Read the code and history rather than guessing:

- current language inventory (files, JSDoc, existing checking) and test coverage;
- the defects in recent fixes or issues that types would have caught, and those they wouldn't;
- public API and module boundaries, and where untrusted data enters;
- dependency and tooling compatibility (bundler, test runner, lint, TypeScript 7's missing compiler API for tools that need it);
- build and runtime constraints, and the team's appetite.

End with one recommendation and its reasons: **full migration**, **incremental migration**, **type-checking JavaScript with JSDoc**, **keeping JavaScript with targeted declarations** for the riskiest boundaries, or **keeping the current approach**. TypeScript is not always the answer. For an incremental plan, give stages: establish checking without changing runtime behavior (often `allowJs` and `checkJs` per file), type the shared domain models and boundaries first, convert the modules with the most risk and change, raise strictness flag by flag, and measure what it catches before deciding to continue. Never mix migration with unrelated refactoring, replace `any` with `unknown` only to cast it back, or call it done because the compiler is quiet.

## 8. Type-level code and compiler cost

- Reach for conditional, mapped, template-literal or recursive types only to protect a contract callers rely on, and prefer an explicit signature that gives a one-line error over inference that gives thirty.
- Bound recursion: a recursive type over recursive data hits TS2589 ("excessively deep and possibly infinite") and fails the build.
- Don't re-implement runtime logic in types; derive types from runtime values (`typeof`, `as const`) or the other way, so they can't drift.
- When the build or editor slows, measure with `tsc --extendedDiagnostics` (instantiations, check time) before and after, rather than guessing.

## 9. Verify

- **Type-check** with the project's own command (`tsc --noEmit`, `tsc -b`) and configuration, with the installed compiler, on the whole project the change affects. If the build only transpiles (Vite, esbuild, SWC), the type check is a separate step; make sure it still runs.
- **Lint** the files you changed with the project's configuration, without fix options.
- **Run what the types can't prove:** the boundary validation against a malformed input, the module loading under the real runtime (for a Node package, import it with Node after building), and the tests for the changed behavior. For a library's public types, add `@ts-expect-error` cases or use the project's type-test tool.
- **Report** what you checked and what still needs checking. For an independent review before calling substantial TypeScript work done, suggest the user ask for knackpack's TypeScript reviewer.
