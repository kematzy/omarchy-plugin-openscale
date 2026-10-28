import QtQuick
import QtQuick.Layouts
import qs.Commons

// Shown between the header and the tab strip when the balance is at or below
// the user's threshold. The panel's one job in that state is to make topping
// up a single click away, so the call to action sits with the warning rather
// than in the footer.
Rectangle {
  id: root

  property var ui: null
  signal addCreditsRequested()

  implicitHeight: Style.space(32)
  color: Qt.rgba(root.ui.warning.r, root.ui.warning.g, root.ui.warning.b, 0.14)

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Style.space(8)
    anchors.rightMargin: Style.space(8)
    spacing: Style.space(8)

    Text {
      text: "\uF071"
      color: root.ui.warning
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Text {
      Layout.fillWidth: true
      text: "Time to top up?"
      color: root.ui.fg
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Rectangle {
      implicitWidth: cta.implicitWidth + Style.space(16)
      implicitHeight: Style.space(24)
      color: ctaHover.hovered
        ? root.ui.warning
        : Qt.rgba(root.ui.warning.r, root.ui.warning.g, root.ui.warning.b, 0.25)

      HoverHandler { id: ctaHover }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.addCreditsRequested()
      }

      Text {
        id: cta
        anchors.centerIn: parent
        text: "ADD CREDITS"
        color: ctaHover.hovered ? root.ui.surface : root.ui.warning
        font.family: root.ui.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 0.8
      }
    }
  }
}
