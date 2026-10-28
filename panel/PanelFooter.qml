import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Panel footer, shown below the tabs on every tab: a full-width rule closing
// the panel body, then three shortcut buttons that open the matching page on
// openscale.so.
//
// A layout rather than a row, because the rule has to span the panel width while
// the buttons sit in their own row below it.
ColumnLayout {
  id: root

  // { icon, label, url } — icon is a Nerd Font glyph, so it renders in the
  // same monospace family as everything else in the shell.
  property var links: [
    // The route `osc claim` opens: the app's own Add Credits dialog, rather
    // than the marketing site's /credits redirect through the login page.
    { icon: "\uF067", label: "Credits", url: "https://app.openscale.so/app?credits=open" },
    { icon: "\uF120", label: "Console", url: "https://app.openscale.so/app" },
    { icon: "\uF02D", label: "Docs", url: "https://openscale.so/docs" }
  ]

  property var ui: null

  spacing: Style.space(8)

  PanelSeparator {
    Layout.fillWidth: true
    foreground: root.ui.fg
    strength: root.ui.ruleStrong
  }

  RowLayout {
    id: buttons

    Layout.fillWidth: true
    spacing: Style.space(8)
    implicitHeight: Style.space(34)

    Repeater {
      model: root.links

      delegate: Rectangle {
        id: link
        required property var modelData

        Layout.fillWidth: true
        implicitHeight: Style.space(32)
        // Square buttons, no radius, matching the tab strip.
        color: hover.hovered ? root.ui.accentWash : "transparent"

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
          spacing: Style.space(8)

          Text {
            text: link.modelData.icon
            color: hover.hovered ? root.ui.accent : root.ui.fg
            font.family: root.ui.fontFamily
            font.pixelSize: Style.font.bodySmall
            Layout.alignment: Qt.AlignVCenter
          }

          Text {
            text: link.modelData.label
            color: hover.hovered ? root.ui.accent : root.ui.fg
            font.family: root.ui.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.6
            Layout.alignment: Qt.AlignVCenter
          }
        }
      }
    }
  }
}
