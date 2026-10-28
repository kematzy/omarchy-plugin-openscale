import QtQuick
import qs.Commons
import qs.Commons as Commons

// Single source of colour for the whole plugin.
//
// Secondary colours are produced by blending the theme foreground toward the
// actual popup surface, then clamped to a WCAG contrast floor. A fixed grey
// (or the theme's terminal color8, which is what Commons.Color.muted resolves
// to) lands at ~1.9:1 on some themes — Tokyo Night among them — which makes
// column headers and units unreadable. Blending toward the real surface lands
// on the same perceived weight on every theme; the clamp guarantees a floor.
QtObject {
  id: root

  property color foregroundColor: Commons.Color.foreground
  property color surfaceColor: Commons.Color.popups.background
  property color accentColor: Commons.Color.accent
  property color urgentColor: Commons.Color.urgent

  readonly property string fontFamily: Style.font.family

  // ---- maths --------------------------------------------------------------

  function blend(a, b, t) {
    return Qt.rgba(a.r + (b.r - a.r) * t,
                   a.g + (b.g - a.g) * t,
                   a.b + (b.b - a.b) * t, 1)
  }

  function channelLin(c) {
    return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
  }

  function luminance(c) {
    return 0.2126 * root.channelLin(c.r)
         + 0.7152 * root.channelLin(c.g)
         + 0.0722 * root.channelLin(c.b)
  }

  function contrastRatio(a, b) {
    var la = root.luminance(a)
    var lb = root.luminance(b)
    var hi = Math.max(la, lb)
    var lo = Math.min(la, lb)
    return (hi + 0.05) / (lo + 0.05)
  }

  // Lighten (on a dark surface) or darken (on a light one) until the colour
  // clears `target`. Twenty steps is finer than the eye resolves and always
  // terminates.
  function ensureContrast(c, bg, target) {
    if (root.contrastRatio(c, bg) >= target) return c
    var dest = root.luminance(bg) < 0.5 ? Qt.rgba(1, 1, 1, 1) : Qt.rgba(0, 0, 0, 1)
    var out = c
    for (var i = 1; i <= 20; i++) {
      out = root.blend(c, dest, i / 20)
      if (root.contrastRatio(out, bg) >= target) return out
    }
    return out
  }

  // ---- tokens -------------------------------------------------------------

  readonly property color surface: root.surfaceColor

  // Figures, model names, amounts — anything the eye should land on first.
  readonly property color fg: root.foregroundColor

  // Column headers, units, inactive tab labels. Must stay readable.
  readonly property color label:
    root.ensureContrast(root.blend(root.foregroundColor, root.surfaceColor, 0.30),
                        root.surfaceColor, 4.5)

  // Legends, timestamps, help text.
  readonly property color caption:
    root.ensureContrast(root.blend(root.foregroundColor, root.surfaceColor, 0.22),
                        root.surfaceColor, 4.5)

  // Rules, resting logo, disabled chrome. Not clamped: never carries text.
  readonly property color decor: root.blend(root.foregroundColor, root.surfaceColor, 0.45)

  readonly property color accent: root.ensureContrast(root.accentColor, root.surfaceColor, 4.5)

  // Balance at zero, blocking errors.
  readonly property color urgent: root.ensureContrast(root.urgentColor, root.surfaceColor, 4.5)

  // Balance low but non-zero. Amber is not in the Omarchy palette, so it is
  // fixed here and clamped like everything else.
  readonly property color warning:
    root.ensureContrast(Qt.rgba(0.878, 0.686, 0.408, 1), root.surfaceColor, 4.5)

  // Rule strengths: the thicker one closes a section, the thinner one
  // separates rows inside one.
  readonly property real ruleStrong: 0.18
  readonly property real ruleFaint: 0.08

  // Washes. Used for tab/button hover and for zebra striping.
  readonly property color hoverWash: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06)
  readonly property color zebraWash: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.035)
  readonly property color accentWash: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12)
}
