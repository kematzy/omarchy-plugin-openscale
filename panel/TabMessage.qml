import QtQuick
import QtQuick.Layouts
import qs.Commons

// Fills a tab body when there is nothing to show. A blocking failure used to
// land in a 10px footnote, where the one message with an actual fix in it —
// "run osc login" — was the least likely thing on screen to be read.
ColumnLayout {
  id: root

  property var ui: null
  property string glyph: ""
  property string title: ""
  property string detail: ""
  property string actionLabel: ""
  signal actionTriggered()

  spacing: Style.space(8)

  Item { Layout.fillHeight: true }

  Text {
    Layout.alignment: Qt.AlignHCenter
    visible: root.glyph !== ""
    text: root.glyph
    color: root.ui.label
    font.family: root.ui.fontFamily
    font.pixelSize: Style.font.display
  }

  Text {
    Layout.alignment: Qt.AlignHCenter
    text: root.title
    color: root.ui.fg
    font.family: root.ui.fontFamily
    font.pixelSize: Style.font.title
    font.bold: true
  }

  Text {
    Layout.fillWidth: true
    visible: root.detail !== ""
    text: root.detail
    color: root.ui.caption
    font.family: root.ui.fontFamily
    font.pixelSize: Style.font.bodySmall
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
  }

  Rectangle {
    Layout.alignment: Qt.AlignHCenter
    Layout.topMargin: Style.space(8)
    visible: root.actionLabel !== ""
    implicitWidth: actionText.implicitWidth + Style.space(24)
    implicitHeight: Style.space(28)
    color: actionHover.hovered ? root.ui.accent : root.ui.accentWash

    HoverHandler { id: actionHover }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.actionTriggered()
    }

    Text {
      id: actionText
      anchors.centerIn: parent
      text: root.actionLabel
      color: actionHover.hovered ? root.ui.surface : root.ui.accent
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }
  }

  Item { Layout.fillHeight: true }
}
