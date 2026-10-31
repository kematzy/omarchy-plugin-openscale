import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../Format.js" as Format

// One status line for every tab, pinned directly above the footer rule:
// a per-tab legend on the left, the data's age on the right, and the error
// in place of both when there is one.
RowLayout {
  id: root

  property var ui: null
  property string legend: ""
  property string error: ""
  // Epoch seconds. 0 when nothing has been fetched yet.
  property double fetchedAt: 0

  spacing: Style.space(8)
  // One line when the legend fits. The Models tab's legend carries the price
  // units note, which would otherwise elide mid-sentence next to the stamp,
  // so it wraps to a second line instead; the stamp stays centred against
  // whatever height the strip takes.
  implicitHeight: Math.max(Style.space(16), legend.implicitHeight)

  Text {
    id: errorText
    Layout.fillWidth: true
    visible: root.error !== ""
    text: "\uF071  " + root.error
    color: root.ui.urgent
    font.family: root.ui.fontFamily
    font.pixelSize: Style.font.caption
    textFormat: Text.PlainText
    elide: Text.ElideRight
  }

  Text {
    id: legend
    Layout.fillWidth: true
    visible: root.error === ""
    text: root.legend
    color: root.ui.caption
    font.family: root.ui.fontFamily
    font.pixelSize: Style.font.caption
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    maximumLineCount: 2
    elide: Text.ElideRight
  }

  Text {
    id: stamp
    visible: root.error === "" && root.fetchedAt > 0
    text: Format.relativeStamp(root.fetchedAt)
    color: root.ui.caption
    font.family: root.ui.fontFamily
    font.pixelSize: Style.font.caption
    textFormat: Text.PlainText
    // When the legend wraps to two lines the stamp reads as the header of
    // the strip, not as its middle.
    Layout.alignment: Qt.AlignTop

    HoverHandler { id: stampHover }
    PanelToolTip {
      visible: stampHover.hovered
      text: Format.stamp(root.fetchedAt)
    }
  }
}
