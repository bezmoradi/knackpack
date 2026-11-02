# software-factory

Start a Claude Code session in the terminal, then carry on from a page in your browser. The page opens on an overview of every Claude Code session on this machine: how many need you, which are working, and what each is doing. Click one to see its details. The session where you ran `/factory` opens live, and the page and the terminal stay in step both ways:

- what you type in the terminal, Claude's answer as it streams, each tool call and each agent show on the page;
- a message you type on the page runs in the same session as your own words, and the terminal shows it;
- **Stop** ends the current turn;
- Claude's questions and permission prompts appear as cards below the conversation, just above the message box, which the page scrolls to when one arrives; you can answer on the page or in the terminal, and the first answer wins;
- the side panel's execution path shows where the task stands: Define (agreed requirements), Plan, Implement (the current commit), Verify (knackpack's adversarial and slop reviewers, each with its verdict and a **Run** button that asks Claude to start it) and Deliver (whether Claude may push);
- while the page is open, Claude can't push until the current commit has a plan behind it and both reviewers have passed it, as the push gate below describes;
- the side panel shows the session's knackpack intent record: open questions, agreed requirements, assumptions and what's built.

The top bar, tabs, message box and status bar stay put; only the conversation scrolls, with its scrollbar beside the text rather than at the window's edge, and the wheel scrolls it from the empty margins too. On a window 1,000 px or wider the side panel sits beside the conversation and scrolls on its own; on a narrower one it follows the conversation.

Other sessions open read-only: what they're waiting on, the questions asked and answered, agents and their verdicts, tasks and intent record. To control one from the browser, run `/factory` in it. The overview lists other sessions only while knackpack records them (`/knackpack:software-factory on`); it reads the session list knackpack writes for its own page.

It's part of the [knackpack](../../README.md) marketplace and installs knackpack with it.

## Install

```text
$ claude plugin marketplace add bezmoradi/knackpack
$ claude plugin install software-factory@knackpack
```

It needs:

- Claude Code 2.1.292 or later, the version knackpack needs; plugin code itself needs 2.1.286 (tested with 2.1.316). An organization that allows only managed plugin code (`allowManagedModsOnly`) blocks it.
- Node.js 18 or later on your `PATH`. A `node` found inside the session's project folder is never used.
- macOS or Linux. Windows is untested.

## Use

| Command | What it does |
|---|---|
| `/factory` | Starts the page for this session and opens it in your default browser |
| `/factory link` | Copies a one-time link to the clipboard instead, for another browser or profile |
| `/factory stop` | Closes the page and stops its local server |

Nothing runs until you type `/factory`, and everything stops when the session ends.

A link works once, within a minute. After that the page keeps its own key until you close the tab, press **Disconnect**, run `/factory` again, or leave it closed for 15 minutes. Opening a used link again disconnects every page of the session and warns you in the terminal, because it means someone else had the link.

**Suggestions.** As in the terminal, typing `/` at the start of a message lists the session's slash commands and skills, and typing `@` lists files in the project and the agents Claude Code offers, each filtered as you type. Arrow keys move through the list, Tab or Enter puts the choice in the message, and Esc closes it. Picking an agent writes `@agent-<name>`, which asks Claude to use that agent. Agents appear once Claude Code has offered them to Claude in this session. Files come from the session's folder, leaving out dot folders other than `.github` and `.claude`, folders such as `node_modules`, `dist` and `build`, and symbolic links.

A message that starts with `/` runs that command as if you had typed it in the terminal, built-in commands included, so `/clear`, `/compact` and `/exit` work from the page too; its output shows under the command's name. A command can't carry images. Messages that start with `!` can't be sent from the page: shell lines run only from the terminal.

**Images.** Paste a screenshot with Cmd+V (Ctrl+V on Linux) or drop an image file onto the message box: it shows as a thumbnail at the right, above the message box, that you can remove before sending, and you can send it with or without text. PNG, JPEG, GIF and WebP are accepted, up to 4 a message; one larger than 1568 px on its longest side is scaled down first, and one still over 2.5 MB is refused. A plugin can't attach an image to a prompt the way the terminal does, so Claude receives your message after a note naming each image, and sees it by calling the plugin's `pasted_image` tool, which Claude Code allows without asking. If Claude Code wouldn't register that tool, the page says the images couldn't be passed on, and Claude gets your text after a note saying so.

**Tabs.** As in VS Code's editor, each session you open from the overview gets a tab under the top bar. **All sessions** is the first tab and can't be closed; this session's tab opens by itself when the page connects. Clicking a session that's already open switches to its tab. Each tab but **All sessions** shows a ×, which closes the tab only: the session keeps running and stays on the overview. A tab whose session needs you shows a yellow dot where the × would be, which turns into the × when you point at it, and **All sessions** shows the dot when another session needs you. Closing the tab you're on goes back to the one you used before it. Arrow keys, Home and End move between tabs, and a middle click closes one. Only the middle of the page scrolls: the top bar, the tabs, the message box and the status bar stay where they are, and the scrollbar is a thin one that shows while the pointer is over that area. Each tab keeps its scroll position, and sending a message from the page scrolls to the end of the conversation. The address stays `http://127.0.0.1:<port>/`: the open tab is remembered in the browser tab's session storage, so a reload brings back the overview, this session's tab and the tab you were on, and the others close. The browser's Back and Forward don't switch tabs.

**Replies** render their Markdown as the terminal does, following GitHub-flavored Markdown: headings, bold, italics, strikethrough, inline code and code blocks, bullet, numbered and task lists, quotes, rules, links and tables. A table takes its column alignment from the `:---:` row and scrolls sideways in its own box when it's wider than the conversation. A link opens in a new tab only when its address starts with `http` or `https`; any other link shows its text alone, with the address when you point at it. Inline HTML and images show as text. Plans in the plan card render the same way.

**Tool calls** show as the terminal shows them: a dot that's grey while the tool runs, green when it's done and red when it failed or was denied, the tool's name and its argument, and a line under it with the outcome, worded by the plugin from the tool's own result: the first lines of a command's output, the lines read, added or removed, a fetch's size and status, or the first line of an error.

**Push gate.** While the page is open, a push Claude makes, itself or through a subagent, is refused until three things hold:

- **A plan:** a `PLAN.md` or `PLAN-<name>.md` from `/knackpack:plan-implementation`, in the session's knackpack folder (`$TMPDIR/claude-<session id>/`) or named on the Files line of the session's intent record. Research shows as done or skipped and never holds a push.
- **Two reviews of the commit being pushed:** one by `knackpack:adversarial-reviewer` and one by `knackpack:slop-reviewer`, each started and finished on the commit that's checked out. A new commit makes them stale, so commit first, then review, then push.
- **No blocking verdict:** "Changes required" and "Needs verification" block for the adversarial reviewer, "CHANGES REQUIRED" and "NEEDS CONTEXT" for the slop reviewer. A reply with no verdict the gate recognizes counts as not run.

A blocking verdict can be overridden on the page: **Override**, then **Confirm override** within 5 seconds. The override holds for that commit only, shows on the timeline, and Claude is told about it when the push goes through.

A push is a Bash command with `git … push` or `git subtree push` in it, `gh pr create`, `gh repo sync`, or the push, file-writing and branch-creating tools of an MCP server whose name contains `github`. While the page is open, only a plain `git push` of the current branch or `HEAD`, with nothing else in the same call and none of `--all`, `--mirror`, `--tags`, `--delete` or another refspec, or a plain `gh pr create`, can pass. Anything else is refused with a request to push plainly, since a command that commits and then pushes would push a commit nobody reviewed. When the gate can't check a push, for example because it can't read the current commit, it refuses. The gate reads the commit from the repository's `.git` files without running git, since a repository's git configuration can make git run programs. After `/factory stop`, pushes work as they do without the plugin.

The gate guards against pushing by mistake; it isn't a security boundary. It recognizes pushes by their command, so a script, alias or tool that pushes some other way gets through, and you can always push from your own shell.

**Status bar.** A bar along the bottom, as in VS Code, shows how many sessions need you and how many are working, then the last turn's token count, on the left, and, on the right, knackpack's version, which links to its GitHub repository, and the license. knackpack writes its version into the session list it keeps, so the page shows only "knackpack" while knackpack isn't recording sessions or is older than 0.20.0. The overview's section headings carry their own counts.

**Appearance.** The **Aa** button at the top right picks a theme and a text size. The themes are VS Code's Solarized Dark (the default), Dark Modern, GitHub Dark Default, One Dark Pro and Dracula, and Solarized Light, Light Modern and GitHub Light Default. Text size steps with **−** and **+** through 80, 90, 100, 110, 125, 150, 175 and 200% of your browser's default, Chrome's own zoom levels, and scales the whole page; **Reset**, beside the heading once the size isn't 100%, sets it back. Both are saved for every session's page, since each `/factory` run starts on a new port, which the browser treats as a new site.

## How it works

Typing `/factory` starts a small Node.js server for the session. The plugin and the server talk over a Unix socket in a private folder (mode 0700) under your temporary directory, and the page talks to the server on `127.0.0.1` only, on a random port.

**What the page's key allows:** reading the session's events and the overview of every session knackpack recorded, sending a message, running any slash command the terminal could run, built-ins such as `/clear` and `/exit` included, listing the names of files in the session's folder for `@` suggestions, stopping the current turn, answering an open question or permission card, uploading images for its next message, saving the page's theme and text size, overriding a reviewer's blocking verdict on the current commit for the push gate, and disconnecting. Nothing else.

**Permission prompts** go to the page only when Claude Code is about to ask you, after your rules, hooks and auto mode's classifier have had their say, and only while the page is open. The card offers what the terminal's dialog offers: **Yes**; **Yes, and …**, which applies every rule, mode or folder change Claude Code itself suggests for this call, such as not asking again for `npm test` commands in this project, and is the only rule the page can save; the page leaves it out when Claude Code suggests a kind of change the card can't describe; and **No, and tell Claude what to do differently**, which denies the call and passes your note to Claude, or stops Claude when you leave the note empty or press Esc. The card shows the whole call; a call too long to show in full can only be denied there. While the page holds a prompt, the terminal shows a row with "Deny" and "Show the usual prompt", which brings back Claude Code's own dialog with the full call and every option. A call your settings deny stays denied, since Claude Code checks deny rules again after any allow. One prompt at a time goes to the page; any other waiting at the same time gets Claude Code's own dialog. Plan approval stays in the terminal; the page shows the plan and says it's waiting there.

**Protections:**

- The server accepts only `Host: 127.0.0.1:<port>`, which stops DNS rebinding.
- It accepts only requests from its own page, by `Origin` and `Sec-Fetch-Site`, and sends no CORS headers.
- It requires the key on every call, from a header only.
- It limits request size, connections and open streams.
- The page runs no inline script, and its content security policy allows images only from itself and from the `blob:` previews it makes of pasted images.
- Everything from the session is shown as text, never as HTML.
- No key or code goes into a command's arguments, the transcript or Claude's context.

**What's kept, and where:**

| Data | Where | For how long |
|---|---|---|
| The page's key and the one-time code | The server's memory; the key also in the tab's `sessionStorage` | Until the session ends, or the page disconnects |
| Session events: prompts, answers, tool summaries, agents | The server's memory, last 3,000 events or 5 MB | Until the server stops |
| The private folder: socket and launch file | Your temporary directory | Removed when the server stops |
| Images pasted on the page | The private folder, mode 0600 | Removed when the server stops |
| The push gate's reviews and overrides | The plugin's memory | Until the session ends or `/reload-plugins` |
| The page's theme and text size | `~/.local/state/software-factory/prefs.json` (under `$XDG_STATE_HOME` if you set it), mode 0600 in a 0700 folder | Until you delete it |

**Logs:** the server writes one JSON line to its standard error for each refused request, connection, revoked key and answer given from the page. It records the kind of event, never keys, codes, message text or tool input. The plugin passes these lines to Claude Code's debug log (`claude --debug`), at most 30 a minute.

**Requests the page sends:**

| Route | Body |
|---|---|
| `POST /api/session` | `{ "code": "<one-time code>" }`, answered with `{ "token": "<page key>" }` |
| `GET /api/events` | None. Answered with a stream of JSON lines |
| `POST /api/message` | `{ "text": "<message>", "images": ["<id>", …] }`: text of at most 20,000 characters, up to 4 images from `/api/image`, each sent once; either may be empty, not both. Text starting with `/` runs as a slash command; it's refused with 400 when images come with it, and text starting with `!` always is |
| `POST /api/files` | `{ "q": "<query>" }`, at most 200 characters, answered with `{ "files": ["<path>", …] }`: up to 15 paths relative to the session's folder whose names match the query, from a walk of that folder that skips dot folders other than `.github` and `.claude`, dependency and build folders, and symbolic links |
| `POST /api/image` | The image itself, with `Content-Type` `image/png`, `image/jpeg`, `image/gif` or `image/webp`, at most 2.5 MB, its first bytes checked against the type; answered with `{ "id": "<image>" }`. The server keeps at most 40 images not yet sent, removing the oldest such image when another arrives |
| `POST /api/stop` | `{}` |
| `POST /api/answer` | `{ "id": "<card>", "answer": <answer> }`: for a permission card `{ "choice": "yes" }`, `{ "choice": "always" }` or `{ "choice": "no", "note": "<optional, at most 2,000 characters>" }`; for a question `{ "<question>": "<answer>" }` |
| `POST /api/override` | `{ "type": "knackpack:adversarial-reviewer" \| "knackpack:slop-reviewer", "head": "<commit id>" }`, a 40- or 64-character commit id; the plugin accepts it only when that reviewer's verdict on that commit blocks and the commit is still checked out |
| `POST /api/disconnect` | `{}` |
| `POST /api/prefs` | `{ "theme": "<name>", "scale": <percent> }`, either or both; only the names in `themes.css` and the sizes in `app.css` are accepted |

## The page's code

The page is plain ES modules with no build step. Any `.js` or `.css` file in `web/` whose name is lowercase letters, digits and hyphens is served at `/<name>`; nothing else is.

| File | What it holds |
|---|---|
| `app.js` | The page itself: the event stream, state, the bar, the timeline, the composer, and every call to the helper |
| `api.js` | The page key and the helper's routes |
| `dom.js` | `el()`, which builds an element with text only, and `visible()`, which shows control and bidi characters as escapes |
| `format.js` | Formatting shared by the components: project names, relative times, verdict colors |
| `tabs.js` | The tab bar, `<sf-tabs>` |
| `prefs.js` | The **Aa** menu: it lists the themes and text sizes it finds in the stylesheets |
| `themes.css` | One block of color variables per theme |
| `path.js` | The execution path in the side panel: plain functions that set each stage's mark and line, leaving the reviewer rows in place |
| `complete.js` | The `/` and `@` suggestions above the message box: plain functions, since the list owns nothing a rebuild would lose |
| `markdown.js`, `cards.js`, `check.js`, `intent.js`, `overview.js`, `session.js` | The components below |

**Why native custom elements, without Shadow DOM or a library.** The page loads nothing from outside the helper and the plugin has no dependencies, which rules out Lit and its kind, and the CSP (`style-src 'self'`) blocks the `<style>` a shadow root would need. One page and one stylesheet gain nothing from style encapsulation, so the components render into the light DOM and use the shared classes and color variables in `app.css`. They exist for one reason: each owns state that rebuilding it would destroy, such as an answer being typed, keyboard focus, or which sections of the intent record are open. A new card no longer wipes a half-typed answer, the Run button keeps focus while the agent list updates, and open sections stay open when the record changes.

| Element | Properties | Events (bubbling) |
|---|---|---|
| `<sf-markdown>` | `text`: the source; it repaints once per frame, so streamed text can be appended | `sf-paint` after each paint |
| `<sf-ask>` | `card`: an `ask` event; `error`: a message to show, which also re-enables the card | `sf-answer` with `{ id, answer }` |
| `<sf-permission>` | `card`: a `permission` event, with `always`, the label of the "Yes, and …" option when Claude Code suggested one; `error`, as above | `sf-answer` with `{ id, answer: { choice: 'yes' \| 'always' \| 'no', note? } }` |
| `<sf-plan>` | `card`: a `plan` event | none |
| `<sf-check>` | `check`: `{ type, name, prompt }`; `status`: `{ running, ran, gate, disabled, error }`, where `gate` is the reviewer's entry in the helper's `gate` event: `{ state: 'none' \| 'running' \| 'stale' \| 'pass' \| 'block' \| 'overridden', verdict }`. It shows **Override** only for `block`, and a second click within 5 seconds confirms | `sf-run` with `{ prompt }`; `sf-override` with `{ type }` once confirmed |
| `<sf-intent>` | `record`: the helper's `intent` record; it hides itself when there's none | none |
| `<sf-overview>` | `data`: the helper's `overview` event; `live`: `{ id, cwd, busy, needs }` for this session, which is more current than knackpack's record of it. It redraws every 30 seconds for the relative times and puts keyboard focus back on the row it was on | `sf-counts` with `{ waiting, working }` after each redraw, for the status bar; each row is a link whose `data-view` names its tab, `live` or `s/<session>`, which `app.js` opens |
| `<sf-session>` | `session`: one session from the overview | none |
| `<sf-tabs>` | `state`: `{ tabs, active }`, each tab `{ id, label, title, closable, need }`; it keeps keyboard focus on the tab it was on and scrolls the active tab into view | `sf-open` and `sf-close` with `{ id }` |

`<sf-markdown>` is used twice: in each reply on the timeline, where it receives streamed text, and inside `<sf-plan>`. `<sf-intent>` is too: in the live session's side panel and in `<sf-session>`.

The page has three views, one per tab: `overview`, `live` for this session, and `s/<session>` for another session. The open one is kept in session storage, not in the address, and any link with a `data-view` attribute opens its view.

To add a component:

1. Create `web/<name>.js` with a class extending `HTMLElement`, register it with `customElements.define('sf-<name>', …)`, and import it from `app.js`.
2. Take data through properties and render when they're set; don't render in the constructor.
3. Build nodes with `el()` and set text with `textContent`, never `innerHTML`.
4. Report what the user does with a bubbling `CustomEvent` named `sf-…`, and let `app.js` call the helper. A component never calls `fetch`.
5. Add the tag to the `display: block` rule in `app.css`, and style it with the color variables from `themes.css`.

**Themes.** Each theme is one block in `themes.css`: `[data-theme="<name>"]` with a `--label`, `color-scheme: dark` or `light`, and the color variables below. The menu, the helper's check of a saved choice and the order of the list all come from that file, so adding a theme takes one block and nothing else. The colors are the theme's own VS Code values, taken from these keys of its theme file, or from VS Code's built-in default for a dark or light theme where the file leaves a key out:

| Variable | Used for | VS Code color |
|---|---|---|
| `--paper` | The page | `editor.background` |
| `--card` | Panels, cards, the menu | `sideBar.background` |
| `--field` | The message box and inputs | `input.background` |
| `--line` | Borders and separators | `sideBar.border`, else `input.border`, else `editorGroup.border` |
| `--hover` | A session row under the pointer | `list.hoverBackground` |
| `--ink` | Text | `input.foreground`, else `foreground` |
| `--soft` | Secondary text | `descriptionForeground` |
| `--placeholder` | Placeholder text | `input.placeholderForeground`, else `--soft` |
| `--accent` | Links, focus rings, the live tag | `textLink.foreground` |
| `--select` | Selected text | `selection.background`, else `editor.selectionBackground` |
| `--button`, `--button-ink` | Primary buttons | `button.background`, `button.foreground` |
| `--good`, `--warn`, `--bad` | Status dots and card borders | `terminal.ansiGreen`, `terminal.ansiYellow`, `terminal.ansiRed` |
| `--good-ink`, `--warn-ink`, `--bad-ink` | Status text | the same green and yellow, and `errorForeground` |
| `--tabs-bg`, `--tab-border` | The tab bar and the lines between tabs | `editorGroupHeader.tabsBackground`, `tab.border` |
| `--tab-active`, `--tab-ink` | The open tab | `tab.activeBackground`, `tab.activeForeground` |
| `--tab-inactive`, `--tab-ink-inactive` | The other tabs | `tab.inactiveBackground`, `tab.inactiveForeground` |
| `--status-bg`, `--status-ink`, `--status-border` | The status bar along the bottom; the border is left out where the theme draws none | `statusBar.background`, `statusBar.foreground`, `statusBar.border` |
| `--tab-hover`, `--tab-top` | A tab under the pointer, and the line above the open tab; left out where the theme draws none | `tab.hoverBackground`, `tab.activeBorderTop` |

Text colors that fall below WCAG AA (4.5:1) on `--paper` or `--card`, or on `--field` for `--ink` and `--placeholder`, are moved toward white on a dark theme or black on a light one, just far enough to pass:

| Theme | Changed |
|---|---|
| Solarized Light | text `#586e75` to `#4d6066`, secondary `#92a0a0` to `#606a6a`, green `#859900` to `#606e00`, yellow `#b58900` to `#846400`, button text `#ffffff` to `#333333`, placeholder `#586e75aa` to `#565f5d` |
| Solarized Dark | placeholder `#93a1a1aa` to `#899ea2` |
| GitHub Dark Default | placeholder `#6e7681` to `#757d87` |
| Dracula | placeholder `#6272a4` to `#8390b7` |
| Light Modern | green `#00bc00` to `#008500`, yellow `#949800` to `#737700`, error `#f85149` to `#cb423c` |

Solarized Light's status bar text `#586E75` is lifted to `#566c73` on `#EEE8D5`. Inactive tab text is checked against its own tab's background, and four themes fall short: Solarized Dark `#93A1A1` to `#99a7a7`, Solarized Light `#586E75` to `#445a61`, One Dark Pro `#dcdcdc80`, VS Code's default of half the active tab's text, to `#9ea0a3`, and Dracula `#6272A4` to `#7888ba`. Tab colors a theme doesn't set are VS Code's defaults from `src/vs/workbench/common/theme.ts`; they come from microsoft/vscode at commit `67710841ad06`, GitHub Theme v6.3.5, One Dark Pro at commit `75c80ab18d90` and Dracula at commit `b50e62e32090`, read on 2026-11-01.

Apart from its placeholder, Solarized Dark keeps the colors it had in 0.1.0, all from VS Code's Solarized Dark: borders are `editor.lineHighlightBackground` (`#073642`), secondary text is `editor.foreground` (`#839496`), the accent is `terminal.ansiCyan` (`#2aa198`), and error text is the red lifted to `#ef6b68`. The values come from microsoft/vscode at commit `67710841ad06` and from the Marketplace releases of GitHub Theme 6.3.5, One Dark Pro 3.20.6 and Dracula Theme 2.25.1, read on 2026-11-01.

To add a theme:

1. Find its color theme file: in the Marketplace package (`extension/package.json` lists each theme's path) or the theme's repository.
2. Add a `[data-theme="<name>"]` block to `themes.css`, in the order the menu should list it, with `--label`, `color-scheme` and every variable above, taken from the keys in the table.
3. Check each text color's contrast and lift any that fail AA as above, then add the change to the table.
4. Open the page, pick the theme from **Aa**, and look at a card, the timeline and the overview.

**Text size.** `app.css` sizes everything in `rem`, and `:root[data-scale="<percent>"]` rules set the root font size. The menu lists those rules, so adding a size takes one rule.

## Limitations

- On a machine shared with other people's accounts, the one-time code travels in the page address after `#`, which the browser never sends to a server. The page removes it before using it, it's never in a command's arguments, and it works once within a minute.
- Other sessions are read-only on the overview: each session's page key controls only the session that started it. Their details are as current as knackpack's record, which updates with each hook event.
- Since 0.2.0 a card comes from Claude Code's PermissionRequest step, which runs only when Claude Code is about to ask you, so calls that auto mode's classifier or plan mode decide shouldn't reach the page. This hasn't been checked in a live session yet. Whether Claude Code shows its own dialog while the page holds a prompt hasn't been checked either; the terminal row above covers the case where it doesn't.
- In 0.2.0 Claude Code dropped every pasted image, showing Claude "(media removed — rejected by API)", because the tool returned MCP's image block rather than the Messages API's. 0.3.0 returns the API's block; a live paste with it hasn't been checked yet.
- A tool call's outcome line is the plugin's own wording, since Claude Code doesn't pass its own to plugins. Grep, Glob and other tools whose results this Claude Code version doesn't describe to plugins get no outcome line, and lines such as "Allowed by auto mode" aren't shown.
- 0.4.0's suggestions and commands from the page were checked on a test helper only. In a live session it's still unchecked when Claude Code first offers its agents to a plugin, whether `@agent-<name>` and `@<file>` in a message the page sends work as they do when typed in the terminal, and what each built-in command shows when run from the page.
- 0.5.0's push gate was checked in live headless sessions on Haiku for its refusals: no plan and no reviews, a commit and a push in one call, `git status` left alone, a normal push once the page was closed, a plan found in the session's folder, and a branch read from `packed-refs`. A push let through by two passing reviews, a review gone stale after a commit, and an override haven't run end to end in a live session yet; the page's side of them was checked on a test helper.
- The gate's reviews and overrides live in the plugin's memory, so `/reload-plugins` forgets them: run the reviewers again after a reload.
- Everything here was tested by hand in real sessions; the project has no automated tests.
