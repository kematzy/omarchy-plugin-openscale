import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Shown between the header and the tab strip when the balance is at or below
// the user's threshold. The panel's one job in that state is to make topping
// up a single click away, so the call to action sits with the warning rather
// than in the footer.
Rectangle {
  id: root

  property var ui: null
  // Red once the credit is exhausted, amber while it is merely low — every
  // colour below keys off this one token.
  property bool noCredit: false
  readonly property color attention: root.noCredit ? root.ui.urgent : root.ui.warning
  signal addCreditsRequested()

  implicitHeight: Style.space(32)
  color: Qt.rgba(root.attention.r, root.attention.g, root.attention.b, 0.14)

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: Style.space(8)
    anchors.rightMargin: Style.space(8)
    spacing: Style.space(8)

    Text {
      text: "\uF071"
      color: root.attention
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
      // Transparent at rest — the amber banner is already the highlight —
      // filled on hover so the click target stays obvious.
      color: ctaHover.hovered ? root.attention : "transparent"

      HoverHandler { id: ctaHover }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.addCreditsRequested()
      }

      PanelToolTip {
        visible: ctaHover.hovered
        text: "Add more credits on the OpenScale's website"
      }

      Text {
        id: cta
        anchors.centerIn: parent
        text: "ADD CREDITS"
        color: ctaHover.hovered ? root.ui.surface : root.attention
        font.family: root.ui.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 0.8
      }
    }
  }
}
