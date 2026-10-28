import QtQuick
import QtQuick.Controls
import qs.Commons

// One tab in the panel's TabBar.
//
// Extends QtQuick.Controls' TabButton so selection stays driven by the parent
// TabBar (`checked` comes from the attached TabBar.index), and replaces the
// default style's chrome with theme tokens: a faint wash on hover, a deeper
// wash of the same colour when selected, nothing otherwise.
TabButton {
  id: root

  property var ui: null
  // Spins a refresh glyph at the tab's leading edge while that tab's data is
  // loading. Panel.qml binds it to the usage loader for Spend and Tokens, and
  // to the catalogue's own loading flag for Models.
  property bool busy: false

  // Square tabs, not pills: no radius on any state, by preference.
  readonly property color hoverColor: root.ui.hoverWash
  // Selected is the same foreground wash as hover, only deeper, so the active
  // tab reads as "the one you are on" rather than as a differently coloured
  // control. The accent stays on the label.
  readonly property color activeColor: root.ui.accentWash

  // Fixed height so the strip is one band; the width has a floor of 84 so a
  // short label still gives a comfortable target, and grows with a longer one.
  // The TabBar shares the panel width between the tabs.
  implicitHeight: Style.space(32)
  implicitWidth: Math.max(Style.space(84), label.implicitWidth + Style.space(24))

  HoverHandler {
    id: hover
  }

  background: Rectangle {
    color: root.checked
      ? root.activeColor
      : (hover.hovered ? root.hoverColor : "transparent")
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
      color: root.checked ? root.ui.accent : root.ui.fg
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.capitalization: Font.AllUppercase
      font.letterSpacing: 0.6
      font.bold: root.checked
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }
  }
}
