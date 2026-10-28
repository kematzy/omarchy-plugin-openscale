import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../Format.js" as Format

// "Tokens" tab: requests and tokens for the same three windows, each followed
// by the share of tokens each model accounted for.
//
// The share is token share, not spend: `osc usage` reports tokens per model
// only, and inventing per-model cost from list prices would be a guess.
//
// The five figures are right-aligned into columns whose widths are shared by
// the pinned header row and the value rows, so they line up down the list; the
// headers and values are plain Texts (not nested layouts) because a layout
// nested in a layout reports an unlimited preferred width and swallows the
// row's spare space. The three sections scroll as one list once a window
// carries several models.
ColumnLayout {
  id: root

  property var ui: null
  property var usage: null

  readonly property var metricLabels: ["Requests", "Input", "Cached", "Output", "Total"]
  readonly property var columnWidths: [
    Style.space(68), Style.space(58), Style.space(62), Style.space(58), Style.space(58)
  ]

  // One unit per column, picked from the largest value any window carries, so
  // the three sections are directly comparable down the column.
  readonly property var columnUnits: {
    var windows = [root.usage ? root.usage.today : null,
                   root.usage ? root.usage.week : null,
                   root.usage ? root.usage.month : null]
    var keys = ["requests", "input", "cached", "output", "total"]
    var units = []
    for (var c = 0; c < keys.length; c++) {
      var max = 0
      for (var w = 0; w < windows.length; w++) {
        if (windows[w]) max = Math.max(max, Number(windows[w][keys[c]]) || 0)
      }
      units.push(Format.unitFor(max))
    }
    return units
  }

  spacing: Style.space(12)

  Text {
    Layout.fillWidth: true
    text: "Token Usage"
    color: root.ui.fg
    font.family: root.ui.fontFamily
    font.pixelSize: Style.font.title
    font.bold: true
  }

  // Pinned column header. The leading spacer matches the sections' content
  // indent, so the labels sit exactly over the figures.
  RowLayout {
    Layout.fillWidth: true
    spacing: Style.space(8)

    Item { Layout.preferredWidth: Style.space(12) }

    Repeater {
      model: root.metricLabels.length

      Text {
        required property int index

        Layout.fillWidth: true
        Layout.preferredWidth: root.columnWidths[index]
        text: root.metricLabels[index]
        color: index === 4 ? root.ui.fg : root.ui.label
        font.family: root.ui.fontFamily
        font.pixelSize: Style.font.caption
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.8
        horizontalAlignment: Text.AlignRight
      }
    }
  }

  PanelSeparator {
    Layout.fillWidth: true
    foreground: root.ui.fg
    strength: root.ui.ruleFaint
  }

  // Plain-Item wrapper so the fade can anchor to the Flickable without
  // fighting the ColumnLayout for position.
  Item {
    Layout.fillWidth: true
    Layout.fillHeight: true

    Flickable {
      id: view

      anchors.fill: parent
      contentWidth: width
      contentHeight: sections.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      interactive: contentHeight > height

      ScrollBar.vertical: ScrollBar {
        policy: view.contentHeight > view.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
      }

      ColumnLayout {
        id: sections

        width: view.width
        spacing: Style.space(16)

        Section {
          title: "Today"
          window: root.usage ? root.usage.today : null
        }
        Section {
          title: "Last 7 days"
          window: root.usage ? root.usage.week : null
        }
        Section {
          title: "Last 30 days"
          window: root.usage ? root.usage.month : null
        }
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
  }

  // Closes the scroll area.
  PanelSeparator {
    Layout.fillWidth: true
    foreground: root.ui.fg
    strength: root.ui.ruleStrong
  }

  // One window: title, the five figures, then the model list.
  component Section: ColumnLayout {
    id: section
    property string title: ""
    property var window: null

    // A window with no requests has nothing to tabulate; the empty state
    // replaces the figures and the model list.
    readonly property bool empty: !section.window || section.window.requests === 0

    readonly property var figures: {
      var w = section.window
      if (!w) return ["—", "—", "—", "—", "—"]
      return [
        Format.inUnit(w.requests, root.columnUnits[0]),
        Format.inUnit(w.input, root.columnUnits[1]),
        Format.inUnit(w.cached, root.columnUnits[2]),
        Format.inUnit(w.output, root.columnUnits[3]),
        Format.inUnit(w.total, root.columnUnits[4])
      ]
    }

    // Share of the window's tokens, biggest first. Zero-total windows have no
    // shares to show rather than a row of 0%.
    readonly property var modelShares: {
      var w = section.window
      if (!w || w.total <= 0 || !w.models) return []
      var list = []
      for (var i = 0; i < w.models.length; i++) {
        var entry = w.models[i]
        var tokens = Number(entry.tokens) || 0
        list.push({
          model: String(entry.model || ""),
          tokens: tokens,
          percent: Format.percent(tokens / w.total)
        })
      }
      list.sort(function(a, b) { return b.tokens - a.tokens })
      return list
    }

    Layout.fillWidth: true
    spacing: Style.space(4)

    Text {
      Layout.fillWidth: true
      text: section.title
      color: root.ui.fg
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
    }

    RowLayout {
      visible: !section.empty
      Layout.fillWidth: true
      spacing: Style.space(8)

      // Indents the figures to the same edge as the model list below them,
      // where the pinned header's spacer finds them.
      Item { Layout.preferredWidth: Style.space(12) }

      Repeater {
        model: section.figures.length

        Text {
          required property int index

          Layout.fillWidth: true
          Layout.preferredWidth: root.columnWidths[index]
          text: section.figures[index]
          color: root.ui.fg
          font.family: root.ui.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: index === 4
          horizontalAlignment: Text.AlignRight
        }
      }
    }

    Text {
      visible: section.empty
      Layout.fillWidth: true
      text: "No usage in this window."
      color: root.ui.caption
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    // Zero-total windows — which includes every zero-request window — have no
    // shares to list, so the model list is empty exactly when it must hide.
    Repeater {
      model: section.modelShares

      delegate: ModelShare {
        required property var modelData

        label: modelData.model
        percent: modelData.percent
        last: index === section.modelShares.length - 1
      }
    }
  }

  // Model id and its share of the window's tokens. A proportional bar was
  // worse than useless here: a single model at 100% next to one at <1% draws a
  // full block beside an empty one, which reads as a rendering fault rather
  // than as a distribution.
  component ModelShare: Item {
    id: share
    property string label: ""
    property string percent: ""
    property bool last: false

    Layout.fillWidth: true
    implicitHeight: Style.space(24)

    Text {
      id: nameText
      anchors.left: parent.left
      anchors.leftMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(0, parent.width - percentText.implicitWidth - Style.space(24))
      text: share.label
      color: root.ui.fg
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideMiddle
    }

    Text {
      id: percentText
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: share.percent
      color: root.ui.fg
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    PanelSeparator {
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.leftMargin: Style.space(12)
      anchors.right: parent.right
      visible: !share.last
      foreground: root.ui.fg
      strength: root.ui.ruleFaint
    }
  }
}
