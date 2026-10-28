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

// Tabular figures: a fixed unit and a fixed number of decimals, chosen once
// per column from its largest value. Mixing "986.66K" and "1.39M" down one
// column defeats the right-alignment the column exists for.
function unitFor(max) {
  var n = Number(max)
  if (!isFinite(n) || n < 10000) return ""
  if (n < 999995) return "K"
  return "M"
}

function inUnit(value, unit) {
  var n = Number(value)
  if (!isFinite(n) || n < 0) return "\u2014"
  if (unit === "M") return (n / 1000000).toFixed(2) + "M"
  if (unit === "K") return (n / 1000).toFixed(2) + "K"
  return group(Math.round(n))
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

// "Updated 2 min ago" / "Updated 3 h ago" / "Updated 27 Oct 17:20".
// Seconds-level precision is noise for a value that refreshes on a poll;
// the exact stamp stays available on hover.
function relativeStamp(seconds) {
  if (!seconds) return ""
  var delta = Math.floor(Date.now() / 1000 - seconds)
  if (delta < 60) return "Updated just now"
  if (delta < 3600) return "Updated " + Math.floor(delta / 60) + " min ago"
  if (delta < 86400) return "Updated " + Math.floor(delta / 3600) + " h ago"
  var d = new Date(seconds * 1000)
  var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
  return "Updated " + d.getDate() + " " + months[d.getMonth()] + " "
    + pad(d.getHours()) + ":" + pad(d.getMinutes())
}

// Turns whatever a CLI printed on failure into one readable line.
//
// `osc` reports errors as JSON — {"error": {"code", "exit", "message"}} — so
// putting stderr straight into the UI dumps a document into a one-line footer.
// A missing sign-in is also the one failure with a fix worth naming, and it is
// worth naming the same way everywhere.
function errorText(raw, fallback) {
  var text = String(raw === undefined || raw === null ? "" : raw)
    .replace(/\u001b\[[0-9;]*[A-Za-z]/g, "")
    .trim()

  var message = ""
  var code = ""
  if (text.charAt(0) === "{") {
    try {
      var parsed = JSON.parse(text)
      var err = parsed.error
      if (err && typeof err === "object") {
        message = String(err.message || "")
        code = String(err.code || "")
      } else if (typeof err === "string") {
        message = err
      } else if (parsed.message) {
        message = String(parsed.message)
      }
    } catch (e) {
      message = ""
    }
  }

  if (code === "unauthorized" || /not signed in|unauthorized/i.test(message)) {
    return "Not signed in — run `osc login`"
  }

  if (message === "") {
    // Not JSON, or JSON without a message: the first line worth reading.
    var lines = text.split("\n")
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim() !== "") {
        message = lines[i].trim()
        break
      }
    }
  }

  if (message === "") return fallback || "OpenScale did not answer"
  return shorten(message, 140)
}

function shorten(text, limit) {
  if (text.length <= limit) return text
  return text.slice(0, limit - 1).replace(/[ ,;:.]+$/, "") + "…"
}
