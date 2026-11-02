# software-factory

Start a Claude Code session in the terminal, then carry on from a page in your browser. The page opens on an overview of every Claude Code session on this machine: how many need you, which are working, and what each is doing. Click one to see its details. The session where you ran `/factory` opens live, and the page and the terminal stay in step both ways:

- what you type in the terminal, Claude's answer as it streams, each tool call and each agent show on the page;
- a message you type on the page runs in the same session as your own words, and the terminal shows it;
- **Stop** ends the current turn;
- Claude's questions and permission prompts appear as cards you can answer on the page or in the terminal, and the first answer wins;
- a checklist shows knackpack's adversarial reviewer, marked required, with its verdict once it has run, and **Run** asks Claude to start it;
- the side panel shows the session's knackpack intent record: open questions, agreed requirements, assumptions and what's built.

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

Messages that start with `/` or `!` can't be sent from the page: slash commands and shell lines run only from the terminal.

## How it works

Typing `/factory` starts a small Node.js server for the session. The plugin and the server talk over a Unix socket in a private folder (mode 0700) under your temporary directory, and the page talks to the server on `127.0.0.1` only, on a random port.

**What the page's key allows:** reading the session's events and the overview of every session knackpack recorded, sending a message, stopping the current turn, answering an open question or permission card, and disconnecting. Nothing else.

**Permission prompts** are answered from the page only when Claude Code would ask you anyway and the page is open. The page offers "allow once" and "deny", and shows the whole call; a call too long to show in full can only be denied there. While the page holds a prompt, the terminal shows a row with "Deny" and "Show the usual prompt", which brings back Claude Code's own dialog with the full call, so nothing is allowed from the terminal without seeing it. Nothing is saved as a rule. A call your settings deny stays denied, and so does one your organization limits, or one another plugin's hook or a settings hook wants you to decide. One prompt at a time goes to the page; any other waiting at the same time gets Claude Code's own dialog. Plan approval stays in the terminal; the page shows the plan and says it's waiting there.

**Protections:**

- The server accepts only `Host: 127.0.0.1:<port>`, which stops DNS rebinding.
- It accepts only requests from its own page, by `Origin` and `Sec-Fetch-Site`, and sends no CORS headers.
- It requires the key on every call, from a header only.
- It limits request size, connections and open streams.
- The page runs no inline script.
- Everything from the session is shown as text, never as HTML.
- No key or code goes into a command's arguments, the transcript or Claude's context.

**What's kept, and where:**

| Data | Where | For how long |
|---|---|---|
| The page's key and the one-time code | The server's memory; the key also in the tab's `sessionStorage` | Until the session ends, or the page disconnects |
| Session events: prompts, answers, tool summaries, agents | The server's memory, last 3,000 events or 5 MB | Until the server stops |
| The private folder: socket and launch file | Your temporary directory | Removed when the server stops |

**Logs:** the server writes one JSON line to its standard error for each refused request, connection, revoked key and answer given from the page. It records the kind of event, never keys, codes, message text or tool input. The plugin passes these lines to Claude Code's debug log (`claude --debug`), at most 30 a minute.

**Requests the page sends:**

| Route | Body |
|---|---|
| `POST /api/session` | `{ "code": "<one-time code>" }`, answered with `{ "token": "<page key>" }` |
| `GET /api/events` | None. Answered with a stream of JSON lines |
| `POST /api/message` | `{ "text": "<message>" }`, at most 20,000 characters |
| `POST /api/stop` | `{}` |
| `POST /api/answer` | `{ "id": "<card>", "answer": "allow" \| "deny" \| { "<question>": "<answer>" } }` |
| `POST /api/disconnect` | `{}` |

## The page's code

The page is plain ES modules with no build step. Any `.js` or `.css` file in `web/` whose name is lowercase letters, digits and hyphens is served at `/<name>`; nothing else is.

| File | What it holds |
|---|---|
| `app.js` | The page itself: the event stream, state, the bar, the timeline, the composer, and every call to the helper |
| `api.js` | The page key and the helper's routes |
| `dom.js` | `el()`, which builds an element with text only, and `visible()`, which shows control and bidi characters as escapes |
| `format.js` | Formatting shared by the components: project names, relative times, verdict colors |
| `markdown.js`, `cards.js`, `check.js`, `intent.js`, `overview.js`, `session.js` | The components below |

**Why native custom elements, without Shadow DOM or a library.** The page loads nothing from outside the helper and the plugin has no dependencies, which rules out Lit and its kind, and the CSP (`style-src 'self'`) blocks the `<style>` a shadow root would need. One page and one stylesheet gain nothing from style encapsulation, so the components render into the light DOM and use the shared classes and color variables in `app.css`. They exist for one reason: each owns state that rebuilding it would destroy, such as an answer being typed, keyboard focus, or which sections of the intent record are open. A new card no longer wipes a half-typed answer, the Run button keeps focus while the agent list updates, and open sections stay open when the record changes.

| Element | Properties | Events (bubbling) |
|---|---|---|
| `<sf-markdown>` | `text`: the source; it repaints once per frame, so streamed text can be appended | `sf-paint` after each paint |
| `<sf-ask>` | `card`: an `ask` event; `error`: a message to show, which also re-enables the card | `sf-answer` with `{ id, answer }` |
| `<sf-permission>` | `card`: a `permission` event; `error`, as above | `sf-answer` with `{ id, answer: 'allow' \| 'deny' }` |
| `<sf-plan>` | `card`: a `plan` event | none |
| `<sf-check>` | `check`: `{ name, required, prompt }`; `status`: `{ running, ran, finished, verdict, disabled }` | `sf-run` with `{ prompt }` |
| `<sf-intent>` | `record`: the helper's `intent` record; it hides itself when there's none | none |
| `<sf-overview>` | `data`: the helper's `overview` event; `live`: `{ id, cwd, busy, needs }` for this session, which is more current than knackpack's record of it. It redraws every 30 seconds for the relative times and puts keyboard focus back on the row it was on | none; rows are links to `#live` and `#s/<session>` |
| `<sf-session>` | `session`: one session from the overview | none |

`<sf-markdown>` is used twice: in each reply on the timeline, where it receives streamed text, and inside `<sf-plan>`. `<sf-intent>` is too: in the live session's side panel and in `<sf-session>`.

The page has three views, chosen by the address: `#` (or nothing) for the overview, `#live` for this session, and `#s/<session>` for another session.

To add a component:

1. Create `web/<name>.js` with a class extending `HTMLElement`, register it with `customElements.define('sf-<name>', …)`, and import it from `app.js`.
2. Take data through properties and render when they're set; don't render in the constructor.
3. Build nodes with `el()` and set text with `textContent`, never `innerHTML`.
4. Report what the user does with a bubbling `CustomEvent` named `sf-…`, and let `app.js` call the helper. A component never calls `fetch`.
5. Add the tag to the `display: block` rule in `app.css`, and style it with the variables in `:root`.

**Theme.** The colors are VS Code's built-in Solarized Dark: the background `#002b36`, panels `#00212b`, inputs `#003847`, the cyan accent `#2aa198`, primary buttons in VS Code's translucent cyan (`#2aa19899`), and Solarized's yellow, green and red. Two text colors differ, so that small text keeps WCAG AA contrast: secondary text uses base0 (`#839496`, 4.75:1) instead of Solarized's comment gray base01 (2.8:1), and error text uses a lighter red (`#ef6b68`, 5:1) instead of `#dc322f` (3.3:1), which stays on the disconnected dot.

## Limitations

- On a machine shared with other people's accounts, the one-time code travels in the page address after `#`, which the browser never sends to a server. The page removes it before using it, it's never in a command's arguments, and it works once within a minute.
- Claude Code doesn't tell plugins when a session is in plan mode, so in plan mode a permission card can appear for a call that plan mode would refuse anyway.
- Other sessions are read-only on the overview: each session's page key controls only the session that started it. Their details are as current as knackpack's record, which updates with each hook event.
- Plugins can't see the permission mode. In auto mode, a call Claude Code would hand to its classifier may come to the page as a card while the page is open, and waits for you there.
- Run on the checklist asks Claude to start the reviewer. Nothing is blocked while a required reviewer hasn't run.
- Everything here was tested by hand in real sessions; the project has no automated tests.
