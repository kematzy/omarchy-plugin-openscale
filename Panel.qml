import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "panel"

// The OpenScale popup: header, tabs, main area, footer.
//
// `Panel` (qs.Ui) owns the open/close state; `KeyboardPanel` anchors a
// layer-shell card to the bar button and handles outside-click dismissal;
// `PanelKeyCatcher` gives us Escape, Tab (switch to the neighbouring panel)
// and the arrow keys.
Panel {
  id: root
  moduleName: "local.openscale"
  manageIpc: false

  // ---- Injected by BarWidget.qml ------------------------------------------
  property var anchorItem: null
  property var hostWidget: null

  // The bar identifies a popup by the widget mounted in its slot, not by this
  // nested panel, so every bar-facing identity resolves to the host widget.
  readonly property var barIdentity: hostWidget || root

  // Pushed in by BarWidget.qml. Becomes the shared service value later.
  property string creditText: "$0.00"

  // ---- Theme ---------------------------------------------------------------
  readonly property color contentForeground: bar ? bar.foreground : Commons.Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color mutedForeground: Commons.Color.muted
  readonly property color accentColor: Commons.Color.accent

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
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(560))
    contentHeight: panel.fittedContentHeight(Style.space(470))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) { if (dx !== 0) root.stepTab(dx) }
      onTextKey: function(text) {
        if (text === "1" || text === "2" || text === "3") root.tabIndex = Number(text) - 1
      }

      ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(12)

        // ---- Header (every tab) -------------------------------------------
        PanelHeader {
          Layout.fillWidth: true
          creditText: root.creditText
          fontFamily: root.contentFontFamily
          foreground: root.contentForeground
          mutedForeground: root.mutedForeground
        }

        // ---- Tab bar -------------------------------------------------------
        TabBar {
          id: tabBar
          Layout.fillWidth: true
          currentIndex: root.tabIndex
          onCurrentIndexChanged: root.tabIndex = currentIndex

          Tab {
            text: "Usage"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.accentColor
          }
          Tab {
            text: "Models"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.accentColor
          }
          Tab {
            text: "Settings"
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            accent: root.accentColor
          }
        }

        // ---- Main area -----------------------------------------------------
        StackLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          currentIndex: root.tabIndex

          UsageTab {
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            mutedForeground: root.mutedForeground
          }
          ModelsTab {
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            mutedForeground: root.mutedForeground
          }
          SettingsTab {
            fontFamily: root.contentFontFamily
            foreground: root.contentForeground
            mutedForeground: root.mutedForeground
          }
        }

        // ---- Footer (every tab) --------------------------------------------
        PanelFooter {
          Layout.fillWidth: true
          fontFamily: root.contentFontFamily
          foreground: root.contentForeground
          accent: root.accentColor
        }
      }
    }
  }
}
