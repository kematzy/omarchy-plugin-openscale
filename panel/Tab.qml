import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons

// One tab in the panel's TabBar.
//
// Extends QtQuick.Controls' TabButton so selection stays driven by the parent
// TabBar (`checked` comes from the attached TabBar.index), and replaces the
// default style's chrome with theme tokens: an accent-tinted pill when
// selected, a faint wash on hover, nothing otherwise.
TabButton {
  id: root

  property string fontFamily: Style.font.family
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent

  implicitHeight: Style.space(32)
  implicitWidth: Math.max(Style.space(84), label.implicitWidth + Style.space(24))

  HoverHandler {
    id: hover
  }

  background: Rectangle {
    radius: Style.cornerRadius
    color: root.checked
      ? Util.alpha(root.accent, 0.18)
      : (hover.hovered ? Util.alpha(root.foreground, 0.06) : "transparent")
  }

  contentItem: Text {
    id: label
    text: root.text
    color: root.checked ? root.accent : root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 0.8
    font.bold: root.checked
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
  }
}
