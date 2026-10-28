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
  implicitHeight: Style.space(16)

  Text {
    id: errorText
    Layout.fillWidth: true
    visible: root.error !== ""
    text: "\uF071  " + root.error
    color: root.ui.urgent
    font.family: root.ui.fontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }

  Text {
    Layout.fillWidth: true
    visible: root.error === ""
    text: root.legend
    color: root.ui.caption
    font.family: root.ui.fontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }

  Text {
    id: stamp
    visible: root.error === "" && root.fetchedAt > 0
    text: Format.relativeStamp(root.fetchedAt)
    color: root.ui.caption
    font.family: root.ui.fontFamily
    font.pixelSize: Style.font.caption

    HoverHandler { id: stampHover }
    PanelToolTip {
      visible: stampHover.hovered
      text: Format.stamp(root.fetchedAt)
    }
  }
}
