import QtQuick
import QtQuick.Layouts
import qs.Commons

// Square − / + stepper. Replaces qs.Ui's NumberField, whose rounded pill and
// ~6px arrows are the only such shapes and targets in this panel.
RowLayout {
  id: root

  property var ui: null
  property real value: 0
  property real from: 0
  property real to: 1000
  property real stepSize: 1
  // Rendered form of `value`, supplied by the caller so this file stays free
  // of currency assumptions.
  property string display: String(root.value)

  signal modified(real value)

  spacing: 0

  component StepButton: Rectangle {
    id: btn
    property string glyph: ""
    property bool enabledStep: true
    signal activated()

    implicitWidth: Style.space(28)
    implicitHeight: Style.space(28)
    color: btnHover.hovered && btn.enabledStep ? root.ui.hoverWash : "transparent"
    opacity: btn.enabledStep ? 1 : 0.4

    HoverHandler { id: btnHover }
    MouseArea {
      anchors.fill: parent
      enabled: btn.enabledStep
      cursorShape: Qt.PointingHandCursor
      onClicked: btn.activated()
    }

    Text {
      anchors.centerIn: parent
      text: btn.glyph
      color: btnHover.hovered && btn.enabledStep ? root.ui.accent : root.ui.fg
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.title
    }
  }

  StepButton {
    glyph: "\u2212"
    enabledStep: root.value > root.from
    onActivated: root.modified(Math.max(root.from, root.value - root.stepSize))
  }

  Text {
    Layout.minimumWidth: Style.space(56)
    text: root.display
    color: root.ui.fg
    font.family: root.ui.fontFamily
    font.pixelSize: Style.font.title
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  StepButton {
    glyph: "+"
    enabledStep: root.value < root.to
    onActivated: root.modified(Math.min(root.to, root.value + root.stepSize))
  }
}
