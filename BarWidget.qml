import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar button + host for the OpenScale panel.
//
// The manifest loads this file; it in turn loads Panel.qml and forwards the
// panel lifecycle (open/close/toggle) that the bar and `omarchy-shell shell
// summon` route through. That split is the documented shape for a bar widget
// with a popup: one plugin, one kind ("bar-widget"), no separate panel kind.
//
// It owns the two data loaders — Service (balance) and Usage (the three usage
// windows) — and therefore the only shared state in the plugin; the panel and
// its tabs are presentational. It also owns the one write path: saving the
// low-balance threshold, which goes out through `omarchy bar set` because a bar
// widget is injected only bar, moduleName and settings.
BarWidget {
  id: root
  moduleName: "io.github.kematzy.openscale"

  // Real balance, read from the `osc` CLI by Service.qml below. One source for
  // the bar button, the tooltip and the panel.
  readonly property string creditText: service.creditText
  readonly property real balanceUsd: service.balanceUsd
  readonly property real spent24hUsd: service.spent24hUsd

  // Low-credit threshold in dollars, from this widget's inline settings. One
  // owner here keeps the bar button, the panel header and the Spend tab from
  // disagreeing about when the figure turns urgent.
  readonly property real lowBalance: Number(setting("lowBalance", 3))
  readonly property bool lowCredit: balanceUsd >= 0 && balanceUsd <= lowBalance
  readonly property bool balanceRefreshing: service.refreshing

  // Called by Panel.qml when the popup opens: fetches the balance unless the
  // last good one is still fresh, so repeated open/close does not poll.
  function refreshOnOpen() {
    service.refreshIfStale()
  }

  // A widget gets only bar/moduleName/settings injected, so there is no shell
  // API to call. `omarchy bar set` is the documented entry point for a widget
  // setting: it routes to shell.setBarWidget and rewrites this widget's inline
  // entry, and the new value comes straight back through `settings`.
  function saveLowBalance(value) {
    var amount = Math.max(0, Math.round(Number(value) || 0))
    if (saveProcess.running) return
    saveProcess.command = ["omarchy", "bar", "set", root.moduleName, "lowBalance",
      String(amount), "--json"]
    saveProcess.running = true
  }

  // ---- Panel lifecycle contract -------------------------------------------
  // Bar.findPanelWidget expects open/close/opened on this root, and the popout
  // coordinator compares against it for the open-panel indicator.

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  // Forwarded so this widget can stand in for the panel as the bar's popout
  // identity: Bar.requestPopout prefers closeForPopoutSwitch over close.
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  // The panel is a separate item, so everything it needs from the host is
  // handed over explicitly rather than inherited.
  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("usage" in target) target.usage = usage
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Service {
    id: service
    // Interval comes from this widget's inline shell.json entry, so changing
    // the setting takes effect without touching the code.
    settings: root.settings
  }

  // One usage loader for both usage tabs, so switching between them does not
  // refetch the three windows.
  Usage {
    id: usage
  }

  Process {
    id: saveProcess

    running: false
    onExited: function(exitCode) {
      // Nothing to read back: the saved value arrives as a settings change.
      if (exitCode !== 0) console.warn("openscale: could not save lowBalance, exit " + exitCode)
    }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false

    onLoaded: {
      root.injectPanel()
      // The bar may not have injected `bar` yet on the first pass.
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // The label is off because WidgetButton can only draw text centred on its
    // own; the brand mark and the amount are composed here instead, and
    // `fixedWidth` lets the button size itself to that row.
    text: root.creditText
    labelVisible: false
    fixedWidth: content.implicitWidth + button.scaledHorizontalMargin * 2
    // Drives the label colour through WidgetButton's own urgent affordance.
    active: root.lowCredit
    tooltipText: service.error !== "" ? "OpenScale — " + service.error
      : "OpenScale — spending, usage and models"
    horizontalMargin: 9
    verticalPadding: 8

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.togglePanel()
    }

    RowLayout {
      id: content
      anchors.centerIn: parent
      spacing: Style.space(5)

      Image {
        source: Qt.resolvedUrl("assets/openscale.svg")
        // 2x the painted size so the mark stays crisp on HiDPI outputs.
        sourceSize.width: Math.round(Style.space(14) * 2)
        sourceSize.height: Math.round(Style.space(14) * 2)
        fillMode: Image.PreserveAspectFit
        Layout.preferredWidth: Style.space(14)
        Layout.preferredHeight: Style.space(14)
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        text: root.creditText
        color: button.active ? button.activeColor : button.foreground
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
        renderType: Text.NativeRendering
        Layout.alignment: Qt.AlignVCenter
      }
    }
  }
}
