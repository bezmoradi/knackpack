---
name: css-engineering
description: "Guide writing or changing CSS so the change fits the project: find its browser targets, build pipeline, stylesheet ownership, naming convention and design tokens first, then make the smallest maintainable change, with the right layout mechanism, responsive and right-to-left behavior, WCAG 2.2 AA accessibility, a fallback for any feature a target lacks, and a check of the result. Use whenever you write or edit stylesheets, style blocks, CSS Modules, Tailwind classes or CSS-in-JS, including layout fixes, theming, dark mode, responsive work and focus styles, even when the user doesn't say CSS. It never restructures a stylesheet, adds a methodology or framework, or renames existing classes unless asked. Not for reviewing CSS already written (the knackpack:css-code-reviewer agent, started only when the user asks for a review), the look and flow of a running app (the UI reviewer), React's own semantics (the React reviewer), or custom elements' behavior (the web-components-engineering skill)."
---

# CSS engineering

Write CSS the way the project already writes it, change as little as the requirement needs, and leave nothing that breaks for a keyboard user, a right-to-left reader, someone at 200% zoom or a browser the project supports. These rules hold for every edit, however small: a one-line style fix is where an unseen stacking context or an unsupported feature slips through.

## Rules that hold throughout

- **The project's conventions win.** Its naming scheme, token system, layer order, file layout and methodology decide, even where you'd choose differently. Read them before writing; never introduce BEM, utilities, cascade layers, `@scope`, a preprocessor or a CSS framework the project doesn't use, unless the user asks.
- **Smallest maintainable change.** Edit the stylesheet that owns the component. Don't restructure files, reorder imports, rename classes, reformat untouched rules or "modernize" working CSS on the side; each touches readers you haven't checked. If the right fix needs a wider change, such as a new token or a layer, say so and ask.
- **Class names, custom properties and layer names other code reads are a public interface.** JavaScript, tests, templates, other packages and a library's consumers may rely on them. Add, don't rename; when a rename is required, find every reader first.
- **Support is decided by the project's targets, not by newness.** CSS has no single version; each feature has its own support. Check every feature you use against the targets (step 1) with current data, since browsers now release every two weeks.
- **Install no package the user didn't ask for, and never run `npx`** (with no terminal attached it downloads and runs missing packages without asking), and never run a tool's fix or write mode (`stylelint --fix`, `prettier --write`) over files you didn't change. Use the tools already in `node_modules`, by path.
- **Say what you didn't verify.** A CSS change that wasn't seen in a browser is unverified; say which checks remain, rather than calling it done.

## 1. Learn the project's CSS

Read before writing, and keep the answers in mind for every step:

- **Browser targets:** `browserslist` in `package.json` or `.browserslistrc` (and its environment sections), a Baseline target in docs or build config, and floors the toolchain imposes: Vite 8's default CSS target is a fixed Baseline-widely-available set, Lightning CSS takes its own `targets`, and Tailwind v4 needs Safari 16.4, Chrome 111 and Firefox 128. With no targets declared, assume Baseline widely available and say so.
- **Pipeline:** Sass or Less, PostCSS plugins (Autoprefixer adds prefixes and polyfills nothing; `postcss-preset-env` may compile nesting), Lightning CSS, Tailwind's major version, CSS Modules, CSS-in-JS. Write source the pipeline understands: `&__element` concatenation is Sass and isn't valid in native nesting.
- **Ownership and architecture:** where global styles, the reset, third-party CSS and each component's styles live; the declared `@layer` order and where it's first stated; how components are isolated.
- **Tokens:** the token source and its tiers (primitives such as `--blue-600`, semantic roles such as `--color-text-muted`, component tokens), and how themes and dark mode switch them.
- **Naming:** measure the convention in the existing stylesheets, including how state is expressed (`.is-open`, `[aria-expanded="true"]`, `[data-state]`).
- **Who reads the classes** you might touch: `grep` the class names and custom properties across the repository.
- **Locales and modes:** right-to-left locales, vertical or CJK text, dark mode, and the accessibility level the project targets (WCAG 2.2 AA unless it says otherwise).

## 2. Write the change

**Reuse before adding.** Use an existing token for every color, space, radius, shadow, font size and z-index that has one; prefer the semantic token over the primitive. Add a token only when the role is new, named by role, not value, in the token source. Extend a component with a modifier or a custom property it exposes rather than reaching into it from a page (`.reports-page .media__title`).

**Pick the layout mechanism by the problem:**

- **Flexbox** for one dimension: rows of controls, wrapping chips, a sidebar and content. Give children that hold long text `min-width: 0` (or `min-height: 0` in a column), or long words and tables overflow the container.
- **Grid** for two dimensions and for aligned rows across items: use `minmax(0, 1fr)` where a track holds long content, `repeat(auto-fit, minmax(<min>, 1fr))` for card grids that reflow without breakpoints, and `subgrid` to align children across cards, spanning the parent tracks they share.
- **Intrinsic sizing first:** `min()`, `max()`, `clamp()`, `fit-content`, `max-inline-size` and wrapping let layouts adapt without breakpoints.
- **Container queries for components that land in different slots,** when the targets support them: the container is a wrapper, never the element that queries itself; `container-type: inline-size` (not `size`, which collapses a container whose height comes from its content); and a `container-name` on shared components.
- **Viewport media queries for page layout,** in the project's breakpoint set; avoid a 1 px gap or overlap between ranges.
- **Logical properties** (`margin-inline-start`, `inset-inline-end`, `text-align: start`) when the product ships right-to-left or vertical text, or is a library others localize; otherwise follow the file's existing style. Don't mix a physical and a logical property for the same side.

**Keep the cascade predictable:** match the specificity of the rules around it; no IDs or `!important` unless the project uses them for that purpose; `:where()` for defaults that consumers must override easily. Unlayered rules beat every layered rule, so put new rules in the layer the project uses for that kind of code. Native nesting's `&` takes the highest specificity of its parent list.

## 3. Avoid the traps that pass every linter

- **Stacking:** a `z-index` only competes within its stacking context. `transform`, `opacity` below 1, `filter`, `backdrop-filter`, `isolation`, `will-change`, `contain`, `position: fixed` or `sticky`, and a `z-index` on a positioned element or a flex or grid item all create one. Before raising a `z-index`, find the contexts of both elements; use the project's z-index scale. Dialogs opened with `showModal()` and popovers live in the top layer, where `z-index` does nothing.
- **Fixed and sticky:** an ancestor with `transform`, `filter`, `backdrop-filter`, `perspective`, `contain: layout` or `paint`, or `content-visibility: auto` traps `position: fixed` inside it. `position: sticky` needs an inset such as `top`, stops at its parent's end, and fails under any ancestor with `overflow: hidden`, `auto` or `scroll`.
- **Viewport units:** `100vw` includes a classic scrollbar and causes horizontal scrolling; prefer `100%`. On mobile, `100vh` is the large viewport and hides content behind the toolbar; use `100svh` or `100dvh`, with `100vh` first as a fallback if a target lacks them.
- **Silent drops:** a `var()` whose property is undefined makes the declaration fall to `unset`, not to an earlier declaration, so give `var()` a fallback argument; an `@property` with a relative-unit `initial-value` or a missing descriptor is ignored; one unsupported selector in a list drops the whole rule (except inside `:is()` and `:where()`); an `@import` after other rules is ignored; `light-dark()` needs `color-scheme: light dark`.
- **Hidden things:** an author `display` rule overrides the `hidden` attribute; `opacity: 0` leaves content focusable; `display: contents` on a button, link, list, table or heading breaks its accessibility.

## 4. Accessibility, as you write

Meet WCAG 2.2 at the project's level, AA by default:

- **Focus:** never remove an outline without a replacement on `:focus-visible`. Draw focus rings with an outline (offset if needed), or keep a transparent outline beside a `box-shadow` ring, since forced-colors mode removes shadows and repaints outlines.
- **Contrast:** 4.5:1 for text, 3:1 for large text and for the borders, icons and states that identify controls. Check every pair a new or changed color token produces, in each theme.
- **Forced colors:** don't draw meaning only with shadows, gradients or background images; in `@media (forced-colors: active)`, use system colors (`CanvasText`, `ButtonText`, `Highlight`); keep `forced-color-adjust: none` to swatches and similar.
- **Reflow and text:** fit 320 CSS px wide without two-way scrolling (data tables and code may scroll in their own box); let text containers grow (`min-height`, not a fixed `px` height with hidden overflow); never size text only in viewport units; break long strings with `overflow-wrap`.
- **Targets:** interactive elements at least 24 by 24 CSS px including padding, or spaced so they don't crowd.
- **Hover and focus:** anything shown on hover also shows on `:focus-visible` or `:focus-within`; hover-only effects go inside `@media (hover: hover)`.
- **Sticky bars:** give the scroll container `scroll-padding-top` (or `-bottom`) at least the bar's height, so focused controls aren't hidden under it.
- **Order:** keep visual order matching DOM order for anything focusable or meaningful; don't reorder with `order`, `*-reverse` or grid placement.
- **Motion:** put non-essential animation inside `@media (prefers-reduced-motion: no-preference)`, or tone it down under `reduce` with a tiny duration rather than `0s`, which stops end events from firing. Anything that moves by itself for more than five seconds beside content needs a pause control.
- **Dark mode:** set `color-scheme` with the theme so form controls and scrollbars match.

## 5. Adopting newer features

Classify each feature you use by the targets, with current data (MDN's compatibility tables, webstatus.dev, web.dev's Baseline pages):

- **Production-ready,** supported by every target: use it, with no fallback.
- **Progressive enhancement,** missing in some targets: write the working baseline first, then the enhancement, so a browser without it still works: an earlier declaration it can parse, or `@supports` testing the exact feature (`@supports (display: grid)` doesn't test subgrid). Essential UI must not depend on it.
- **Experimental,** in one engine or a changing specification: don't use it unless the user decides to, with a fallback.

Don't add a fallback for a feature every target supports, and don't adopt a feature only because it's new.

## 6. Verify

- **Lint** with the project's own Stylelint or Biome from `node_modules`, on the files you changed, without fix or write options; fix only what you introduced.
- **In a browser,** when a preview is running or the user can open one, check the changed component at about 1440, 768, 375 and 320 px wide, at 200% zoom, with long and translated text, by keyboard (focus visible and not covered), and, where relevant, with `dir="rtl"`, dark mode, forced colors and reduced motion (browser developer tools can emulate the last three).
- **Report** what you checked and what still needs checking, by name. For an independent review of the change, the user can ask for knackpack's CSS reviewer.
