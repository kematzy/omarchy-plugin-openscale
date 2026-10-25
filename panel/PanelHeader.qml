import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons

// Panel header, shown above the tabs on every tab: the brand lockup on the
// left, the credit balance on the right with its caption beneath it.
//
// The lockup is one asset — mark and wordmark together — so the header has no
// separate wordmark text. The SVG is white-on-transparent, so it is recoloured
// here instead of being painted as-is: white would glare on a dark theme and
// disappear on a light one.
RowLayout {
  id: root

  property string creditCaption: "Remaining"
  property string creditText: "$999.99"
  // Set by the host when the credit is at or below its low-balance threshold,
  // so the threshold itself has one owner and this file stays presentational.
  property bool lowCredit: false
  property url logoSrc: Qt.resolvedUrl("../assets/openscale-logo.svg")
  // Painted height of the lockup; the width follows the asset's aspect ratio.
  property real logoHeight: Style.space(30)
  // Nudges the figure block down so the figure lines up with the lockup.
  property real balanceOffset: Style.space(4)
  property string fontFamily: Style.font.family
  property color foreground: Commons.Color.foreground
  property color urgentColor: Commons.Color.urgent

  // Intrinsic size of assets/openscale-logo.svg (213 x 47).
  readonly property real logoAspect: 213 / 47
  readonly property real logoWidth: Math.round(root.logoHeight * root.logoAspect)

  // The popup surface this header sits on. Secondary colours are mixed toward
  // it rather than given alpha: MultiEffect colorization paints an opaque
  // colour, and a blend lands on the same visual weight for light and dark
  // themes, where a fixed grey would not.
  readonly property color surfaceColor: Commons.Color.popups.background
  readonly property color logoColor: root.blend(root.foreground, root.surfaceColor, 0.22)
  readonly property color captionColor: root.blend(root.foreground, root.surfaceColor, 0.25)
  readonly property color amountColor: root.lowCredit ? root.urgentColor : root.foreground

  function blend(a, b, amount) {
    return Qt.rgba(a.r + (b.r - a.r) * amount,
                   a.g + (b.g - a.g) * amount,
                   a.b + (b.b - a.b) * amount, 1)
  }

  spacing: Style.space(9)
  implicitHeight: Math.max(root.logoHeight, balanceBox.implicitHeight)

  // Widest figure the header has to show. Reserving its width keeps the block
  // — and the caption under it — from reflowing between $0.00 and $999.99.
  TextMetrics {
    id: amountMetrics
    font: amount.font
    text: "$999.99"
  }

  Item {
    id: logoBox
    Layout.preferredWidth: root.logoWidth
    Layout.preferredHeight: root.logoHeight
    Layout.alignment: Qt.AlignVCenter

    Image {
      id: logo
      anchors.fill: parent
      source: root.logoSrc
      // 2x the painted size so the lockup stays crisp on HiDPI outputs; SVGs
      // rasterise at sourceSize.
      sourceSize.width: Math.round(root.logoWidth * 2)
      sourceSize.height: Math.round(root.logoHeight * 2)
      fillMode: Image.PreserveAspectFit
      // Kept as a hidden layer so the effect below can sample it as a texture.
      visible: false
      layer.enabled: true
    }

    MultiEffect {
      anchors.fill: parent
      source: logo
      colorization: 1.0
      colorizationColor: root.logoColor
    }
  }

  // Pushes the balance to the right edge.
  Item {
    Layout.fillWidth: true
  }

  Item {
    id: balanceBox
    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    implicitWidth: balance.implicitWidth
    implicitHeight: balance.implicitHeight

    ColumnLayout {
      id: balance
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: root.balanceOffset
      // Extra room between the figure and its caption: the caption reads as a
      // label under the figure, not as a second line of it.
      spacing: Style.space(4)

      Text {
        id: amount
        Layout.alignment: Qt.AlignRight
        // Never narrower than the widest figure. The extra width is on the
        // left: horizontalAlignment keeps the figure's own right edge on the
        // column edge, in line with the caption beneath it.
        Layout.minimumWidth: amountMetrics.advanceWidth
        horizontalAlignment: Text.AlignRight
        text: root.creditText
        color: root.amountColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.display
        font.bold: true

        Behavior on color {
          ColorAnimation { duration: 160 }
        }
      }

      Text {
        Layout.alignment: Qt.AlignRight
        horizontalAlignment: Text.AlignRight
        text: root.creditCaption
        color: root.captionColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.8
      }
    }
  }
}
