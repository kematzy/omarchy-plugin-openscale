import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import "../Format.js" as Format

// "Models" tab: two-line blocks, one per model, cheapest first.
//
// A six-column table could only fit by shrinking everything to 11px, because
// the model name alone wants most of a 420px row. Giving each model two lines
// lets the name be read at subtitle size and the figures at body size, while
// the four figures stay in fixed-width groups so they still line up from row to
// row for comparison.
//
// The list comes from the on-disk catalogue cache via models.sh: read once when
// the panel builds its tabs, refreshed each time the Models tab is shown. That
// cached copy doubles as the baseline for the NEW badge — ids the live catalogue
// has and the cache did not are flagged for the rest of the session.
ColumnLayout {
  id: root

  property string fontFamily: Style.font.family
  property color foreground: Commons.Color.foreground
  property color mutedForeground: Commons.Color.muted
  property color accent: Commons.Color.accent

  // Cheapest first. "input" | "output" | "context" — the hook for clickable
  // sorting when the tab gains it; nothing sets it yet.
  property string sortKey: "input"

  // Filled from the on-disk cache when the tab is created, then replaced by a
  // live fetch each time it is shown. The cache lives at
  // ${XDG_CACHE_HOME:-~/.cache}/omarchy/openscale/models.json and is read and
  // written through models.sh, because QML cannot write files.
  property var models: []
  property double fetchedAt: 0
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

  // Base widths of the figure columns. Each column is fixed so the figures
  // line up from row to row; the gaps between them are flexible, which is what
  // spreads the four figures across the full width and lands the last value on
  // the right edge.
  readonly property real columnContext: Style.space(58)
  readonly property real columnInput: Style.space(60)
  readonly property real columnOutput: Style.space(68)
  readonly property real columnCached: Style.space(92)

  readonly property var rows: root.sortedModels()
  readonly property string sortCaption: root.sortKey === "output"
    ? "cheapest output first"
    : (root.sortKey === "context" ? "smallest context first" : "cheapest input first")

  spacing: Style.space(6)

  // The cache is read once, when the panel builds its tabs, so the Models tab
  // has content the first time it is opened after a shell restart.
  Component.onCompleted: root.loadCache()

  function loadCache() {
    if (helperPath === "") return
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

  // Panel.qml calls refresh() when this tab becomes the current one: one fetch
  // per visit, guarded against overlapping runs.
  function refresh() {
    if (proc.running) return
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
      if (!fromCache) error = "Could not read the model catalogue"
      return
    }
    if (typeof parsed.error === "string" && parsed.error !== "") {
      if (!fromCache) error = parsed.error
      return
    }
    if (!Array.isArray(parsed.models)) {
      // {} from --read is simply "no cache yet".
      if (!fromCache) error = "osc models returned no catalogue"
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


  function sortedModels() {
    var list = []
    for (var i = 0; i < (models ? models.length : 0); i++) list.push(models[i])
    var key = root.sortKey
    list.sort(function(a, b) {
      var av = root.sortValue(a, key)
      var bv = root.sortValue(b, key)
      if (av !== bv) return av - bv
      // Tiebreak on the id so equal prices keep a predictable order.
      return String(a.id).localeCompare(String(b.id))
    })
    return list
  }

  function sortValue(model, key) {
    if (!model) return 0
    if (key === "context") return Number(model.context) || 0
    var prices = model.usdPerMillion || {}
    return Number(prices[key]) || 0
  }

  // Names arrive as "Vendor: Model"; the vendor is redundant inside a table of
  // models, so only the model part is shown. Anything without that prefix is
  // left alone.
  function shortName(model) {
    var name = String(model && model.name ? model.name : (model ? model.id : ""))
    var separator = name.indexOf(": ")
    return separator >= 0 ? name.slice(separator + 2) : name
  }



  // Label in caption, figure in body: the label says what the number is, so the
  // table needs no header row and no abbreviation legend. The value is pushed
  // to the column's right edge, so figures in a column end on one line.
  //
  // Deliberately a plain Item with two Texts rather than a nested RowLayout: a
  // layout nested in a layout reports an unlimited preferred width, so it
  // absorbs the row's surplus and the flexible gaps collapse to zero.
  component Figure: Item {
    id: figure
    property string label: ""
    property string value: ""

    readonly property real labelGap: Style.space(5)

    implicitWidth: labelText.implicitWidth + labelGap + valueText.implicitWidth
    implicitHeight: Math.max(labelText.implicitHeight, valueText.implicitHeight)

    Text {
      id: labelText
      text: figure.label
      color: root.mutedForeground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      // Sit on the same baseline as the figure beside it, whatever the two
      // sizes are.
      y: valueText.y + (valueText.baselineOffset - labelText.baselineOffset)
    }

    Text {
      id: valueText
      text: figure.value
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.subtitle
      horizontalAlignment: Text.AlignRight
      x: labelText.implicitWidth + figure.labelGap
      width: Math.max(0, figure.width - x)
    }
  }

  // The list scrolls only when the catalogue outgrows the panel: the seven
  // current blocks nearly fill the tab's height, so clipping an eighth silently
  // would be worse than a scrollbar. The legend stays pinned below.
  Flickable {
    id: view

    Layout.fillWidth: true
    Layout.fillHeight: true
    contentWidth: width
    contentHeight: list.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    interactive: contentHeight > height

    ScrollBar.vertical: ScrollBar {
      policy: ScrollBar.AsNeeded
    }

    ColumnLayout {
      id: list

      width: view.width
      // Blocks read as separate entries: the base gap plus the extra air the
      // larger name line wants.
      spacing: Style.space(16)

      Repeater {
        model: root.rows

        delegate: ColumnLayout {
          id: block
          required property var modelData

          Layout.fillWidth: true
          // Room between the name and the figures under it, so the two lines
          // read as one block rather than as two unrelated rows.
          spacing: Style.space(6)

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            Text {
              Layout.fillWidth: false
              // Fast serving belongs to the model, not to a figure to compare,
              // so it sits at the end of the name. The name keeps its natural
              // width — capped so a long one elides instead of pushing the
              // glyph out — and the trailing spacer takes the surplus, which
              // is what keeps the glyph next to the text.
              Layout.maximumWidth: block.width
                - (badge.visible ? badge.implicitWidth + Style.space(6) : 0)
              text: root.shortName(block.modelData)
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }

            // Not in the catalogue the cache held when the shell started.
            Text {
              visible: root.isNew(block.modelData)
              text: "NEW"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 0.6
              Layout.alignment: Qt.AlignVCenter
            }

            Text {
              id: badge
              visible: block.modelData.fastMode === true
              text: "\uF0E7"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              Layout.alignment: Qt.AlignVCenter
            }

            Item {
              Layout.fillWidth: true
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Figure {
              Layout.preferredWidth: root.columnContext
              label: "Ctx"
              value: Format.context(block.modelData.context)
            }

            // Flexible gaps: fixed content columns with the surplus shared
            // equally between them, so the row spans the panel width.
            Item {
              Layout.fillWidth: true
            }

            Figure {
              Layout.preferredWidth: root.columnInput
              label: "In"
              value: Format.money(block.modelData.usdPerMillion ? block.modelData.usdPerMillion.input : -1)
            }

            Item {
              Layout.fillWidth: true
            }

            Figure {
              Layout.preferredWidth: root.columnOutput
              label: "Out"
              value: Format.money(block.modelData.usdPerMillion ? block.modelData.usdPerMillion.output : -1)
            }

            Item {
              Layout.fillWidth: true
            }

            Figure {
              Layout.preferredWidth: root.columnCached
              label: "Cache"
              value: Format.money(block.modelData.usdPerMillion ? block.modelData.usdPerMillion.cached : -1)
            }
          }
        }
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.space(8)

    Text {
      Layout.fillWidth: true
      text: root.error !== "" ? root.error : "Prices $/1M tokens"
      // Brighter than Color.muted: this line is the only explanation of the
      // figures, so it should be readable rather than decorative.
      color: root.error !== "" ? Commons.Color.urgent : Util.alpha(root.foreground, 0.75)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }

    // When the catalogue was last read from OpenScale, so a week-old cache is
    // visibly stale rather than quietly wrong.
    Text {
      visible: root.error === "" && root.fetchedAt > 0
      text: "Last updated: " + Format.stamp(root.fetchedAt)
      color: Util.alpha(root.foreground, 0.75)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
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
