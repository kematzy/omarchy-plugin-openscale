import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons

// Panel footer, shown below the tabs on every tab: three shortcut buttons that
// open the matching page on openscale.so.
RowLayout {
  id: root

  // { icon, label, url } — icon is a Nerd Font glyph, so it renders in the
  // same monospace family as everything else in the shell.
  property var links: [
    { icon: "\uF09D", label: "Credits", url: "https://openscale.so/credits" },
    { icon: "\uF120", label: "Console", url: "https://openscale.so/login" },
    { icon: "\uF02D", label: "Docs", url: "https://openscale.so/docs" }
  ]

  property string fontFamily: Style.font.family
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent

  spacing: Style.space(6)
  implicitHeight: Style.space(34)

  Repeater {
    model: root.links

    delegate: Rectangle {
      id: link
      required property var modelData

      Layout.fillWidth: true
      implicitHeight: Style.space(32)
      radius: Style.cornerRadius
      color: hover.hovered ? Util.alpha(root.accent, 0.12) : "transparent"

      HoverHandler {
        id: hover
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // execArgv keeps the URL a literal argv entry (no shell re-parsing).
        onClicked: Util.execArgv(["xdg-open", link.modelData.url])
      }

      RowLayout {
        anchors.centerIn: parent
        spacing: Style.space(7)

        Text {
          text: link.modelData.icon
          color: hover.hovered ? root.accent : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          Layout.alignment: Qt.AlignVCenter
        }

        Text {
          text: link.modelData.label
          color: hover.hovered ? root.accent : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.capitalization: Font.AllUppercase
          font.letterSpacing: 0.6
          Layout.alignment: Qt.AlignVCenter
        }
      }
    }
  }
}
