import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../Format.js" as Format

// "Models" tab: one line per model, grouped under vendor headers, filtered as
// you type.
//
// One line per model keeps the four figures in fixed-width columns that line
// up from row to row for comparison, and a ListView recycles delegates so a
// long catalogue scrolls without instantiating every row at once.
//
// The list comes from the on-disk catalogue cache via models.sh: read once when
// the panel builds its tabs, refreshed when the Models tab is shown and the
// cache is missing or at least 24 hours old. That cached copy doubles as the
// baseline for the NEW badge — ids the live catalogue has and the cache did not
// are flagged for the rest of the session.
ColumnLayout {
  id: root

  property var ui: null

  // Filled from the on-disk cache when the tab is created. Refresh only after
  // the cached catalogue is 24 hours old. The cache lives at
  // ${XDG_CACHE_HOME:-~/.cache}/omarchy/openscale/models.json and is read and
  // written through models.sh, because QML cannot write files.
  property var models: []
  property double fetchedAt: 0
  property bool cacheLoaded: false
  property bool refreshPending: false
  readonly property int cacheRefreshGapSec: 24 * 60 * 60
  // Drives the spinner in the tab bar: true only while a fetch is in flight.
  property bool loading: false
  property string error: ""

  // The catalogue the cache held when the panel was built, so a refresh can
  // tell which models were not in it. No cache means no baseline, and then
  // nothing is labelled new — better than flagging the whole list.
  property var knownIds: ({})
  property bool hasBaseline: false
  property var newIds: ({})

  readonly property string helperPath: String(Qt.resolvedUrl("../models.sh"))
    .replace(/^file:\/\//, "")

  // What the filter field holds; "" shows everything.
  property string filter: ""
  // True while the filter field has the keyboard. Panel.qml blocks its key
  // catcher on this so typing reaches the field instead of changing tabs.
  readonly property bool editing: filterInput.activeFocus

  // True before any catalogue has arrived and nothing has failed: there is
  // nothing to list yet, so the list makes way for a loading note.
  readonly property bool firstRun: root.models.length === 0 && root.error === ""

  // True when the catalogue loader's failure leaves nothing to show — the
  // sign-in case. Transient failures stay in the status strip instead.
  readonly property bool blocked: Format.isBlocking(root.error)

  // Base widths of the figure columns. Each column is fixed so the figures
  // line up from row to row; the flexible name column takes the surplus, which
  // is what spreads the four figures across the full width and lands the last
  // value on the right edge.
  readonly property real columnContext: Style.space(48)
  readonly property real columnInput: Style.space(56)
  readonly property real columnOutput: Style.space(56)
  readonly property real columnCached: Style.space(56)

  // The scrollbar is an overlay on the list's right edge, so without a
  // reserved lane it paints over the CACHE column (and the header above it
  // reads misaligned with the rows). Fixed rather than conditional: a gutter
  // that appears with the scrollbar would shift every column when the list
  // overflows or not.
  readonly property real scrollGutter: Style.space(12)

  // A flat list of header and model entries, so one ListView can render both.
  // Vendors are alphabetical; models inside a vendor are cheapest-input first.
  readonly property var rows: {
    var needle = String(root.filter || "").toLowerCase()
    var groups = ({})
    for (var i = 0; i < (root.models ? root.models.length : 0); i++) {
      var m = root.models[i]
      if (!m) continue
      if (needle !== "") {
        var hay = (String(m.name || "") + " " + String(m.id || "")).toLowerCase()
        if (hay.indexOf(needle) === -1) continue
      }
      var vendor = root.vendorOf(m)
      if (!groups[vendor]) groups[vendor] = []
      groups[vendor].push(m)
    }

    var vendors = Object.keys(groups).sort(function(a, b) { return a.localeCompare(b) })
    var out = []
    for (var v = 0; v < vendors.length; v++) {
      var list = groups[vendors[v]]
      list.sort(function(a, b) {
        var ap = (a.usdPerMillion && a.usdPerMillion.input) || 0
        var bp = (b.usdPerMillion && b.usdPerMillion.input) || 0
        if (ap !== bp) return ap - bp
        return String(a.id).localeCompare(String(b.id))
      })
      out.push({ isHeader: true, vendor: vendors[v], model: null })
      for (var k = 0; k < list.length; k++) {
        out.push({ isHeader: false, vendor: vendors[v], model: list[k],
                   last: k === list.length - 1 })
      }
    }
    return out
  }

  spacing: Style.space(8)

  // The cache is read once, when the panel builds its tabs, so the Models tab
  // has content the first time it is opened after a shell restart.
  Component.onCompleted: root.loadCache()

  function loadCache() {
    if (helperPath === "") {
      cacheLoaded = true
      return
    }
    cacheProc.running = true
  }

  function idsOf(list) {
    var set = ({})
    for (var i = 0; i < (list ? list.length : 0); i++) {
      if (list[i] && list[i].id) set[String(list[i].id)] = true
    }
    return set
  }

  function isNew(model) {
    return !!model && root.newIds[String(model.id)] === true
  }

  // Panel.qml calls refresh() when this tab becomes current. Wait for the cache
  // read, then fetch only when no cached catalogue exists or it is at least 24h old.
  function refresh() {
    if (proc.running) return
    if (!cacheLoaded) {
      refreshPending = true
      return
    }
    var ageSec = fetchedAt > 0 ? Date.now() / 1000 - fetchedAt : Infinity
    if (ageSec < cacheRefreshGapSec) return
    loading = true
    proc.running = true
  }

  // Both modes of models.sh speak the same envelope:
  // {fetchedAt, models} on success, {error} on failure, {} when there is no
  // cache. A cache read never shows the spinner and never clears good data.
  function apply(text, fromCache) {
    var parsed = null
    try {
      parsed = JSON.parse(String(text || ""))
    } catch (e) {
      parsed = null
    }
    if (!parsed || typeof parsed !== "object") {
      if (!fromCache) error = "Could not read the cached model list"
      return
    }
    if (typeof parsed.error === "string" && parsed.error !== "") {
      if (!fromCache) error = parsed.error
      return
    }
    if (!Array.isArray(parsed.models)) {
      // {} from --read is simply "no cache yet".
      if (!fromCache) error = "osc models returned no listing"
      return
    }
    if (fromCache) {
      knownIds = root.idsOf(parsed.models)
      hasBaseline = true
    } else if (hasBaseline) {
      // Mark what the cached list did not have. The marks last for the session:
      // the cache has been rewritten by now, so they cannot be recomputed later.
      var fresh = root.idsOf(parsed.models)
      var added = ({})
      for (var id in fresh) if (knownIds[id] !== true) added[id] = true
      newIds = added
    }

    models = parsed.models
    fetchedAt = Number(parsed.fetchedAt) || 0
    error = ""
  }

  // Names arrive as "Vendor: Model" and sometimes carry a trailing "(fast)".
  // The vendor is a group header now, and the lightning glyph already says
  // "fast", so both are removed from the name itself.
  function shortName(model) {
    var name = String(model && model.name ? model.name : (model ? model.id : ""))
    var separator = name.indexOf(": ")
    if (separator >= 0) name = name.slice(separator + 2)
    return name.replace(/\s*\(fast\)\s*$/i, "")
  }

  // "Vendor" from "Vendor: Model"; "Other" when the name carries no prefix.
  function vendorOf(model) {
    var name = String(model && model.name ? model.name : "")
    var separator = name.indexOf(": ")
    return separator >= 0 ? name.slice(0, separator) : "Other"
  }

  TabMessage {
    Layout.fillWidth: true
    Layout.fillHeight: true
    visible: root.blocked
    ui: root.ui
    glyph: "\uF023"
    title: "Not signed in"
    detail: "OpenScale needs an authenticated session. Run osc login in a terminal."
    actionLabel: "RUN OSC LOGIN"
    onActionTriggered: Util.execArgv(["omarchy-launch-terminal", "osc", "login"])
  }

  Text {
    Layout.fillWidth: true
    visible: !root.blocked
    text: "Available Models"
    color: root.ui.fg
    font.family: root.ui.fontFamily
    font.pixelSize: Style.font.title
    font.bold: true
  }

  // Borderless, square, with a focus rule rather than a box: the panel has no
  // other outlined control.
  Rectangle {
    Layout.fillWidth: true
    visible: !root.blocked
    implicitHeight: Style.space(28)
    color: "transparent"

    Text {
      id: searchIcon
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "\uF002"
      color: root.ui.label
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    TextInput {
      id: filterInput
      anchors.left: searchIcon.right
      anchors.leftMargin: Style.space(8)
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      color: root.ui.fg
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.bodySmall
      selectByMouse: true
      onTextChanged: root.filter = text
      Keys.onEscapePressed: { text = ""; focus = false }

      Text {
        anchors.fill: parent
        visible: filterInput.text === ""
        text: "Filter models"
        color: root.ui.caption
        font: filterInput.font
      }
    }

    PanelSeparator {
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      foreground: filterInput.activeFocus ? root.ui.accent : root.ui.fg
      strength: filterInput.activeFocus ? 1.0 : root.ui.ruleFaint
      height: filterInput.activeFocus ? Style.space(2) : 1
    }
  }

  // Pinned column header. The MODEL cell plays the name column: flexible,
  // taking the same surplus the rows' names take, so the four figure columns
  // land on the same edges as the rows below. The right margin reserves the
  // scrollbar's lane.
  RowLayout {
    Layout.fillWidth: true
    visible: !root.firstRun && !root.blocked
    Layout.rightMargin: root.scrollGutter
    spacing: Style.space(8)

    Text {
      Layout.fillWidth: true
      text: "MODEL"
      color: root.ui.label
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.caption
      font.capitalization: Font.AllUppercase
      font.letterSpacing: 0.8
      horizontalAlignment: Text.AlignLeft
    }

    Text {
      Layout.preferredWidth: root.columnContext
      text: "CTX"
      color: root.ui.label
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.caption
      font.capitalization: Font.AllUppercase
      font.letterSpacing: 0.8
      horizontalAlignment: Text.AlignRight
    }

    Text {
      Layout.preferredWidth: root.columnInput
      text: "IN"
      color: root.ui.label
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.caption
      font.capitalization: Font.AllUppercase
      font.letterSpacing: 0.8
      horizontalAlignment: Text.AlignRight
    }

    Text {
      Layout.preferredWidth: root.columnOutput
      text: "OUT"
      color: root.ui.label
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.caption
      font.capitalization: Font.AllUppercase
      font.letterSpacing: 0.8
      horizontalAlignment: Text.AlignRight
    }

    Text {
      Layout.preferredWidth: root.columnCached
      text: "CACHE"
      color: root.ui.label
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.caption
      font.capitalization: Font.AllUppercase
      font.letterSpacing: 0.8
      horizontalAlignment: Text.AlignRight
    }
  }

  PanelSeparator {
    Layout.fillWidth: true
    visible: !root.firstRun && !root.blocked
    foreground: root.ui.fg
    strength: root.ui.ruleFaint
  }

  // The list scrolls only when the catalogue outgrows the panel: clipping a
  // model silently would be worse than a scrollbar. Errors and the timestamp
  // live in the shared status strip below, not here.
  //
  // Plain-Item wrapper so the fade can anchor to the ListView without
  // fighting the ColumnLayout for position.
  Item {
    Layout.fillWidth: true
    Layout.fillHeight: true
    visible: !root.blocked

    ListView {
      id: view

      anchors.fill: parent
      visible: !root.firstRun
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      model: root.rows
      spacing: 0

      ScrollBar.vertical: ScrollBar {
        policy: view.contentHeight > view.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
      }

      delegate: Loader {
        required property var modelData
        // Inset by the scrollbar's reserved lane, so the CACHE column and the
        // row separators stay clear of the overlay.
        width: view.width - root.scrollGutter
        sourceComponent: modelData.isHeader ? vendorHeader : modelRow
        property var entry: modelData
      }
    }

    // Says "there is more below" on a popup the user may never hover, which is
    // what ScrollBar.AsNeeded cannot do.
    Rectangle {
      anchors.left: view.left
      anchors.right: view.right
      anchors.bottom: view.bottom
      height: Style.space(16)
      visible: view.contentHeight > view.height
        && view.contentY < view.contentHeight - view.height - 1
      gradient: Gradient {
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 1.0; color: root.ui.surface }
      }
    }

    // First run: nothing fetched yet and nothing failed. Errors go to the
    // status strip instead of blanking the tab.
    Text {
      anchors.centerIn: parent
      visible: root.firstRun
      text: "Loading models…"
      color: root.ui.caption
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  // Vendor group header. Same device the Spend tab uses for ROLLING/CALENDAR,
  // so the two lists read the same way.
  Component {
    id: vendorHeader
    Item {
      implicitHeight: Style.space(28)
      width: parent ? parent.width : 0
      Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(4)
        text: parent.parent.entry.vendor.toUpperCase()
        color: root.ui.label
        font.family: root.ui.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 0.8
      }
    }
  }

  Component {
    id: modelRow
    Item {
      id: rowItem
      readonly property var entry: parent.entry
      readonly property var m: rowItem.entry.model
      implicitHeight: Style.space(24)
      width: parent ? parent.width : 0

      RowLayout {
        anchors.fill: parent
        spacing: Style.space(8)

        Text {
          Layout.fillWidth: true
          text: root.shortName(rowItem.m)
          color: root.ui.fg
          font.family: root.ui.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        Text {
          visible: root.isNew(rowItem.m)
          text: "NEW"
          color: root.ui.accent
          font.family: root.ui.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 0.8
        }

        Text {
          visible: rowItem.m.fastMode === true
          text: "\u26A1"
          color: root.ui.accent
          font.family: root.ui.fontFamily
          font.pixelSize: Style.font.caption
        }

        Text {
          Layout.preferredWidth: root.columnContext
          text: Format.context(rowItem.m.context)
          color: root.ui.fg
          font.family: root.ui.fontFamily
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignRight
        }

        Text {
          Layout.preferredWidth: root.columnInput
          text: Format.price(rowItem.m.usdPerMillion ? rowItem.m.usdPerMillion.input : -1)
          color: root.ui.fg
          font.family: root.ui.fontFamily
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignRight
        }

        Text {
          Layout.preferredWidth: root.columnOutput
          text: Format.price(rowItem.m.usdPerMillion ? rowItem.m.usdPerMillion.output : -1)
          color: root.ui.fg
          font.family: root.ui.fontFamily
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignRight
        }

        Text {
          Layout.preferredWidth: root.columnCached
          text: Format.cachePrice(rowItem.m.usdPerMillion ? rowItem.m.usdPerMillion.cached : -1)
          color: root.ui.fg
          font.family: root.ui.fontFamily
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignRight
        }
      }

      PanelSeparator {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        visible: !rowItem.entry.last
        foreground: root.ui.fg
        strength: root.ui.ruleFaint
      }
    }
  }

  // Cache read at startup: silent, no spinner.
  Process {
    id: cacheProc

    command: ["bash", root.helperPath, "--read"]
    stdout: StdioCollector {
      id: cacheOut
      waitForEnd: true
    }
    stderr: StdioCollector {
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode === 0) root.apply(cacheOut.text, true)
      root.cacheLoaded = true
      if (root.refreshPending) {
        root.refreshPending = false
        root.refresh()
      }
    }
  }

  // Live fetch when the tab is shown; this one owns the spinner.
  Process {
    id: proc

    command: ["bash", root.helperPath, "--refresh"]
    stdout: StdioCollector {
      id: procOut
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: procErr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.loading = false
      if (exitCode === 0) {
        root.apply(procOut.text, false)
        return
      }
      var message = String(procErr.text || "").trim()
      root.error = message !== "" ? message : "models.sh exited with code " + exitCode
    }
  }
}
