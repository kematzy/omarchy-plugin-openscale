import QtQuick
import Quickshell.Io

// Reads the OpenScale account balance from the `osc` CLI and holds it for the
// bar button and the panel.
//
// The CLI is the only read-only source for the balance: the public API has no
// credit endpoint. One poll is `osc balance --json`, whose `balanceUusd` is a
// micro-USD integer (11195181 is $11.195181). The command is a fixed string —
// nothing is ever interpolated into it — and this file only ever reads.
Item {
  id: root

  property var settings: ({})

  // -1 means "not known yet", which is not the same as a balance of zero and
  // must never be drawn as a figure.
  property real balanceUsd: -1
  // Rolling 24-hour spend, shown beside the calendar-day figures in the Spend
  // tab so the two "recent" numbers can be told apart.
  property real spent24hUsd: -1
  property bool ok: false
  property bool refreshing: false
  property string error: ""
  // Wall-clock time of the last successful poll, in ms. 0 means never.
  property double lastSuccessAt: 0

  // Background cadence while the panel is closed: the bar only needs a rough
  // figure at a glance, and the figure is refreshed on demand when the panel
  // opens. 30s minimum so it can be shortened while developing.
  readonly property int refreshIntervalSec: root.intSetting("refreshIntervalSec", 300, 30, 3600)
  // Opening the panel refreshes the balance only if the last good fetch is at
  // least this old, so flicking the panel open and shut cannot spawn a poll per
  // open. 0 disables the floor.
  readonly property int openRefreshGapSec: root.intSetting("openRefreshGapSec", 60, 0, 3600)

  // The bar and the panel both render this string, so the figure is formatted
  // once, here: dollars, always two decimals, no space after the sign.
  readonly property string creditText: root.balanceUsd >= 0 ? root.money(root.balanceUsd) : "—"

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var value = Math.round(parseFloat(String(root.setting(name, fallback))))
    if (!isFinite(value)) value = fallback
    return Math.max(min, Math.min(max, value))
  }

  function money(value) {
    var magnitude = Math.abs(value).toFixed(2)
    return (value < 0 ? "-$" : "$") + magnitude
  }

  function refresh() {
    if (proc.running) return
    // A manual refresh re-arms the background timer, so the next automatic
    // poll lands a full interval later instead of seconds after it.
    pollTimer.restart()
    refreshing = true
    proc.running = true
  }

  // Used when the panel opens. A failed poll leaves `lastSuccessAt` alone, so
  // the next open retries immediately instead of waiting out the gap.
  function refreshIfStale() {
    var ageSec = root.lastSuccessAt > 0
      ? (Date.now() - root.lastSuccessAt) / 1000
      : Infinity
    if (ageSec >= root.openRefreshGapSec) root.refresh()
  }

  // A refused or unreadable poll keeps the last good figure on screen and only
  // records why, so a transient failure never blanks the bar.
  function apply(text) {
    var parsed = null
    try {
      parsed = JSON.parse(String(text || ""))
    } catch (e) {
      parsed = null
    }

    var micro = parsed && typeof parsed === "object" ? parsed.balanceUusd : undefined
    var value = micro === null || micro === undefined ? NaN : Number(micro)
    if (!isFinite(value)) {
      ok = false
      error = "osc returned no balance"
      return
    }

    balanceUsd = value / 1000000
    var spend = parsed.spent24hUusd
    spent24hUsd = spend === null || spend === undefined ? -1 : Number(spend) / 1000000
    ok = true
    error = ""
    lastSuccessAt = Date.now()
  }

  function exitMessage(exitCode, stderrText) {
    // The CLI's documented exit codes: 0 ok, 1 error, 2 usage, 3 sign-in
    // needed, 4 out of credit, 5 limit reached. Only 3 has a fix worth naming.
    if (exitCode === 3) return "Not signed in — run `osc login`"
    var message = String(stderrText || "").trim()
    return message !== "" ? message : "osc balance exited with code " + exitCode
  }

  Timer {
    id: pollTimer
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: proc
    // `bash -c` so a missing CLI becomes exit 127 plus a readable stderr line.
    // A directly-executed missing binary never starts, and Quickshell's Process
    // emits no `exited` for that, so the failure would be silent.
    command: ["bash", "-c", "exec osc balance --json"]
    stdout: StdioCollector {
      id: procOut
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: procErr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.refreshing = false
      if (exitCode === 0) {
        root.apply(procOut.text)
        return
      }
      root.ok = false
      root.error = root.exitMessage(exitCode, procErr.text)
    }
  }
}
