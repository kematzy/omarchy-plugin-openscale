.pragma library

// Shared number formatting, so every tab speaks the same way.
//
// Money keeps its cents; counts stay exact below 10,000 and compact to K/M
// above it; decimals are dropped when they are zero.

function money(value) {
  var amount = Number(value)
  if (!isFinite(amount) || amount < 0) return "—"
  return "$" + amount.toFixed(2)
}

// 9,999 · 10.5K · 55K · 19.41M · 363.76M · 2M
function count(value) {
  var n = Number(value)
  if (!isFinite(n) || n < 0) return "—"
  if (n < 10000) return group(Math.round(n))
  // Just below a million, K would round to "1000K"; show 1M instead.
  if (n < 999995) return trim(n / 1000) + "K"
  return trim(n / 1000000) + "M"
}

function group(value) {
  return String(value).replace(/\B(?=(\d{3})+(?!\d))/g, ",")
}

// Two decimals at most, and none when they would be zeros: 2.73, 2, 10.5.
function trim(value) {
  var text = Number(value).toFixed(2)
  if (text.indexOf(".") === -1) return text
  text = text.replace(/0+$/, "")
  return text.replace(/\.$/, "")
}

// Whole percent; anything that would round to 0 is "<1%" rather than a lie.
function percent(ratio) {
  var r = Number(ratio)
  if (!isFinite(r) || r < 0) return "—"
  var pc = r * 100
  if (pc > 0 && pc < 1) return "<1%"
  return Math.round(pc) + "%"
}

// Context window: 1048568 reads as 1M, 131072 as 131K.
function context(tokens) {
  var n = Number(tokens)
  if (!isFinite(n) || n <= 0) return "—"
  if (n >= 1000000) {
    var millions = n / 1000000
    return (millions >= 10 ? Math.round(millions) : Math.round(millions * 10) / 10) + "M"
  }
  if (n >= 1000) return Math.round(n / 1000) + "K"
  return String(Math.round(n))
}

// "2026-10-26 at 15:57:53", local time, from epoch seconds.
function stamp(seconds) {
  if (!seconds) return ""
  var date = new Date(seconds * 1000)
  return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate())
    + " at " + pad(date.getHours()) + ":" + pad(date.getMinutes()) + ":" + pad(date.getSeconds())
}

function pad(value) {
  return (value < 10 ? "0" : "") + value
}
