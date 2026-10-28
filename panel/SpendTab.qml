import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../Format.js" as Format

// "Spend" tab: what the account has cost over four overlapping windows, then
// the one setting worth a control — the low-balance threshold.
//
// "Last 24 hours" is rolling spend from the balance payload (Service.qml), while
// "Today", "Last 7 days" and "Last 30 days" are the period figures from the
// usage loader. The rolling and calendar numbers therefore differ slightly, which
// is why the labels distinguish them.
//
// The threshold is edited here but owned by the widget: lowBalanceEdited travels
// to Panel.qml and from there to BarWidget.saveLowBalance(), because persisting a
// widget setting has to go through `omarchy bar set`.
ColumnLayout {
  id: root

  property var ui: null

  // Rolling 24 hours from the balance payload; -1 while unknown.
  property real spent24hUsd: -1
  // The shared Usage.qml loader for the other three columns.
  property var usage: null
  property real lowBalance: 3

  signal lowBalanceEdited(real value)

  // The stepper is click-driven and never takes keyboard focus, so this tab
  // never needs to block the panel's key catcher. Kept as a binding point for
  // Panel.qml's `blocked: spendTab.editing`.
  readonly property bool editing: false

  spacing: Style.space(12)

  Text {
    Layout.fillWidth: true
    text: "Spending Overview"
    color: root.ui.fg
    font.family: root.ui.fontFamily
    font.pixelSize: Style.font.title
    font.bold: true
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.space(4)

    PanelSectionHeader {
      text: "ROLLING"
      foreground: root.ui.label
    }

    MoneyRow {
      label: "Last 24 hours"
      amount: root.spent24hUsd >= 0 ? Format.money(root.spent24hUsd) : "—"
    }

    PanelSectionHeader {
      Layout.topMargin: Style.space(12)
      text: "CALENDAR"
      foreground: root.ui.label
    }

    MoneyRow {
      striped: true
      label: "Today"
      amount: root.usage && root.usage.today ? Format.money(root.usage.today.costUsd) : "—"
    }
    MoneyRow {
      label: "Last 7 days"
      amount: root.usage && root.usage.week ? Format.money(root.usage.week.costUsd) : "—"
      rate: root.usage && root.usage.week ? Format.money(root.usage.week.costUsd / 7) + "/day" : ""
    }
    MoneyRow {
      striped: true
      label: "Last 30 days"
      amount: root.usage && root.usage.month ? Format.money(root.usage.month.costUsd) : "—"
      rate: root.usage && root.usage.month ? Format.money(root.usage.month.costUsd / 30) + "/day" : ""
    }
  }

  Item {
    Layout.fillHeight: true
  }

  // ---- Low balance ---------------------------------------------------------
  PanelSeparator {
    Layout.fillWidth: true
    foreground: root.ui.fg
    strength: root.ui.ruleStrong
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.space(12)

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(2)

      Text {
        text: "Low-balance alert"
        color: root.ui.fg
        font.family: root.ui.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Text {
        Layout.fillWidth: true
        text: "Highlight the balance in the bar and panel when credit falls to or below this amount."
        color: root.ui.caption
        font.family: root.ui.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }

    StepperField {
      id: balanceField
      Layout.alignment: Qt.AlignVCenter
      ui: root.ui
      value: Math.round(root.lowBalance)
      display: Format.money(root.lowBalance)
      from: 0
      to: 1000
      stepSize: 1
      onModified: function(amount) { root.lowBalanceEdited(amount) }
    }
  }

  // One window: name, the per-day rate that makes windows comparable, then the
  // total. The faint alternating background ties a label to a figure ~300px
  // away without drawing a rule for every row.
  component MoneyRow: Rectangle {
    id: row
    property string label: ""
    property string amount: ""
    property string rate: ""
    property bool striped: false

    Layout.fillWidth: true
    implicitHeight: Style.space(24)
    color: row.striped ? root.ui.zebraWash : "transparent"

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.space(4)
      anchors.rightMargin: Style.space(4)
      spacing: Style.space(8)

      Text {
        Layout.fillWidth: true
        text: row.label
        color: root.ui.fg
        font.family: root.ui.fontFamily
        font.pixelSize: Style.font.title
      }

      Text {
        text: row.rate
        color: root.ui.label
        font.family: root.ui.fontFamily
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignRight
      }

      Text {
        Layout.minimumWidth: Style.space(72)
        text: row.amount
        color: root.ui.fg
        font.family: root.ui.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
        horizontalAlignment: Text.AlignRight
      }
    }
  }
}
