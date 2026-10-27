<!-- markdownlint-disable-file MD033 -->

<div align="center">
  <img src="assets/openscale-logo.svg" alt="OpenScale" width="213">
</div>

# OpenScale for Omarchy v4+

**Your OpenScale balance in the Omarchy bar with easy access to extended spending, token usage,
and model pricing information**

[OpenScale](https://openscale.so) provides open-source AI models at cheap prices for users in
emerging economies.

This plugin adds an [Omarchy](https://omarchy.org) top bar widget showing current account balance,
with a popup window displaying the **account balance** and what was spent **today**, the last seven
or 30 days. It also shows token usage, which models were used and available models and their usage rates.

<div align="center">
  <img src=".assets/tab-spend.png" alt="The OpenScale plugin">
</div>

---

> [!NOTE]
> This project is not affiliated with or endorsed by OpenScale.

---

## Key Features

### Spending Overview (USD)

<div align="center">
  <img src=".assets/tab-spend.png" alt="OpenScale plugin spend tab">
</div>

- Provides a quick overview of the rolling spending within:
  - the **Last 24 hours**
  - **Today** (_resets at midnight_)
  - the **Last 7 days**
  - the **Last 30 days**
- Set your own low-balance alert threshold, by default USD $3.00.

<br />

### Tokens & Models Used

<div align="center">
  <img src=".assets/tab-tokens.png" alt="OpenScale plugin tokens tab">
</div>

- Easy overview of requests and token usage for:
  - **Today**
  - the **Last 7 days**
  - the **Last 30 days**
- Shows used models in proportional bars with relative percentage values.

<br />

### Available Models & Pricing

<div align="center">
  <img src=".assets/tab-models.png" alt="OpenScale plugin models tab">
</div>

- Shows available models, sorted by input price, with details showing:
  - Context window
  - Input, output, and cached-input prices per 1M tokens
  - A ⚡ mark for fast-serving variants
  - A **NEW** label beside recently added models

> [!Note]
> The list is cached on disk for 24 hours or refreshes when you visit the Models tab.

<br />

### Low Balance Notification

<div align="center">
  <img src=".assets/low-balance-notification.png" alt="OpenScale plugin low balance notification">
</div>

- Shown as red in the bar widget and panel header when your remaining balance is below your set limit.
- The balance refreshes every 5 minutes by default, or when the panel is opened.

### Keyboard Navigation

- Switch tabs by pressing `1`, `2`, `3` or `←`, `→` or `h`, `l`
- Press `Esc` to close the panel
- Press `Tab` to move to the next bar panel.

> [!Note]
> When the low-balance threshold field is focused, arrow keys and digits are captured.

---

## Quick Start

To use the plugin you need to have **OpenScale CLI** installed and be signed in.

See the [OpenScale Dashboard](https://app.openscale.so/app) for the OpenScale CLI installation
instructions.

Install and sign in to the OpenScale CLI if you haven't already:

```bash
osc login
```

Then install the plugin and restart the shell:

```bash
omarchy plugin add https://github.com/kematzy/omarchy-plugin-openscale.git --enable
```

The widget appears in the right section of the bar, but you can easily move it by clicking and
dragging.

---

## Configuration

Three settings are available in Omarchy’s **Settings → Widgets** panel and can also be edited from
the command line:

| Setting              | Default | What it does                                                    |
| -------------------- | ------- | --------------------------------------------------------------- |
| `lowBalance`         | `3`     | Highlight the balance at or below this many dollars.            |
| `refreshIntervalSec` | `300`   | Background refresh interval in seconds.                         |
| `openRefreshGapSec`  | `60`    | Refresh on panel open only if the last read is older than this. |

```bash
omarchy bar set io.github.kematzy.openscale lowBalance 10 --json
omarchy bar set io.github.kematzy.openscale refreshIntervalSec 120 --json
```

## Privacy & Safety

- **Read-only account access**

  The plugin uses the CLI to read your balance, usage, and model catalogue. It does not create,
  rotate, or revoke API keys, move credit, or write to your OpenScale account.

- **Credentials stay with the CLI**

  The plugin does not read, copy, log, or cache your token or API key. `osc` manages device login;
  the widget only requests data through the CLI.

- **Local persistent data**

  The model listing cache is stored in `~/.cache/omarchy/openscale/`, and the low-balance threshold
  is saved to your bar configuration through `omarchy bar set`.

- **No direct OpenScale network requests**

  OpenScale traffic is handled by the `osc` CLI.

- **Fixed commands**

  The plugin starts commands with fixed arguments, such as `osc balance --json`, `models.sh --read`,
  and `omarchy bar set …`. Values you type are not interpolated into shell commands.

- **No elevated privileges**

  The plugin does not request elevated permissions.

- **Visible errors**

  If a read fails, the last successful balance remains visible and the error is shown in the
  tooltip or the tab's footer.

The plugin runs inside `omarchy-shell`, like other bar widgets. To audit it before enabling,
start with `Service.qml`, `Usage.qml`, and `models.sh`.

## Updating & Removing

To update the plugin, run this command:

```bash
omarchy plugin update io.github.kematzy.openscale
```

To remove the plugin, run this command:

```bash
omarchy plugin remove io.github.kematzy.openscale
```

> [!Note]
> Removing the plugin leaves `~/.cache/omarchy/openscale/models.json` behind. It is harmless and safe
> to delete with:
>
> ```bash
> rm -rf ~/.cache/omarchy/openscale
> ```

## Contributing

Issues and pull requests are welcome. Before opening a PR, validate the plugin:

```bash
omarchy plugin validate .
```

If you have the shell's QML kit on disk, run the lint described in [docs/README.md](docs/README.md#checks).
Keep changes focused and follow the surrounding code style.

## License

Released under the [MIT](LICENSE).

Copyright [Kematzy](https://github.com/kematzy)

## Credits

- [**OpenScale**](https://openscale.so) — the models, API, and `osc` CLI this plugin uses.
  Most of the plugin code was created using OpenScale models for assistance.

- [**Omarchy**](https://omarchy.org) — the desktop, its shell, and the `qs.Ui` component kit used
  to build the panel.

- [**Omarchy plugin authors**](https://plugins.omarchy.org/) — many Omarchy plugins have served as
  useful references for this plugin.

## Technical documentation

For architecture, data sources, refresh and caching policies, Omarchy plugin mechanics, and
development notes, see **[docs/README.md](docs/README.md)**.
