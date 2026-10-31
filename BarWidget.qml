import QtQuick
import QtQuick.Effects
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

  // ---- Zero-credit demo (hidden dev toggle) ---------------------------------
  // Forces the exhausted-credit state — $0.00, the red no-entry glyph, urgent
  // colours and the banner in red — regardless of the live balance. Exists only
  // in the source: not documented, not in the README. Toggled live through the
  // bar-settings pipeline, no restart needed:
  //   omarchy bar set io.github.kematzy.openscale demoZeroCredit true --json
  //   omarchy bar set io.github.kematzy.openscale demoZeroCredit false --json
  // The service keeps polling underneath; only what is displayed is masked,
  // and notifications are silenced so a demo never sends real ones.
  readonly property bool demoZeroCredit: setting("demoZeroCredit", false) === true

  // Real balance, read from the `osc` CLI by Service.qml below. One source for
  // the bar button, the tooltip and the panel.
  readonly property string creditText: demoZeroCredit ? "$0.00" : service.creditText
  readonly property real balanceUsd: demoZeroCredit ? 0 : service.balanceUsd
  readonly property real spent24hUsd: service.spent24hUsd

  // Low-credit threshold in dollars, from this widget's inline settings. One
  // owner here keeps the bar button, the panel header and the Spend tab from
  // disagreeing about when the figure turns urgent.
  readonly property real lowBalance: Number(setting("lowBalance", 3))

  // Traffic lights. Colour alone is not a signal — each state also changes the
  // glyph, so the bar still reads when colour does not.
  readonly property bool noCredit: balanceUsd >= 0 && balanceUsd <= 0
  readonly property bool lowCredit: balanceUsd > 0 && balanceUsd <= lowBalance

  readonly property bool balanceRefreshing: service.refreshing

  // The bar is a different surface from the popup, so this instance is seeded
  // from the bar rather than reusing the panel's.
  Theme {
    id: theme
    foregroundColor: root.bar ? root.bar.foreground : Commons.Color.foreground
    surfaceColor: root.bar ? root.bar.background : Commons.Color.background
  }

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

  // Fires once on the crossing into a low state, not on every poll. A
  // threshold the user set themselves should announce itself rather than wait
  // to be found.
  property bool notifiedLow: false

  // Both state changes funnel through here, so a poll that flips low → empty
  // still notifies exactly once, at the severity the new state deserves.
  function announceLowState() {
    // The demo override fabricates a zero balance; never announce fiction.
    if (demoZeroCredit) return
    if (!lowCredit && !noCredit) { notifiedLow = false; return }
    if (notifiedLow) return
    notifiedLow = true
    notifyProcess.command = ["notify-send", "--app-name=OpenScale",
      "--urgency=" + (noCredit ? "critical" : "normal"),
      noCredit ? "OpenScale credit exhausted" : "OpenScale credit is low",
      creditText + " remaining"]
    notifyProcess.running = true
  }

  onLowCreditChanged: announceLowState()
  onNoCreditChanged: announceLowState()

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

  // Low-balance announcement, one-shot per crossing; see announceLowState().
  Process {
    id: notifyProcess

    running: false
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
      spacing: Style.space(8)

      // The brand mark, recoloured to the bar text so it stops standing out
      // against the other widgets' icons: the asset is white-on-transparent,
      // so MultiEffect colorization paints it in one pass, the way the panel
      // header does its lockup.
      Item {
        id: mark
        // The bar's icon slot is 16px and the surrounding glyphs carry air
        // inside their em, so the mark paints a step smaller inside the same
        // slot instead of filling it edge to edge.
        readonly property real ink: Style.bar.iconCanvas - Style.space(2) * 2

        width: Style.bar.iconCanvas
        height: Style.bar.iconCanvas
        Layout.alignment: Qt.AlignVCenter

        Image {
          id: markTexture
          anchors.centerIn: parent
          width: parent.ink
          height: parent.ink
          // 2x the painted size so the mark stays crisp on HiDPI outputs.
          sourceSize.width: Math.round(parent.ink * 2)
          sourceSize.height: Math.round(parent.ink * 2)
          source: Qt.resolvedUrl("assets/openscale-logomark.svg")
          fillMode: Image.PreserveAspectFit
          // Kept as a hidden layer so the effect below can sample it as a texture.
          visible: false
          layer.enabled: true
        }

        MultiEffect {
          anchors.fill: markTexture
          source: markTexture
          colorization: 1.0
          colorizationColor: button.foreground
        }
      }

      Text {
        visible: root.noCredit || root.lowCredit
        // Warning triangle when low, no-entry when empty. Both are BMP
        // codepoints: anything above U+FFFF needs a surrogate pair and is a
        // reliable way to ship a tofu box.
        text: root.noCredit ? "\uF05E" : "\uF071"
        color: root.noCredit ? theme.urgent : theme.warning
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        text: root.creditText
        color: root.noCredit ? theme.urgent
          : (root.lowCredit ? theme.warning : button.foreground)
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
        renderType: Text.NativeRendering
        Layout.alignment: Qt.AlignVCenter
      }
    }
  }
}
