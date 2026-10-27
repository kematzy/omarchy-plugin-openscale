# OpenScale bar widget — technical notes

Everything needed to work on this plugin: how it is wired, where the numbers come from, how often
they are read, and what to know about the Omarchy plugin machinery underneath.

For what the plugin does and how to install it, see the [README](../README.md).

## Contents

1. [Architecture](#architecture)
2. [Data sources: the `osc` CLI](#data-sources-the-osc-cli)
3. [Refresh and caching](#refresh-and-caching)
4. [Settings](#settings)
5. [Number formatting](#number-formatting)
6. [Omarchy plugin mechanics](#omarchy-plugin-mechanics)
7. [Checks](#checks)
8. [Development recipes](#development-recipes)
9. [Known limitations](#known-limitations)
10. [References](#references)

## Architecture

```text
omarchy-shell
 └─ Bar.qml (first-party bar)
     └─ BarWidget.qml ................. bar button, hosts everything below
         ├─ Service.qml ............... balance poller (osc balance)
         ├─ Usage.qml ................. usage loader (osc usage × 3)
         └─ Loader → Panel.qml ........ the popup (qs.Ui Panel + KeyboardPanel)
             ├─ panel/PanelHeader.qml . brand lockup (links to openscale.so) + balance
             ├─ panel/Tab.qml ......... one tab button
             ├─ panel/SpendTab.qml .... four money windows + threshold editor
             ├─ panel/TokensTab.qml ... three windows of tokens + model shares
             ├─ panel/ModelsTab.qml ... catalogue + disk cache
             └─ panel/PanelFooter.qml . three shortcut links
```

| File                        | Role                                                                                                 |
| --------------------------- | ---------------------------------------------------------------------------------------------------- |
| `manifest.json`             | Plugin contract: id, kind, entry point, settings schema                                              |
| `BarWidget.qml`             | Entry point. Bar button; owns `Service`, `Usage`, the panel loader; persists `lowBalance`            |
| `Service.qml`               | Polls `osc balance --json`, holds balance and rolling 24 h spend                                     |
| `Usage.qml`                 | Loads the three `osc usage` windows in order for the usage tabs                                      |
| `models.sh`                 | Reads/writes the on-disk catalogue cache (QML cannot write files)                                    |
| `Format.js`                 | Shared, pure number formatting                                                                       |
| `Panel.qml`                 | Composition: header → tab strip → active tab → footer; tab routing, refresh triggers, per-tab height |
| `panel/*.qml`               | The pieces named in the tree above                                                                   |
| `assets/openscale.svg`      | Bar button mark                                                                                      |
| `assets/openscale-logo.svg` | Header lockup (mark + wordmark in one asset)                                                         |

### How the pieces are connected

- The bar instantiates `BarWidget.qml` once per bar, injecting **`bar`**, **`moduleName`** and
  **`settings`**. Those three are all a widget gets (see [why that matters](#persisting-a-setting)).
- `BarWidget.qml` loads `Panel.qml` itself through a `Loader` and forwards the panel lifecycle the
  bar and `omarchy-shell shell summon` expect: `opened`, `open()`, `close()`, `togglePanel()`,
  `popoutSwitchClosing`, `closeForPopoutSwitch()`.
- Because the panel is a nested item rather than a bar slot, it receives `bar`, `settings`,
  `anchorItem` (the bar button), `hostWidget` and `usage` through `injectPanel()`.
- The panel reads the balance **live** from `hostWidget` (`creditText`, `lowCredit`,
  `balanceRefreshing`) instead of copying it at injection time, so a poll updates bar and panel together.
- Tab index drives everything below the strip: `StackLayout.currentIndex`, which tab gets refreshed,
  and how tall the card is.

## Data sources: the `osc` CLI

The [OpenScale public API](https://openscale.so/openapi.json) exposes models,
chat, prompts and conversations — but **no credit or usage endpoint**. The
signed-in `osc` CLI is the only read-only source for account figures, so the
plugin shells out to it and never speaks HTTP itself.

### Commands used

| Command                    | Used for                                          | Output shape                                            |
| -------------------------- | ------------------------------------------------- | ------------------------------------------------------- |
| `osc balance --json`       | bar figure, Spend tab "Last 24 hours"             | `{balanceUusd, spent24hUusd, runwayHours, planCovered}` |
| `osc usage --today --json` | Spend "Today only", Tokens "Today"                | see below                                               |
| `osc usage --7d --json`    | Spend "Last 7 days", Tokens "Last 7 days"         | see below                                               |
| `osc usage --30d --json`   | Spend "Last 30 days", Tokens "Last 30 days"       | see below                                               |
| `osc models --json`        | Models tab                                        | array of model objects                                  |
| `osc claim`                | _not called_; its printed URL is the Credits link | `https://app.openscale.so/app?credits=open`             |

`osc usage --json` returns:

```json
{
  "period": "today",
  "from": "2026-10-26",
  "requests": 49,
  "costUusd": 226733,
  "tokens": { "input": 2727297, "cached": 16630242, "output": 55009 },
  "models": [{ "model": "deepseek/deepseek-v4.1-flash", "tokens": 19412548 }]
}
```

`osc models --json` returns an array of:

```json
{
  "id": "deepseek/deepseek-v4.1-flash",
  "name": "DeepSeek: DeepSeek V4.1 Flash",
  "context": 1048568,
  "fastMode": true,
  "usdPerMillion": { "input": 0.06, "output": 0.24, "cached": 0.003 }
}
```

### Things the data does _not_ give you

- **No per-model cost.** `models[].tokens` is tokens only, so the Tokens tab's bars are token share.
  Pricing them locally would mean reimplementing OpenScale's billing.
- **No `name` in usage.** `models[].model` is the id (`deepseek/…`), which is what the Tokens tab
  displays; the Models tab uses `name` with the vendor prefix stripped.
- **`--today` is a calendar day**, while `balance.spent24hUusd` is a rolling 24 h. They usually
  differ slightly; the Spend tab labels them so.
- **`--7d` and `--30d` can be identical** while an account is younger than a week.
  That is correct, not a bug.

### Units and error semantics

- Money crosses the boundary as **micro-USD integers** (`uusd`): divide by 1,000,000.
  `Format.money()` then renders two decimals.
- The CLI's documented exit codes:
  - `0` ok
  - `1` error
  - `2` usage
  - `3` sign-in needed
  - `4` out of credit
  - `5` limit reached.
- Departures from `0` become the `error` string shown in the tooltip or the tab footer.
  `osc` reports failures as JSON (`{"error": {"code", "exit", "message"}}`), so the raw text
  is never shown: `Format.errorText()` — and `readable_error()` in `models.sh` — extracts
  `.error.message`, strips ANSI, falls back to the first usable line and shortens anything
  long. `3` always reads "Not signed in — run `osc login`".
- Every `osc` invocation costs a process spawn plus one HTTPS round trip, ~300 ms measured.
  That is why reads are batched per tab and floored.

## Refresh and caching

Nothing is polled that nobody is looking at, and nothing is fetched twice.

| Data          | Trigger                          | Cadence                                                             | Stored                 |
| ------------- | -------------------------------- | ------------------------------------------------------------------- | ---------------------- |
| Balance       | background timer                 | `refreshIntervalSec`, default 300 s                                 | memory (`Service.qml`) |
| Balance       | panel opens                      | only if the last good read is older than `openRefreshGapSec` (60 s) | memory                 |
| Usage windows | Spend/Tokens tab becomes current | 60 s floor, hardcoded                                               | memory (`Usage.qml`)   |
| Models        | Models tab becomes current       | if cache is missing or at least 24 hours old                        | disk + memory          |

Details worth knowing:

- **A manual read re-arms the balance timer**, so the next background poll is a full interval later
  rather than seconds after the click.
- **A failed read does not advance the freshness stamp**, so the next open retries immediately
  instead of waiting out the gap.
- **Usage loads today → 7 d → 30 d sequentially**, each window rendering as it lands, so the most
  actionable figure appears first. A failed window keeps its previous figures, the rest still load,
  and the reason replaces the timestamp.
- **Models are cached on disk** because QML cannot write files: `models.sh --read` prints the
  cached envelope, `--refresh` fetches, rewrites the cache and prints the fresh envelope.
  Both always exit 0 with JSON (`{fetchedAt, models}`, `{"error": …}` or `{}`), so a failure is a
  state the tab renders.
  - Path: `${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/openscale/models.json`
  - Shape: `{"fetchedAt": <epoch seconds>, "models": [ … ]}` — an envelope because
    the CLI returns a bare array, which cannot carry a timestamp.
  - Written atomically (`mktemp` + `mv`), mode 600.
  - A cached catalogue is reused for 24 hours; visiting the Models tab after it expires triggers
    a refresh. A missing cache is fetched on the first visit.
  - The cache doubles as the baseline for the **NEW** badge: ids in the live list that the cached
    envelope did not have are marked for the session. No cache means no baseline, and then nothing
    is labelled.
- **The card sizes itself to the active tab.** Spend asks for the height its whole column needs
  (header + strip + tab + footer); the data tabs keep `Style.space(600)` and scroll inside it,
  because their length depends on the list and on how many models a window carries.

### Why no disk cache for usage

Usage moves constantly, so a cache would mostly serve stale figures, and the three windows are
three CLI calls — cheap enough to refetch when a tab is opened, floored so that flicking between
tabs does not re-issue them.

## Settings

Declared in `manifest.json` under `barWidget.defaults` and `barWidget.schema`, so Omarchy renders
them in its own **Settings → Widgets** UI. There is deliberately no Settings tab.

| Key                  | Type    | Default | Meaning                                                                             |
| -------------------- | ------- | ------- | ----------------------------------------------------------------------------------- |
| `lowBalance`         | number  | `3`     | The figure turns urgent at or below this many dollars (bar, header, Credit display) |
| `refreshIntervalSec` | integer | `300`   | Background balance cadence, 30–3600 s                                               |
| `openRefreshGapSec`  | integer | `60`    | Minimum age before opening the panel triggers a balance read, 0–3600 s              |

```bash
omarchy bar set io.github.kematzy.openscale lowBalance 10 --json
omarchy bar set io.github.kematzy.openscale refreshIntervalSec 120 --json
```

Numbers need `--json`, or they land in `shell.json` as strings.

## Number formatting

`Format.js` is imported by all three tabs, so the same figure always looks the same. It is a
`.pragma library` of pure functions:

| Function  | Rule                                                                                                 | Examples                                                     |
| --------- | ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| `money`   | dollars, always 2 decimals, `—` when unknown                                                         | `$0.23`, `$5.34`                                             |
| `count`   | exact with commas below 10,000; K below a million; M above; up to 2 decimals, trailing zeros dropped | `1,443`, `9,999`, `10K`, `55.01K`, `19.41M`, `363.76M`, `2M` |
| `percent` | whole percent, `<1%` when it would round to zero                                                     | `100%`, `62%`, `<1%`                                         |
| `context` | compact context window                                                                               | `1M`, `131K`                                                 |
| `stamp`   | local timestamp from epoch seconds                                                                   | `2026-10-26 at 15:57:53`                                     |

Percentages in the Tokens bars are share of `input + cached + output` for that window, which equals
the sum of `models[].tokens`.

## Omarchy plugin mechanics

Condensed from the shell's own docs — the long version is in `/usr/share/omarchy/shell/README.md`
and `plugins/README.md`.

- A plugin is a **git repo with a `manifest.json`** at its root, cloned to
  `~/.config/omarchy/plugins/<manifest-id>/`. **The folder name must equal the
  id** — enable state, bar layout and the reload watcher are keyed by it.
- Kinds used here: `bar-widget`. The popup is part of the widget, not a separate `panel` plugin;
  the manifest has one entry point, `BarWidget.qml`.
- Bar widgets are instantiated **per bar surface** and receive only `bar`, `moduleName` and
  `settings`. Panels, overlays and services loaded by the shell itself can also receive `shell`,
  `manifest`, `pluginRegistry` and `barWidgetRegistry` facades — bar widgets cannot.
- The bar's layout and per-widget settings live inline in `~/.config/omarchy/shell.json`;
  there is no separate settings file and no merge layer.

### Persisting a setting

Because a widget gets no shell facade, there is no in-process API for writing a setting, and
writing `shell.json` directly is not a plugin's business. The supported path is the documented CLI,
which routes to `shell.setBarWidget()`:

```bash
omarchy bar set io.github.kematzy.openscale lowBalance 10 --json
```

`BarWidget.saveLowBalance()` runs exactly that with a fixed argv (no shell, no interpolation),
and the new value comes back through the injected `settings` property. Verified: it rewrites only
that widget's entry and leaves its position alone.

### Hot reload has a caveat

The shell watches `~/.config/omarchy/plugins/` and reloads plugin code when a file is saved.
For **new files** that works; for **edits to already-loaded QML it may not**, because the reload
path guards `Qt.clearComponentCache()` behind a `typeof` check and that function does not exist
in this Quickshell build. The engine keeps its compiled component for the same URL, so the plugin
re-registers the old code and nothing appears to change.

In practice: **`omarchy restart shell` after editing QML.** `rescanPlugins` goes through the same
code path and will not help. Reverting a `keepLoaded` service may survive, but this plugin has none.

### Theming

Everything reads `qs.Commons`:

- `Style.space()` for metrics, `Style.font.*` for type (`caption` 10, `bodySmall` 11, `body` 12,
  `subtitle` 13, `title` 14, `heading` 16, `display` 24 at the default base size, scaled by the theme)
- `Commons.Color.foreground` / `muted` / `accent` / `urgent` / `popups.background`
- `Util.alpha()`, `Util.execArgv()` for helpers

No hardcoded colors, so the panel follows the active Omarchy theme. Two places deliberately blend
rather than use alpha: the header's logo tint (a `MultiEffect` colorization, which paints an opaque
color) and the header's caption color.

## Checks

```bash
omarchy plugin validate .
```

Lints the manifest and QML against the shell's own components. Then, because the `qs` import prefix
only resolves inside the shell's config dir, give `qmllint` an import path shaped like it:

```bash
mkdir -p /tmp/qmlimports && ln -sfn /usr/share/omarchy/shell /tmp/qmlimports/qs
/usr/lib/qt6/bin/qmllint -I /tmp/qmlimports *.qml panel/*.qml
```

Expect `Style.font.*`, `bar.*` and `loader.item` "missing-property" warnings: the singletons are
declared as `QtObject`, so `qmllint` cannot see their members. The built-in Omarchy plugins produce
the same ones. Anything else is worth reading.

## Development recipes

### See a change

`omarchy restart shell` (see [the hot reload caveat](#hot-reload-has-a-caveat)).

### Exercise a component without restarting the shell

Quickshell can run a throwaway config, which is how the numbers in this document were checked
without touching the live bar. Create a scratch dir with symlinks so `qs.Commons` / `qs.Ui` resolve,
plus one for the panel components:

```bash
mkdir -p /tmp/qstest && cd /tmp/qstest
ln -sfn /usr/share/omarchy/shell/Commons Commons
ln -sfn /usr/share/omarchy/shell/Ui Ui
ln -sfn ~/.config/omarchy/plugins/io.github.kematzy.openscale/panel panel
```

Then a `probe.qml` in that directory can `import "panel"`, wrap a component in a `Loader`, set
properties from `onLoaded`, and print what it measures from a `Timer`.
Run it with `qs -p /tmp/qstest/probe.qml`. Useful for measuring layouts, timing a poll and driving
the state machines; it never touches the real bar.

### Reset or inspect the catalogue cache

```bash
bash models.sh --read | jq '{fetchedAt, n: (.models|length)}'
bash models.sh --refresh | jq '.models | length'
rm -f ~/.cache/omarchy/openscale/models.json   # forces a real fetch
```

To test the **NEW** badge, hand-write a cache that is missing some ids and then open the Models tab:

```bash
jq -c '{fetchedAt: 1793000000, models: [.models[] | select(.id | test(":fast") | not)]}' \
  ~/.cache/omarchy/openscale/models.json > /tmp/small.json \
  && mv /tmp/small.json ~/.cache/omarchy/openscale/models.json
```

### Check the data the plugin sees

```bash
osc balance --json
osc usage --today --json
osc models --json
```

If a tab is empty or shows `—`, these are the first things to run: they answer
"is it the plugin or the CLI?" immediately.

## Known limitations

- **Per-model spend is not shown.** The CLI reports tokens per model only.
- **`--30d` equals `--7d`** on a young account. Expected, not a bug.
- **The Models list scrolls** once the catalogue outgrows the panel (eight entries
  at the current height); the scrollbar appears as needed.
- **The Tokens tab scrolls** as soon as a window carries more than one model.
- **Tab labels share the strip width equally**, so longer names would shrink all
  three.
- **No Settings tab.** Three settings is not worth a tab when Omarchy's own widget
  settings render the manifest schema.
- **No manual refresh gesture.** Data refreshes on open, on tab activation and on
  the balance timer; there is no `r` key or refresh button.
- `osc` invocations are processes: each read costs ~300 ms, which is why usage is
  loaded per tab and floored rather than polled.

## References

- Omarchy: <https://omarchy.org> · plugin docs: <https://plugins.omarchy.org/develop.html>
- Shell internals: `/usr/share/omarchy/shell/README.md`,
  `/usr/share/omarchy/shell/plugins/README.md`
- OpenScale API reference (OpenAPI 3.1): <https://openscale.so/openapi.json>
- OpenScale site: <https://openscale.so> · dashboard: <https://app.openscale.so>
- CLI help: `osc --help` (every command also takes `--json`)
- Reference plugin: <https://github.com/SpoilHeap/Omarchy.OpenRouter>
