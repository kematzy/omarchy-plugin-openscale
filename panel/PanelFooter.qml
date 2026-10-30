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
    { icon: "\uF067", label: "Credits", url: "https://app.openscale.so/app?credits=open", isPrimary: true,
      tooltip: "Add more credits on the OpenScale's website" },
    { icon: "\ueacd", label: "Dashboard", url: "https://app.openscale.so/app",
      tooltip: "Open your OpenScale dashboard" },
    { icon: "\uF02D", label: "Docs", url: "https://openscale.so/docs",
      tooltip: "Open the OpenScale documentation" }
  ]

  property var ui: null
  // When true, the primary link (Credits) is promoted to a filled button —
  // the same moment the low-balance banner appears above the tabs.
  property bool lowCredit: false

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
        // Only promoted when the balance is low; the rest of the time every
        // button looks the same.
        readonly property bool promoted: root.lowCredit && link.modelData.isPrimary === true

        // Keyboard-reachable: Tab lands on the button, Enter/Return clicks it.
        activeFocusOnTab: true

        // One activation path for mouse and keyboard, so Enter behaves
        // exactly like a click.
        function activate() {
          Util.execArgv(["xdg-open", link.modelData.url])
        }

        Keys.onReturnPressed: link.activate()
        Keys.onEnterPressed: link.activate()

        Accessible.role: Accessible.Button
        Accessible.name: modelData.label + ", opens in browser"

        Layout.fillWidth: true
        implicitHeight: Style.space(32)
        // Square buttons, no radius, matching the tab strip.
        color: link.promoted
          ? (hover.hovered ? root.ui.accent : root.ui.accentWash)
          : (hover.hovered ? root.ui.hoverWash : "transparent")

        HoverHandler {
          id: hover
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          // execArgv keeps the URL a literal argv entry (no shell re-parsing).
          onClicked: link.activate()
        }

        // Keyboard focus ring, matching the tabs'.
        Rectangle {
          anchors.fill: parent
          visible: link.activeFocus
          color: "transparent"
          border.width: 1
          border.color: root.ui.accent
        }

        RowLayout {
          anchors.centerIn: parent
          spacing: Style.space(8)

          Text {
            text: link.modelData.icon
            color: link.promoted && hover.hovered ? root.ui.surface
              : (link.promoted || hover.hovered ? root.ui.accent : root.ui.fg)
            font.family: root.ui.fontFamily
            font.pixelSize: Style.font.bodySmall
            Layout.alignment: Qt.AlignVCenter
          }

          Text {
            text: link.modelData.label
            color: link.promoted && hover.hovered ? root.ui.surface
              : (link.promoted || hover.hovered ? root.ui.accent : root.ui.fg)
            font.family: root.ui.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.6
            Layout.alignment: Qt.AlignVCenter
          }

          Text {
            text: "\u2197"
            color: root.ui.decor
            font.family: root.ui.fontFamily
            font.pixelSize: Style.font.caption
            Layout.alignment: Qt.AlignVCenter
          }
        }

        PanelToolTip {
          visible: hover.hovered
          text: link.modelData.tooltip
        }
      }
    }
  }
}
