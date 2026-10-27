import QtQuick
import Quickshell.Io
import "Format.js" as Format

// Loads the three usage windows from the `osc` CLI and holds them for the Spend
// and Tokens tabs.
//
// Both tabs read this one object, so switching between them never re-fetches:
// the windows come from three separate CLI calls (~300 ms each) and nothing is
// cached on disk — usage moves constantly, and the on-disk decision was
// models-only.
Item {
  id: root

  // { costUsd, requests, input, cached, output, total, models: [{ model, tokens }] }
  property var today: null
  property var week: null
  property var month: null

  property bool loading: false
  property string error: ""
  property double fetchedAt: 0

  readonly property bool hasData: today !== null || week !== null || month !== null

  // Three calls per visit is the churn worth avoiding, so a tab that was just
  // shown does not fetch again. Not a setting: the only knob worth exposing in
  // this plugin is the low-balance threshold.
  readonly property int refreshGapSec: 60

  readonly property var periods: ["--today", "--7d", "--30d"]

  property int _index: -1

  function refresh() {
    if (proc.running) return
    var ageSec = fetchedAt > 0 ? (Date.now() - fetchedAt) / 1000 : Infinity
    if (ageSec < refreshGapSec) return
    error = ""
    loading = true
    _index = 0
    loadCurrent()
  }

  function loadCurrent() {
    // Fixed command: the period is one of our own constants, never user input.
    proc.command = ["bash", "-c", "exec osc usage " + periods[_index] + " --json"]
    proc.running = true
  }

  function applyWindow(index, text) {
    var parsed = null
    try {
      parsed = JSON.parse(String(text || ""))
    } catch (e) {
      parsed = null
    }
    if (!parsed || typeof parsed !== "object" || !parsed.tokens) {
      error = "osc usage returned no figures"
      return
    }

    var tokens = parsed.tokens || {}
    var input = Number(tokens.input) || 0
    var cached = Number(tokens.cached) || 0
    var output = Number(tokens.output) || 0
    var window = {
      costUsd: (Number(parsed.costUusd) || 0) / 1000000,
      requests: Number(parsed.requests) || 0,
      input: input,
      cached: cached,
      output: output,
      total: input + cached + output,
      models: Array.isArray(parsed.models) ? parsed.models : []
    }

    if (index === 0) today = window
    else if (index === 1) week = window
    else month = window
  }

  Process {
    id: proc

    stdout: StdioCollector {
      id: procOut
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: procErr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      var stderrText = String(procErr.text || "").trim()
      if (exitCode === 0) {
        root.applyWindow(root._index, procOut.text)
      } else if (exitCode === 3) {
        root.error = "Not signed in — run `osc login`"
      } else {
        // stderr normally carries the reason; the CLI sometimes reports on stdout.
        root.error = Format.errorText(stderrText !== "" ? procErr.text : procOut.text,
          "osc usage exited with code " + exitCode)
      }

      // Keep going after a failed window: partial figures are still worth
      // showing, and the error line says what went missing.
      if (root._index + 1 < root.periods.length) {
        root._index += 1
        root.loadCurrent()
        return
      }

      root._index = -1
      root.loading = false
      if (root.error === "") root.fetchedAt = Date.now()
    }
  }
}
