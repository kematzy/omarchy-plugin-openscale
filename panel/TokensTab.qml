import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "../Format.js" as Format

// "Tokens" tab: requests and tokens for the same three windows, each followed
// by the share of tokens each model accounted for.
//
// The bars are token share, not spend: `osc usage` reports tokens per model
// only, and inventing per-model cost from list prices would be a guess.
ColumnLayout {
  id: root

  property string fontFamily: Style.font.family
  property color foreground: Commons.Color.foreground
  property color mutedForeground: Commons.Color.muted
  property color accent: Commons.Color.accent
  property var usage: null

  readonly property var metricLabels: ["Requests", "Input", "Cached", "Output", "Total"]
  readonly property var columnWidths: [
    Style.space(68), Style.space(58), Style.space(62), Style.space(58), Style.space(58)
  ]

  spacing: Style.space(10)

  Text {
    Layout.fillWidth: true
    text: "Usage: Tokens & Models"
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.title
    font.bold: true
  }

  Flickable {
    id: view

    Layout.fillWidth: true
    Layout.fillHeight: true
    contentWidth: width
    contentHeight: sections.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    interactive: contentHeight > height

    ScrollBar.vertical: ScrollBar {
      policy: ScrollBar.AsNeeded
    }

    ColumnLayout {
      id: sections

      width: view.width
      spacing: Style.space(14)

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

  Text {
    Layout.fillWidth: true
    text: root.usage && root.usage.error !== ""
      ? root.usage.error
      : (root.usage && root.usage.fetchedAt > 0
        ? "Last updated: " + Format.stamp(root.usage.fetchedAt / 1000) : "")
    color: root.usage && root.usage.error !== "" ? Commons.Color.urgent : Util.alpha(root.foreground, 0.75)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    horizontalAlignment: Text.AlignRight
    elide: Text.ElideRight
  }

  // One window: title, the five figures, then a bar per model.
  component Section: ColumnLayout {
    id: section
    property string title: ""
    property var window: null

    readonly property var figures: {
      var w = section.window
      if (!w) return ["—", "—", "—", "—", "—"]
      return [
        Format.count(w.requests), Format.count(w.input), Format.count(w.cached),
        Format.count(w.output), Format.count(w.total)
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
          ratio: tokens / w.total
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
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.subtitle
      font.bold: true
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Repeater {
        model: root.metricLabels.length

        Text {
          required property int index

          Layout.fillWidth: true
          Layout.preferredWidth: root.columnWidths[index]
          text: root.metricLabels[index]
          color: root.mutedForeground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.capitalization: Font.AllUppercase
          font.letterSpacing: 0.6
          horizontalAlignment: Text.AlignRight
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Repeater {
        model: section.figures.length

        Text {
          required property int index

          Layout.fillWidth: true
          Layout.preferredWidth: root.columnWidths[index]
          text: section.figures[index]
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignRight
        }
      }
    }

    Text {
      Layout.fillWidth: true
      Layout.topMargin: Style.space(2)
      text: "Models used: " + (section.window && section.window.models ? section.window.models.length : 0)
      color: root.mutedForeground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Repeater {
      model: section.modelShares

      delegate: ModelShare {
        required property var modelData

        label: modelData.model
        ratio: modelData.ratio
      }
    }
  }

  // Name inside the bar on the left, share on the right, fill proportional to
  // that model's tokens.
  component ModelShare: Item {
    id: share
    property string label: ""
    property real ratio: 0

    Layout.fillWidth: true
    implicitHeight: Math.max(nameText.implicitHeight, percentText.implicitHeight) + Style.space(6)

    Rectangle {
      anchors.fill: parent
      color: Util.alpha(root.foreground, 0.07)
    }

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: parent.width * Math.max(0, Math.min(1, share.ratio))
      color: Util.alpha(root.accent, 0.28)
    }

    Text {
      id: nameText
      anchors.left: parent.left
      anchors.leftMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(0, parent.width - percentText.implicitWidth - Style.space(20))
      text: share.label
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideMiddle
    }

    Text {
      id: percentText
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      text: Format.percent(share.ratio)
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }
}
