import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../Format.js" as Format

// "Spend" tab: what the account has cost over four overlapping windows, then
// the one setting worth a control — the low-balance threshold.
//
// "Last 24 hours" is rolling spend from the balance payload (Service.qml), while
// "Today only", "Last 7 days" and "Last 30 days" are the period figures from the
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

  // True while the threshold field has the keyboard. Panel.qml blocks its key
  // catcher on this so arrows and digits reach the editor instead of changing
  // tabs; the Escape handler below hands focus back so the panel can close.
  readonly property bool editing: balanceField.field.activeFocus

  Keys.onEscapePressed: if (editing) balanceField.field.focus = false

  spacing: Style.space(12)

  Text {
    Layout.fillWidth: true
    text: "Spending Overview (USD)"
    color: root.ui.fg
    font.family: root.ui.fontFamily
    font.pixelSize: Style.font.title
    font.bold: true
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.space(8)

    MoneyRow {
      label: "Last 24 hours"
      amount: root.spent24hUsd >= 0 ? Format.money(root.spent24hUsd) : "—"
    }
    MoneyRow {
      label: "Today only"
      amount: root.usage && root.usage.today ? Format.money(root.usage.today.costUsd) : "—"
    }
    MoneyRow {
      label: "Last 7 days"
      amount: root.usage && root.usage.week ? Format.money(root.usage.week.costUsd) : "—"
    }
    MoneyRow {
      label: "Last 30 days"
      amount: root.usage && root.usage.month ? Format.money(root.usage.month.costUsd) : "—"
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
        text: "Highlight the balance in the bar and panel header when it falls to or below this amount."
        color: root.ui.caption
        font.family: root.ui.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }

    NumberField {
      id: balanceField
      Layout.alignment: Qt.AlignVCenter
      value: Math.round(root.lowBalance)
      from: 0
      to: 1000
      stepSize: 1
      foreground: root.ui.fg
      accent: root.ui.accent
      fontFamily: root.ui.fontFamily
      onModified: function(value) { root.lowBalanceEdited(value) }
    }
  }

  Text {
    Layout.fillWidth: true
    text: root.usage && root.usage.error !== ""
      ? root.usage.error
      : (root.usage && root.usage.fetchedAt > 0
        ? "Last updated: " + Format.stamp(root.usage.fetchedAt / 1000) : "")
    color: root.usage && root.usage.error !== "" ? root.ui.urgent : root.ui.caption
    font.family: root.ui.fontFamily
    font.pixelSize: Style.font.caption
    horizontalAlignment: Text.AlignRight
    elide: Text.ElideRight
  }

  // One window: name at the same size as a model name in the Models tab, the
  // figure bold and pinned to the right edge.
  component MoneyRow: RowLayout {
    id: row
    property string label: ""
    property string amount: ""

    Layout.fillWidth: true
    spacing: Style.space(8)

    Text {
      Layout.fillWidth: true
      text: row.label
      color: root.ui.fg
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.title
    }

    Text {
      text: row.amount
      color: root.ui.fg
      font.family: root.ui.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
      horizontalAlignment: Text.AlignRight
      Layout.alignment: Qt.AlignRight
    }
  }
}
