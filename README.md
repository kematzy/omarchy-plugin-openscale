# OpenScale for Omarchy

An [Omarchy](https://omarchy.org/) shell plugin: the OpenScale credit balance in
the status bar, with a panel for usage, models and settings.

- **Plugin id:** `io.github.kematzy.openscale`
- **Kind:** `bar-widget` (one plugin; the popup is part of the widget, not a
  separate `panel` plugin)
- **Status:** working credit balance, read from the `osc` CLI. Usage, models and
  settings tabs are still placeholders

## Layout

| File | Purpose |
|------|---------|
| `manifest.json` | Plugin contract: id, kind, entry point, settings schema. Validated by `omarchy plugin validate` |
| `BarWidget.qml` | Manifest entry point. The bar button, the `Service` that polls the balance, plus the `Loader` that owns `Panel.qml` and forwards `open()/close()/toggle()` |
| `Service.qml` | Polls `osc balance --json` on a timer and when the panel opens, converts `balanceUusd` to dollars, formats the figure |
| `Panel.qml` | Composition only: header → tab bar → main area → footer, inside `qs.Ui`'s `Panel` + `KeyboardPanel` + `PanelKeyCatcher` |
| `panel/PanelHeader.qml` | Brand lockup on the left, credit balance over its caption on the right (every tab) |
| `panel/Tab.qml` | One tab button: theme-token pill, uppercase label |
| `panel/PanelFooter.qml` | Three shortcut buttons that open pages on openscale.so (every tab) |
| `panel/UsageTab.qml`, `panel/ModelsTab.qml`, `panel/SettingsTab.qml` | Tab bodies — placeholders for now |
| `assets/openscale.svg` | Bar button mark |
| `assets/openscale-logo.svg` | Header lockup: mark + wordmark in one asset |

## How the shell loads it

`BarWidget.qml` is the entry point. It loads `Panel.qml` itself and exposes the
lifecycle the bar and `omarchy-shell shell summon` talk to:

```
opened, open(), close(), toggle(), popoutSwitchClosing, closeForPopoutSwitch()
```

`Panel.qml` receives `bar`, `settings`, `anchorItem` (the bar button) and
`hostWidget` via `injectPanel()` in `BarWidget.qml` — that is what anchors the
popup under the button and lets the bar know which panel is open. The balance
itself is not copied in: the panel reads `hostWidget.creditText` and
`hostWidget.lowCredit` live, so a poll updates header and bar together.

## Data

The balance comes from the `osc` CLI, which must be installed and signed in
(`openscale login`):

```bash
osc balance --json
# {"balanceUusd": 11195181, "spent24hUusd": 231648, "runwayHours": 1159.9, "planCovered": false}
```

`balanceUusd` is a micro-USD integer, so it is divided by 1,000,000 and shown as
`$11.20`. The public API has no credit endpoint; the CLI is the only read-only
source for it. The plugin runs exactly one fixed command — nothing is
interpolated into it, and nothing it does writes to the account.

Polling is per widget and has two knobs:

| Setting | Default | What it does |
|---|---|---|
| `refreshIntervalSec` | `300` | Background poll while the panel is closed. 30 s minimum, for development |
| `openRefreshGapSec` | `60` | Opening the panel refreshes only if the last good fetch is older than this. `0` refreshes on every open |

```bash
omarchy bar set io.github.kematzy.openscale refreshIntervalSec 120 --json
```

A small spinner ahead of the figure turns while a fetch is in flight. A failed
poll keeps the last good figure on screen and puts the reason in the bar tooltip;
an unknown balance is shown as `—`, never `$0.00`. At or below `$3.00` the figure
turns urgent in both the bar and the header.

The usage windows, the models cache and the missing-CLI error screen are not
built yet.

## Development

This checkout lives at `~/.config/omarchy/plugins/io.github.kematzy.openscale`,
which is where the shell looks for plugins. **The folder name must equal the
manifest `id`** — enable state, bar layout and the reload watcher are all keyed
by it.

The shell watches that folder (`inotifywait`) and reloads plugin code when a file
is saved. If a change does not appear:

```bash
omarchy-shell shell rescanPlugins
```

Note this watcher does **not** follow symlinks, so a symlinked plugin folder gets
no automatic reload — keep the real checkout here.

### Checks

```bash
omarchy plugin validate .
```

Static QML check against the shell's own components (`qs.Ui`, `qs.Commons`). The
`qs` prefix only resolves inside the shell's config dir, so qmllint needs an
import path shaped like it:

```bash
mkdir -p /tmp/qmlimports && ln -sfn /usr/share/omarchy/shell /tmp/qmlimports/qs
/usr/lib/qt6/bin/qmllint -I /tmp/qmlimports BarWidget.qml Panel.qml panel/*.qml
```

Expect `Style.font.*` / `bar.*` "missing-property" warnings: those singletons are
declared as `QtObject`, so qmllint cannot see their members. The built-in Omarchy
plugins produce the same ones.

### Trying it

Click the bar widget, or:

```bash
omarchy-shell shell summon io.github.kematzy.openscale   # open
omarchy-shell shell hide io.github.kematzy.openscale     # close
```

Inside the panel: `Esc` closes, `←`/`→` (or `h`/`l`) change tabs, `1`/`2`/`3`
jump to a tab, `Tab` switches to the neighbouring bar panel.

## Theming

Everything reads `qs.Commons`: `Style.space()` for metrics, `Style.font.*` for
type, `Color.foreground` / `Color.muted` / `Color.accent` for colour, and the
`bar` object for font family and foreground. No hardcoded colours, so the panel
follows the active Omarchy theme.

## Known gaps

- **Usage, models and settings tabs** are placeholders. `osc usage` and
  `osc models` supply the data for the first two; the refresh interval is
  already a manifest setting, the low-balance threshold is not yet.
- **Console link** points at `https://openscale.so/login`; there is no
  `/console` page. Credits → `/credits`, Docs → `/docs` are confirmed live.
- Tabs currently stretch to equal width (segmented-control look).
- `README` and `LICENSE` exist, which the marketplace requires; the repository
  must be **public** before it can be submitted.
