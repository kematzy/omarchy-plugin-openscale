import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons

// Placeholder for the "Models" tab — structure only, contents to be designed.
ColumnLayout {
  id: root

  property string fontFamily: Style.font.family
  property color foreground: Commons.Color.foreground
  property color mutedForeground: Commons.Color.muted

  spacing: Style.space(6)

  Text {
    Layout.fillWidth: true
    text: "Models"
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.title
    font.bold: true
  }

  Text {
    Layout.fillWidth: true
    text: "The model list, prices and context windows land here."
    color: root.mutedForeground
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    wrapMode: Text.WordWrap
  }

  // Absorbs the leftover height so the placeholder sits at the top of the
  // main area instead of stretching with it.
  Item {
    Layout.fillHeight: true
  }
}
