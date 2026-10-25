# OpenScale for Omarchy

An [Omarchy](https://omarchy.org/) shell plugin: the OpenScale credit balance in
the status bar, with a panel for usage, models and settings.

- **Plugin id:** `io.github.kematzy.openscale`
- **Kind:** `bar-widget` (one plugin; the popup is part of the widget, not a
  separate `panel` plugin)
- **Status:** scaffold — layout and wiring exist, the real data does not yet

## Layout

| File | Purpose |
|------|---------|
| `manifest.json` | Plugin contract: id, kind, entry point. Validated by `omarchy plugin validate` |
| `BarWidget.qml` | Manifest entry point. The bar button, plus the `Loader` that owns `Panel.qml` and forwards `open()/close()/toggle()` |
| `Panel.qml` | Composition only: header → tab bar → main area → footer, inside `qs.Ui`'s `Panel` + `KeyboardPanel` + `PanelKeyCatcher` |
| `panel/PanelHeader.qml` | Brand mark + wordmark on the left, credit balance on the right (every tab) |
| `panel/Tab.qml` | One tab button: theme-token pill, uppercase label |
| `panel/PanelFooter.qml` | Three shortcut buttons that open pages on openscale.so (every tab) |
| `panel/UsageTab.qml`, `panel/ModelsTab.qml`, `panel/SettingsTab.qml` | Tab bodies — placeholders for now |
| `assets/openscale.svg` | Brand mark, from openscale.so |

## How the shell loads it

`BarWidget.qml` is the entry point. It loads `Panel.qml` itself and exposes the
lifecycle the bar and `omarchy-shell shell summon` talk to:

```
opened, open(), close(), toggle(), popoutSwitchClosing, closeForPopoutSwitch()
```

`Panel.qml` receives `bar`, `settings`, `anchorItem` (the bar button) and
`hostWidget` via `injectPanel()` in `BarWidget.qml` — that is what anchors the
popup under the button and lets the bar know which panel is open.

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

- **Credit balance** is a placeholder in `BarWidget.qml` (`creditText`), pushed
  into the panel by `injectPanel()`. Both should read one shared source once a
  `Service.qml` fetches the real value.
- **Console link** points at `https://openscale.so/login`; there is no
  `/console` page. Credits → `/credits`, Docs → `/docs` are confirmed live.
- Tabs currently stretch to equal width (segmented-control look).
- `README` and `LICENSE` exist, which the marketplace requires; the repository
  must be **public** before it can be submitted.
