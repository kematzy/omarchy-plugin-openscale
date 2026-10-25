import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons

// Panel header, shown above the tabs on every tab: brand mark on the left,
// credit balance on the right.
RowLayout {
  id: root

  property string label: "OpenScale"
  property string creditCaption: "credit"
  property string creditText: "$0.00"
  property url logoSrc: Qt.resolvedUrl("../assets/openscale.svg")
  property string fontFamily: Style.font.family
  property color foreground: Commons.Color.foreground
  property color mutedForeground: Commons.Color.muted

  spacing: Style.space(9)
  implicitHeight: Math.max(logo.implicitHeight, credit.implicitHeight)

  Image {
    id: logo
    source: root.logoSrc
    // 2x the painted size so the mark stays crisp on HiDPI outputs; SVGs
    // rasterise at sourceSize.
    sourceSize.width: Math.round(Style.space(24) * 2)
    sourceSize.height: Math.round(Style.space(24) * 2)
    fillMode: Image.PreserveAspectFit
    Layout.preferredWidth: Style.space(24)
    Layout.preferredHeight: Style.space(24)
    Layout.alignment: Qt.AlignVCenter
  }

  Text {
    text: root.label
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.subtitle
    font.bold: true
    Layout.alignment: Qt.AlignVCenter
  }

  // Pushes the balance to the right edge.
  Item {
    Layout.fillWidth: true
  }

  Text {
    text: root.creditCaption
    color: root.mutedForeground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 0.6
    Layout.alignment: Qt.AlignBaseline
  }

  Text {
    id: credit
    text: root.creditText
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.title
    font.bold: true
    Layout.alignment: Qt.AlignBaseline
  }
}
