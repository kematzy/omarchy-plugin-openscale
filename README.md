<p align="center">
  <img src="assets/openscale-logo.svg" alt="OpenScale" width="213">
</p>

# OpenScale for Omarchy

**Keep your OpenScale balance in the Omarchy bar. Open the panel for spending, token usage, and model pricing.**

OpenScale provides an OpenAI- and Anthropic-compatible API for open models. This plugin adds a balance widget and detail panel to the Omarchy bar, using your signed-in `osc` CLI so there is no API key to configure in the plugin.

> **Independent community plugin:** I’m an OpenScale customer, not affiliated with or endorsed by OpenScale.

## Quick start

You’ll need **Omarchy** with `omarchy-shell`, the **OpenScale CLI** signed in, and **`jq`** (included with Omarchy).

Install and sign in to the OpenScale CLI if you haven’t already:

```bash
curl -fsSL https://openscale.so/install | sh
osc login
```

Then install the plugin and restart the shell:

```bash
omarchy plugin add https://github.com/kematzy/omarchy-plugin-openscale.git --enable
omarchy restart shell
```

The widget appears in the right section of the bar. Move it with `omarchy bar move` if you want it elsewhere.

On a bare Arch install, install `jq` with `omarchy pkg add jq`.

To install by hand instead:

```bash
git clone https://github.com/kematzy/omarchy-plugin-openscale.git \
  ~/.config/omarchy/plugins/io.github.kematzy.openscale
omarchy plugin enable io.github.kematzy.openscale
omarchy restart shell
```

The clone folder must match the plugin’s manifest ID, which is why it is cloned to that path.

## Features

### Balance in the bar

- See your OpenScale balance next to the OpenScale mark, for example `$11.20`.
- Set a low-balance threshold; the balance is highlighted when it reaches or falls below it (default: `$3.00`).
- Hover to see the balance and, if a refresh failed, the reason.
- Click to open the panel. The balance refreshes as the panel opens if the last read is older than a minute.
- The balance refreshes in the background every 5 minutes by default.

![The bar widget with its balance highlighted at or below the threshold](.assets/low-balance-notification.png)

*When the balance reaches the threshold, it is highlighted in the bar and panel header.*

### Spend tab

Compare spending across four time windows:

| Window            | What it shows                                      |
| ----------------- | -------------------------------------------------- |
| **Last 24 hours** | Rolling spend, calculated from the account balance |
| **Today**         | Spend so far in the current calendar day           |
| **Last 7 days**   | Rolling seven-day spend                            |
| **Last 30 days**  | Rolling 30-day spend                               |

**Last 24 hours** and **Today** are different measures: one is a rolling window, the other resets at midnight.

The low-balance alert threshold is also shown here. Edit it in place; the value is saved to your bar configuration.

### Tokens tab

See request and token totals for today, the last 7 days, and the last 30 days. The breakdown includes input, cached input, output, and total tokens. Proportional bars show each model’s share of token usage in each time window.

### Models tab

Browse the available models, sorted by input price, with details to help you choose:

- Context window
- Input, output, and cached-input prices per 1M tokens
- A ⚡ mark for fast-serving variants
- **NEW** beside models added since your cached catalogue was last updated

The catalogue is cached on disk, so it appears immediately when the panel opens and refreshes when you visit the Models tab.

### Keyboard controls

`1` `2` `3` switch tabs · `←` `→` (or `h` `l`) move between tabs · `Esc` closes the panel · `Tab` moves to the neighbouring bar panel.

When the low-balance threshold field is focused, it captures arrow keys and digits so typing `10` does not switch to tab 1.

### Screenshots

| Spend                           | Tokens                            | Models                            |
| ------------------------------- | --------------------------------- | --------------------------------- |
| ![Spend tab](.assets/tab-spend.png) | ![Tokens tab](.assets/tab-tokens.png) | ![Models tab](.assets/tab-models.png) |

## Configuration

Three settings are available in Omarchy’s **Settings → Widgets** panel and can also be edited from the command line:

| Setting              | Default | What it does                                                                                  |
| -------------------- | ------- | --------------------------------------------------------------------------------------------- |
| `lowBalance`         | `3`     | Highlight the balance at or below this many dollars. Also editable on the Spend tab.           |
| `refreshIntervalSec` | `300`   | Background refresh interval in seconds (30-second minimum).                                    |
| `openRefreshGapSec`  | `60`    | Refresh on panel open only if the last read is older than this. Set to `0` to refresh on every open. |

```bash
omarchy bar set io.github.kematzy.openscale lowBalance 10 --json
omarchy bar set io.github.kematzy.openscale refreshIntervalSec 120 --json
```

## Privacy and safety

- **Read-only account access.** The plugin uses the CLI to read your balance, usage, and model catalogue. It does not create, rotate, or revoke API keys, move credit, or write to your OpenScale account.
- **Credentials stay with the CLI.** The plugin does not read, copy, log, or cache your token or API key. `osc` manages device login; the widget requests data through the CLI.
- **Local persistent data.** The model catalogue cache is stored in `~/.cache/omarchy/openscale/`. The low-balance threshold is saved to your bar configuration through `omarchy bar set`.
- **No direct OpenScale network requests.** OpenScale traffic is handled by the `osc` CLI.
- **Fixed commands.** The plugin starts commands with fixed arguments, such as `osc balance --json`, `models.sh --read`, and `omarchy bar set …`. Values you type are not interpolated into shell commands.
- **No elevated privileges.** The plugin does not request elevated permissions.
- **Visible errors.** If a read fails, the last successful balance remains visible and the error is shown in the tooltip or the tab’s footer.

The plugin runs inside `omarchy-shell`, like other bar widgets. To audit it before enabling, start with `Service.qml`, `Usage.qml`, and `models.sh`.

## Updating and removing

```bash
omarchy plugin update io.github.kematzy.openscale
omarchy plugin remove io.github.kematzy.openscale
```

Removing the plugin leaves `~/.cache/omarchy/openscale/models.json` behind. It is harmless and safe to delete:

```bash
rm -rf ~/.cache/omarchy/openscale
```

## Contributing

Issues and pull requests are welcome. Before opening a PR, validate the plugin:

```bash
omarchy plugin validate .
```

If you have the shell’s QML kit on disk, run the lint described in [docs/README.md](docs/README.md#checks). Keep changes focused and follow the surrounding style; the code is commented for a reason.

## License

[MIT](LICENSE).

## Credits

- **[OpenScale](https://openscale.so)** — the models, API, and `osc` CLI this plugin uses. This is an independent community plugin and is not affiliated with OpenScale.
- **[Omarchy](https://omarchy.org)** — the desktop, its shell, and the `qs.Ui` component kit used to build the panel.
- **Omarchy plugin authors** — many Omarchy plugins have served as useful references for bar widgets and popup panels.

## Technical documentation

For architecture, data sources, refresh and caching policies, Omarchy plugin mechanics, and development notes, see **[docs/README.md](docs/README.md)**.
