import QtQuick
import QtQuick.Controls
import qs.Commons

// One tab in the panel's TabBar.
//
// Extends QtQuick.Controls' TabButton so selection stays driven by the parent
// TabBar (`checked` comes from the attached TabBar.index), and replaces the
// default style's chrome with theme tokens: a faint wash on hover, an accent
// underline on the selected tab, nothing otherwise.
TabButton {
  id: root

  property var ui: null
  // Spins a refresh glyph at the tab's leading edge while that tab's data is
  // loading. Panel.qml binds it to the usage loader for Spend and Tokens, and
  // to the catalogue's own loading flag for Models.
  property bool busy: false
  // Numeral shown in the tab's top-right corner; 0 hides it.
  property int shortcut: 0

  // Square tabs, not pills: no radius on any state, by preference.
  // Fixed height so the strip is one band; the width has a floor of 84 so a
  // short label still gives a comfortable target, and grows with a longer one.
  // The TabBar shares the panel width between the tabs.
  implicitHeight: Style.space(32)
  implicitWidth: Math.max(Style.space(84), label.implicitWidth + Style.space(24))

  HoverHandler {
    id: hover
  }

  background: Rectangle {
    color: hover.hovered && !root.checked ? root.ui.hoverWash : "transparent"

    // Active-tab marker. Echoes the bar's own open-widget indicator, so the
    // panel points back at the control that opened it.
    Rectangle {
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      height: Style.space(2)
      visible: root.checked
      color: root.ui.accent
    }
  }

  contentItem: Item {
    // The spinner is pinned to the leading edge, so the label stays exactly
    // centred whether or not it is there.
    Text {
      id: spinner
      anchors.left: parent.left
      // A few pixels in from the tab's leading edge, so the glyph is not
      // flush against the tab it belongs to.
      anchors.leftMargin: Style.space(2)
      anchors.verticalCenter: parent.verticalCenter
      visible: root.busy
      text: "\uF021"
      textFormat: Text.PlainText
      color: root.ui.label
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.bodySmall

      RotationAnimation on rotation {
        running: root.busy
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: 900
        onRunningChanged: if (!running) spinner.rotation = 0
      }
    }

    Text {
      id: label
      anchors.centerIn: parent
      text: root.text
      color: root.checked ? root.ui.accent : root.ui.label
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.capitalization: Font.AllUppercase
      font.letterSpacing: 0.6
      font.bold: root.checked
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }

    // The 1/2/3 shortcuts work whether or not this is shown; the numeral is
    // the only thing that says so.
    Text {
      anchors.right: parent.right
      anchors.rightMargin: Style.space(4)
      anchors.top: parent.top
      anchors.topMargin: Style.space(4)
      visible: root.shortcut > 0
      text: String(root.shortcut)
      color: root.ui.decor
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
