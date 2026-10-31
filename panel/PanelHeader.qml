import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Panel header, shown above the tabs on every tab: the brand lockup on the
// left, the credit balance on the right with its caption beneath it.
//
// The lockup is one asset — mark and wordmark together — so the header has no
// separate wordmark text. The SVG is white-on-transparent, so it is recoloured
// here instead of being painted as-is: white would glare on a dark theme and
// disappear on a light one.
//
// The lockup is also a link to openscale.so: it is the one "where does this come
// from" affordance in the panel, and it brightens on hover so it reads as one.
RowLayout {
  id: root

  property string creditCaption: "Remaining"
  property string creditText: "$999.99"
  // Set by the host when the credit is at or below its low-balance threshold,
  // so the threshold itself has one owner and this file stays presentational.
  property bool lowCredit: false
  // One shade further than low: the credit is exhausted (zero).
  property bool noCredit: false
  // Set by the host while a balance fetch is in flight.
  property bool busy: false
  // The fetch takes ~300 ms, which is over before the eye registers the
  // rotation, so the spinner would read as a rendering artefact. Holding it for
  // half a second after the figure lands makes the refresh legible.
  readonly property bool spinning: busy || spinnerTail.running

  property url logoSrc: Qt.resolvedUrl("../assets/openscale-logo-full.svg")
  // Painted height of the lockup; the width follows the asset's aspect ratio.
  property real logoHeight: Style.space(26)

  property var ui: null

  // Average daily spend over the last 7 days, and the resulting runway. Both
  // -1 when the usage loader has not answered yet.
  property real dailyRateUsd: -1
  property real balanceUsd: -1

  // Intrinsic size of assets/openscale-logo-full.svg (650 x 103).
  readonly property real logoAspect: 650 / 103
  readonly property real logoWidth: Math.round(root.logoHeight * root.logoAspect)

  readonly property color amountColor: root.noCredit
    ? root.ui.urgent : (root.lowCredit ? root.ui.warning : root.ui.fg)

  // "~14 days left · $0.73/day (7-day average)". Empty when there is not
  // enough data to say anything true.
  readonly property string runwayText: {
    if (root.dailyRateUsd <= 0 || root.balanceUsd < 0) return ""
    var days = Math.floor(root.balanceUsd / root.dailyRateUsd)
    return "~" + days + (days === 1 ? " day" : " days") + " left · $"
      + root.dailyRateUsd.toFixed(2) + "/day (7-day average)"
  }

  spacing: Style.space(8)
  implicitHeight: Math.max(logoColumn.implicitHeight, balanceBox.implicitHeight)

  onBusyChanged: {
    if (busy) spinnerTail.stop()
    else spinnerTail.restart()
  }

  // Trailing spin, timed from the moment `busy` clears.
  Timer {
    id: spinnerTail
    interval: 500
    repeat: false
  }

  // Widest figure the header has to show. Reserving its width keeps the block
  // — and the caption under it — from reflowing between $0.00 and $999.99.
  TextMetrics {
    id: amountMetrics
    font: amount.font
    text: "$999.99"
  }

  // The lockup and its URL line, wrapped so both read as one link: one hover
  // handler and one click target cover the whole column. The host is a plain
  // Item — a ColumnLayout would manage an anchored overlay child, which is
  // undefined behaviour — and the ColumnLayout inside stacks the two lines.
  Item {
    id: logoColumn
    Layout.alignment: Qt.AlignTop
    // Breathing room above the lockup, mirrored on the balance column, so
    // the header does not sit flush against the popup's top edge.
    Layout.topMargin: Style.space(8)
    implicitWidth: logoContent.implicitWidth
    implicitHeight: logoContent.implicitHeight

    ColumnLayout {
      id: logoContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: Style.space(4)

      Item {
        id: logoBox
        // Optical baseline nudge: the amount's ink starts a few pixels inside
        // its text box, while the mark's ink starts at its own box edge — this
        // brings the two inks level, and the URL line level with REMAINING.
        Layout.topMargin: Style.space(4)
        Layout.preferredWidth: root.logoWidth
        Layout.preferredHeight: root.logoHeight

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
          // Hover brings the lockup up to the figure's colour, so it reads as a link.
          colorizationColor: logoHover.hovered ? root.ui.fg : root.ui.decor
        }
      }

      RowLayout {
        spacing: Style.space(4)

        Text {
          text: "https://openscale.so"
          color: logoHover.hovered ? root.ui.accent : root.ui.caption
          font.family: root.ui.fontFamily
          font.pixelSize: Style.font.caption
        }

        // Appears on hover: says the click leaves the desktop for a browser.
        Text {
          visible: logoHover.hovered
          text: "\u2197"
          color: root.ui.accent
          font.family: root.ui.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }

    HoverHandler {
      id: logoHover
    }

    // Left click only, so a stray right or middle click does not open a browser.
    // execArgv keeps the URL a literal argv entry: no shell re-parsing. A
    // sibling of the column rather than a child of it: the whole block is one
    // click target, and a plain-Item parent makes the anchor legal.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      cursorShape: Qt.PointingHandCursor
      onClicked: Util.execArgv(["xdg-open", "https://openscale.so"])
    }

    PanelToolTip {
      visible: logoHover.hovered
      text: "Open the OpenScale website in your default browser"
    }
  }

  // Pushes the balance to the right edge.
  Item {
    Layout.fillWidth: true
  }

  Item {
    id: balanceBox
    Layout.alignment: Qt.AlignRight | Qt.AlignTop
    Layout.topMargin: Style.space(8)
    implicitWidth: balance.implicitWidth
    implicitHeight: balance.implicitHeight

    ColumnLayout {
      id: balance
      anchors.right: parent.right
      anchors.top: parent.top
      // Extra room between the figure and its caption: the caption reads as a
      // label under the figure, not as a second line of it.
      spacing: Style.space(4)

      RowLayout {
        Layout.alignment: Qt.AlignRight
        spacing: Style.space(8)

        // Spinner sits in its own text field ahead of the figure, and only
        // while a fetch is in flight. A hidden layout item takes no space, so
        // the figure's right edge stays pinned while it appears and goes.
        Text {
          id: spinner
          Layout.alignment: Qt.AlignVCenter
          visible: root.spinning
          text: "\uF021"
          textFormat: Text.PlainText
          color: root.ui.label
          font.family: root.ui.fontFamily
          font.pixelSize: Style.font.title

          RotationAnimation on rotation {
            running: root.spinning
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 900
            onRunningChanged: if (!running) spinner.rotation = 0
          }
        }

        Text {
          id: amount
          Layout.alignment: Qt.AlignVCenter
          // Never narrower than the widest figure. The extra width is on the
          // left: horizontalAlignment keeps the figure's own right edge on the
          // column edge, in line with the caption beneath it.
          Layout.minimumWidth: amountMetrics.advanceWidth
          horizontalAlignment: Text.AlignRight
          text: root.creditText
          color: root.amountColor
          font.family: root.ui.fontFamily
          font.pixelSize: Style.font.display
          font.bold: true
          textFormat: Text.PlainText

          Accessible.role: Accessible.StaticText
          Accessible.name: root.creditText + " remaining"

          Behavior on color {
            ColorAnimation { duration: 160 }
          }

          HoverHandler { id: amountHover }

          PanelToolTip {
            visible: amountHover.hovered && root.runwayText !== ""
            text: root.runwayText
          }
        }
      }

      Text {
        Layout.alignment: Qt.AlignRight
        horizontalAlignment: Text.AlignRight
        text: root.creditCaption
        color: root.ui.caption
        font.family: root.ui.fontFamily
        font.pixelSize: Style.font.caption
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.8
      }
    }
  }
}
