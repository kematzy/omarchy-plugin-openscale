import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "panel"

// The OpenScale popup: header, tabs, main area, footer.
//
// Composition only. `Panel` (qs.Ui) owns the open/close state; `KeyboardPanel`
// anchors a layer-shell card to the bar button and handles outside-click
// dismissal; `PanelKeyCatcher` gives us Escape, Tab (switch to the neighbouring
// panel) and the arrow keys.
//
// This file is also where the panel's three cross-cutting decisions live:
//
//   * tab order — Spend 0, Tokens 1, Models 2, mirrored by the StackLayout and
//     by the 1/2/3 shortcuts;
//   * what refreshing means — opening the popup refreshes the balance and
//     whichever data tab is showing, and switching tabs refreshes the tab being
//     shown (the loaders own their own floors, so this is safe to call often);
//   * how tall the card is — the Spend tab sizes it to its content, the data
//     tabs take the full box and scroll inside it.
//
// The balance itself is read live from the host widget rather than copied in,
// so the header follows the poller instead of a snapshot taken at load.
Panel {
  id: root
  moduleName: "io.github.kematzy.openscale"
  manageIpc: false

  // ---- Injected by BarWidget.qml ------------------------------------------
  property var anchorItem: null
  property var hostWidget: null

  // The bar identifies a popup by the widget mounted in its slot, not by this
  // nested panel, so every bar-facing identity resolves to the host widget.
  readonly property var barIdentity: hostWidget || root

  // Read live from the host widget rather than copied at injection time: the
  // balance changes on the service's own schedule, so the panel has to follow
  // it instead of holding the value it was handed on load.
  readonly property string creditText: hostWidget ? hostWidget.creditText : "—"
  readonly property bool lowCredit: hostWidget ? hostWidget.lowCredit === true : false
  readonly property bool balanceRefreshing: hostWidget
    ? hostWidget.balanceRefreshing === true
    : false
  readonly property real spent24hUsd: hostWidget ? hostWidget.spent24hUsd : -1
  readonly property real lowBalance: hostWidget ? hostWidget.lowBalance : 3

  // Injected by BarWidget.qml: one loader shared by the Spend and Tokens tabs.
  property var usage: null

  // Opening the popup — by click or by `omarchy-shell shell summon` — asks the
  // host for a fresh balance and refreshes whichever data tab is showing. The
  // host decides whether the balance is stale enough; the tab only fetches if
  // it is the current one.
  readonly property int spendTabIndex: 0
  readonly property int tokensTabIndex: 1
  readonly property int modelsTabIndex: 2

  onOpenedChanged: if (opened) root.refreshOnOpen()
  onTabIndexChanged: root.refreshActiveTab()

  function refreshOnOpen() {
    if (hostWidget && typeof hostWidget.refreshOnOpen === "function") hostWidget.refreshOnOpen()
    root.refreshActiveTab()
  }

  // Per-tab height. Spend sizes the card to what the whole column needs —
  // header, tab strip, the tab itself and the footer — while the data tabs take
  // the full box and scroll inside it, because how long they are depends on the
  // catalogue and on how many models a window carries.
  //
  // The extra couple of pixels cover fittedContentHeight()'s rounding, which
  // could otherwise leave the last row a fraction of a pixel outside the card.
  // fittedContentHeight() still clamps the result to the screen.
  readonly property real contentHeightTarget: tabIndex === root.spendTabIndex
    ? Math.max(panelContent.implicitHeight, Style.space(240)) + Style.space(2)
    : Style.space(600)

  function refreshActiveTab() {
    if (tabIndex === root.spendTabIndex || tabIndex === root.tokensTabIndex) {
      if (root.usage) root.usage.refresh()
      return
    }
    if (tabIndex === root.modelsTabIndex) modelsTab.refresh()
  }

  // ---- Theme ---------------------------------------------------------------
  // Single source of colour for the whole panel; children receive it as `ui`.
  readonly property var ui: theme

  Theme {
    id: theme
    foregroundColor: root.bar ? root.bar.foreground : Commons.Color.foreground
  }

  // ---- Tabs ----------------------------------------------------------------
  property int tabIndex: 0

  function stepTab(direction) {
    var next = tabIndex + direction
    if (next < 0) next = tabBar.count - 1
    if (next >= tabBar.count) next = 0
    tabIndex = next
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    // Anchored under the bar button rather than centred on the screen.
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(460))
    contentHeight: panel.fittedContentHeight(root.contentHeightTarget)

    Behavior on contentHeight {
      NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // Let the Spend tab's number field keep its own keys while it is focused.
      blocked: spendTab.editing
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) { if (dx !== 0) root.stepTab(dx) }
      onTextKey: function(text) {
        if (text === "1" || text === "2" || text === "3") root.tabIndex = Number(text) - 1
      }

      ColumnLayout {
        id: panelContent
        anchors.fill: parent
        spacing: Style.space(12)

        // ---- Header (every tab) -------------------------------------------
        PanelHeader {
          Layout.fillWidth: true
          creditText: root.creditText
          lowCredit: root.lowCredit
          busy: root.balanceRefreshing
          ui: theme
          balanceUsd: root.hostWidget ? root.hostWidget.balanceUsd : -1
          dailyRateUsd: (root.usage && root.usage.week && root.usage.week.costUsd > 0)
            ? root.usage.week.costUsd / 7 : -1
        }

        LowBalanceBanner {
          Layout.fillWidth: true
          visible: root.lowCredit
          ui: theme
          onAddCreditsRequested: Util.execArgv(["xdg-open",
            "https://app.openscale.so/app?credits=open"])
        }

        // ---- Tab bar -------------------------------------------------------
        // The rule sits directly on the tab strip, so the strip reads as one
        // block with a top border. The extra room above it is what separates
        // the tabs from the balance.
        ColumnLayout {
          Layout.fillWidth: true
          Layout.topMargin: Style.space(12)
          spacing: 0

          PanelSeparator {
            Layout.fillWidth: true
            foreground: theme.fg
            strength: theme.ruleStrong
          }

          TabBar {
            id: tabBar
            Layout.fillWidth: true
            // The Controls style paints a filled band behind the tabs; its
            // palette window colour differs from the popup surface, so the
            // band's bottom edge read as a second rule under the strip.
            background: null
            currentIndex: root.tabIndex
            onCurrentIndexChanged: root.tabIndex = currentIndex

            Tab {
              text: "Spend"
              shortcut: 1
              // Both usage tabs are fed by one loader, so both spin while it
              // is fetching.
              busy: root.usage ? root.usage.loading : false
              ui: theme
            }
            Tab {
              text: "Tokens"
              shortcut: 2
              busy: root.usage ? root.usage.loading : false
              ui: theme
            }
            Tab {
              text: "Models"
              // Spins only while the catalogue is actually being fetched.
              busy: modelsTab.loading
              shortcut: 3
              ui: theme
            }
          }

          // Closes the strip — the rule above it opens it.
          PanelSeparator {
            Layout.fillWidth: true
            foreground: theme.fg
            strength: theme.ruleStrong
          }
        }

        // ---- Main area -----------------------------------------------------
        StackLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          currentIndex: root.tabIndex

          SpendTab {
            id: spendTab
            ui: theme
            spent24hUsd: root.spent24hUsd
            usage: root.usage
            lowBalance: root.lowBalance
            onLowBalanceEdited: function(value) {
              if (hostWidget && typeof hostWidget.saveLowBalance === "function")
                hostWidget.saveLowBalance(value)
            }
          }
          TokensTab {
            id: tokensTab
            ui: theme
            usage: root.usage
          }
          ModelsTab {
            id: modelsTab
            ui: theme
          }
        }

        // ---- Status strip (every tab) --------------------------------------
        PanelStatus {
          Layout.fillWidth: true
          ui: theme
          legend: root.tabIndex === root.modelsTabIndex
            ? "\u26A1 fast serving · NEW since last launch · prices in USD $/1M tokens"
            : "Amounts in USD"
          error: root.tabIndex === root.modelsTabIndex
            ? modelsTab.error
            : (root.usage ? root.usage.error : "")
          fetchedAt: root.tabIndex === root.modelsTabIndex
            ? modelsTab.fetchedAt
            : (root.usage && root.usage.fetchedAt > 0 ? root.usage.fetchedAt / 1000 : 0)
        }

        // ---- Footer (every tab) --------------------------------------------
        PanelFooter {
          Layout.fillWidth: true
          ui: theme
          lowCredit: root.lowCredit
        }
      }
    }
  }
}
