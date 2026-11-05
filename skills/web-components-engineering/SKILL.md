---
name: web-components-engineering
description: "Guide writing or changing Web Components so they fit the project and work for every consumer: learn its browser targets, consuming frameworks and versions, component library and conventions first, then design a stable public contract (tag, attributes, properties, events, slots, parts) and implement it with idempotent lifecycle and cleanup, shadow or light DOM as fits, accessibility across shadow boundaries, native form association, server-rendered roots reused, and a real-browser check. Use whenever you create or edit a custom element, a shadow root, a Lit, FAST or Stencil component, a form-associated control, or a component library's registration, types or docs, even when the user doesn't say Web Components. It adds no library, base class or TypeScript migration unless asked. Not for reviewing components already written (the knackpack:web-components-code-reviewer agent, started only on request), CSS layout and cascade (the css-engineering skill), or React's own semantics (the React reviewer)."
argument-hint: "[change]"
---

# Web Components engineering

Build elements the way the project already builds them, change as little as the requirement needs, and leave nothing that breaks when the element is moved, upgraded late, used from another framework, operated by keyboard or screen reader, or loaded in a browser the project supports. These rules hold for every edit: a one-line change to a lifecycle callback is where a leak or a lost value slips through.

## Rules that hold throughout

- **The project's conventions win.** Its library (plain `HTMLElement`, Lit, FAST, Stencil), base classes, naming, registration pattern, shadow or light DOM choice, styling approach and documentation format decide, even where you'd choose differently. Read them before writing; never introduce a library, a base class hierarchy, a reactive system, a global store or a TypeScript migration unless the user asks.
- **The public contract is API.** Tag names, attributes, properties, methods, events and their `detail`, slots, CSS parts, custom properties and custom states are what consumers rely on. Add, don't rename; when a rename is required, find every consumer first (`grep` the tag, class, event and slot names), and for a published package treat it as a breaking change.
- **Prefer the platform.** Native elements inside the shadow root, platform events, `ElementInternals` and constructable stylesheets before custom machinery. Adopt a library only when its value is demonstrable for this project.
- **Support is decided by the project's targets and consumers.** Check every platform feature against the browser targets and every integration against the consuming framework's actual version, with current data (MDN's compatibility tables, webstatus.dev, the framework's documentation).
- **Install no package the user didn't ask for, and never run `npx`** (with no terminal attached it downloads and runs missing packages without asking), and never run a tool's fix or write mode over files you didn't change. Use the tools already in `node_modules`, by path.
- **Say what you didn't verify.** A component not exercised in a real browser is unverified; name the checks that remain rather than calling it done.

## 1. Learn the project

Read before writing, and keep the answers in mind for every step:

- **Application or published package:** `package.json` (`exports`, `files`, `sideEffects`, `peerDependencies`, a `customElements` field), a `custom-elements.json` manifest, generated `.d.ts` files, the README or Storybook that documents components.
- **Consumers:** where the element is used (plain HTML, server templates, React, Vue, Angular, Svelte) and each framework's version from the lockfile; for a library, the frameworks its docs promise.
- **Browser targets:** `browserslist` or a Baseline target; with none, assume Baseline widely available and say so.
- **How elements are written:** the library and version, base classes, where and how `define` is called, whether definitions load eagerly or lazily, shadow or light DOM and why, how styles are shared, whether the server renders declarative shadow DOM.
- **Tooling:** TypeScript (`target`, `useDefineForClassFields`), ESLint plugins (`eslint-plugin-wc`, `eslint-plugin-lit`), the test runner and whether it uses real browsers.

## 2. Design the contract first

Write down, before the class, what consumers will touch:

| Interface | Convention |
| --- | --- |
| Tag name | lowercase, with a hyphen, in the project's prefix |
| Class | PascalCase, matching the tag |
| Attribute | lowercase kebab-case, serializable configuration only |
| Property | camelCase; rich values (objects, arrays) as properties only |
| Event | lowercase kebab-case name, documented `detail` |
| Slot, part | lowercase kebab-case, named for the role |
| Custom property | the project's namespace (`--prefix-name`) |
| Private state | `#private` fields |

Decide each default, what an invalid value does, which attributes reflect, which events fire and when, and what the keyboard does. Keep internals private: expose only what a consumer needs.

## 3. Implement the element

**Constructor:** call `super()` first; attach the shadow root (or reuse a server-rendered one, step 6), create private state, add listeners on the element itself. Never read or add attributes or children there: an element created by `createElement` or the parser after definition fails if its constructor adds them, while an upgrade doesn't check, so the bug depends on loading order.

**`connectedCallback` runs on every insertion, including every move.** Make setup idempotent: one-time work in the constructor or behind a flag; connection-scoped work (listeners on `window`, `document` or other elements, observers, timers, subscriptions, fetches) created here and released in `disconnectedCallback`. Use a fresh `AbortController` per connection, pass its `signal` to `addEventListener` and `fetch`, and abort it on disconnect; a listener added with an already-aborted signal is never added, so don't reuse the old one. Disconnection isn't destruction: the element must set up again cleanly when reinserted. Check `this.isConnected` before async results touch the DOM.

**Properties set before the element is defined** become own properties that hide your accessors after the upgrade. In `connectedCallback`, for each public property: if `Object.hasOwn(this, name)`, read it, `delete this[name]`, assign it again.

**Attributes and properties:** list observed attributes in lowercase in `static observedAttributes`. Getters read the attribute (or private state for rich values); setters write it; `attributeChangedCallback` only performs side effects, so nothing loops. Booleans use presence: `toggleAttribute(name, Boolean(value))`, never `setAttribute(name, value)`, which writes `"false"`. Never overwrite a consumer's `role`, `tabindex`, `aria-*`, `class` or `style`; set defaults only when absent, or through `ElementInternals`.

**Events:** dispatch component events from the host (`this.dispatchEvent(new CustomEvent('item-select', { bubbles: true, detail }))`); an event dispatched from inside the shadow root without `composed: true` never reaches the page. `change` and `submit` aren't composed, so re-dispatch your own `change` when an inner input changes; `click`, `input` and `keydown` already escape, so don't re-dispatch those. Send copies in `detail`, never internal objects. Don't fire events in response to the consumer setting a property.

**Inheritance:** an override of a lifecycle callback calls `super`'s; a subclass's `observedAttributes` includes the parent's.

**Registration:** follow the project's pattern. Remember that `define` throws if the name is taken, and that a `customElements.get` guard hides two different versions rather than fixing the conflict; prefer one shared copy (a peer dependency). A package whose modules register on import lists them in `sideEffects`, or bundlers drop them.

## 4. Shadow DOM, slots and styling

- Choose shadow DOM for encapsulated rendering and styles; choose light DOM when the element enhances server-rendered markup, needs global styles, or needs ID references and native form submission across its content. Follow a documented project choice.
- Use open roots by default. A closed root isn't a security boundary: same-page scripts can still reach the element's data, so never use one to protect secrets.
- Share styles with one constructed `CSSStyleSheet` per class in `adoptedStyleSheets` (or the library's equivalent), not a `<style>` per instance.
- Expose styling deliberately: custom properties for theme values, `part` for elements consumers may restyle, `exportparts` through nested components, custom states (`internals.states`, `:state()`) for state styling. Document each. Avoid `:host-context()`, which only Chrome supports.
- Only the host's direct children are slotted, and content whose `slot` matches no slot isn't rendered; provide fallback content, and use `slotchange` to react to assignment changes.
- With a focusable control inside, use `delegatesFocus: true` instead of `tabindex` on the host, which creates two tab stops.

## 5. Accessibility, as you write

Meet WCAG 2.2 at the project's level, AA by default:

- Put native elements inside the shadow root (`<button>`, `<input>`, `<a href>`); a `<div>` with a role needs keyboard handling, focusability and a name, and usually misses one.
- ID references (`aria-labelledby`, `aria-describedby`, `aria-controls`, `<label for>`) don't cross shadow boundaries. Put the label inside the shadow root, slot it, accept the text through an attribute, make the element form-associated so `<label>` names it, or use element reflection (`ariaLabelledByElements`) for references outward. Reference Target works only in Chrome as of late 2026.
- Give the host default semantics through `ElementInternals` (`internals.role`, `internals.ariaChecked`, ...), which consumer attributes can override.
- Every pointer action has a keyboard path; focus is visible and moves deliberately; use `<dialog>` with `showModal()` for modals rather than a hand-built focus trap.
- Keep live regions in the DOM, empty, before their text changes.
- Respect `prefers-reduced-motion` and forced colors in component styles (see the css-engineering skill).

## 6. Forms and server rendering

**Form controls** set `static formAssociated = true`, call `attachInternals()` once in the constructor, and then:

- call `setFormValue(value, state)` on every change, at start and after reset (`null` means not submitted);
- set `setValidity(flags, message, anchor)` with a message and an anchor inside the element, and `setValidity({})` when valid;
- implement `formResetCallback`, `formDisabledCallback` (disable inner controls too) and `formStateRestoreCallback`;
- reflect `name`, `value`, `disabled` and `required` like a native control.

Don't fall back to a hidden input unless a target lacks form-associated custom elements, and then design and state the fallback.

**Server-rendered roots:** when the server sends `<template shadowrootmode>`, the root already exists. Calling `attachShadow()` again empties it. Reuse it:

```js
this.#internals = this.attachInternals();
const root = this.#internals.shadowRoot ?? this.attachShadow({ mode: 'open' });
```

Then hydrate the existing nodes instead of re-rendering. Add server rendering only where the application needs it.

## 7. Framework consumers and types

- **React 19** sets a prop as a property when the defined element has that property, otherwise as an attribute, and maps `onname` to a listener for `name` with the case kept. So define the element before React renders it, and use lowercase or kebab-case event names. **React 18 and earlier** pass everything as attributes and ignore custom events: bridge with a ref and an effect, or a wrapper.
- **Vue** needs `compilerOptions.isCustomElement`; **Angular** needs `CUSTOM_ELEMENTS_SCHEMA`; **Svelte 5** sets properties only where the prototype has a setter, so expose accessors, not plain class fields.
- Keep TypeScript declarations (`HTMLElementTagNameMap`, event maps, JSX `IntrinsicElements`) in step with what the code dispatches and accepts. With Lit and `useDefineForClassFields`, declare reactive properties with `accessor` or `declare` so class fields don't shadow them. Validate untrusted runtime values; types don't.

## 8. Security

Build DOM from a static `<template>` and set `textContent` and attributes. Never pass attributes, properties, URL parameters or fetched data to `innerHTML`, `insertAdjacentHTML` or `setHTMLUnsafe`; a shadow root doesn't stop script. Allow only safe URL schemes in `href` and `src`, and never `import()` a URL from an attribute.

## 9. Verify

- **Type check and lint** with the project's installed tools, on the files you changed, without fix options.
- **Test in a real browser** (Web Test Runner, Playwright), since jsdom and happy-dom lack layout, focus delegation and most form-association APIs. Cover what you changed: definition after properties were set, removing and reinserting (no duplicates, listeners restored), reflection including `false`, events received outside the host, slot assignment, form submission, reset and disabling, keyboard operation and accessible names, and server-rendered upgrade where used.
- **Document** the contract where the project keeps it (README, manifest, stories) and note breaking changes.
- **Report** what you checked and what still needs checking. For an independent review before calling a substantial component done, suggest the user ask for knackpack's Web Components reviewer.
