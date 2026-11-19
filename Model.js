// Pure helpers for the PIA bar widget. ES5 only: QML's JS engine and Node
// (for tests) must both be able to load this file.

// Two-letter country prefixes PIA uses in region ids, mapped to the subtitle
// shown under a city name.
var COUNTRY_CODES = {
  us: "US", uk: "UK", ca: "CA", au: "AU", de: "DE", fr: "FR", es: "ES",
  it: "IT", dk: "DK", fi: "FI", se: "SE", jp: "JP", kr: "KR", lu: "LU",
  mx: "MX", nz: "NZ", cl: "CL", ar: "AR", br: "BR", za: "ZA", rs: "RS",
  at: "AT", be: "BE", ch: "CH", cy: "CY", hu: "HU", il: "IL", pl: "PL",
  pt: "PT", ro: "RO", sk: "SK", nl: "NL"
};

// Full names for codes that only appear on streaming-only regions
// ("fr-streaming-optimized" is France, not a city called Fr).
var COUNTRY_NAMES = {
  us: "United States", uk: "United Kingdom", ca: "Canada", au: "Australia",
  de: "Germany", fr: "France", es: "Spain", it: "Italy", dk: "Denmark",
  fi: "Finland", se: "Sweden", jp: "Japan", kr: "South Korea",
  lu: "Luxembourg", mx: "Mexico", nz: "New Zealand", cl: "Chile",
  ar: "Argentina", br: "Brazil", za: "South Africa", rs: "Serbia",
  at: "Austria", be: "Belgium", ch: "Switzerland", cy: "Cyprus",
  hu: "Hungary", il: "Israel", pl: "Poland", pt: "Portugal",
  ro: "Romania", sk: "Slovakia", nl: "Netherlands"
};

// Tokens that stay uppercase inside a city name.
var ACRONYMS = { dc: "DC" };

// Map a raw connectionstate value onto a semantic kind. Anything unexpected
// (including an empty answer) reads as "unknown" rather than throwing.
function parseState(raw) {
  var value = String(raw || "").replace(/\s+/g, " ").trim()
  if (value === "Connected") return "connected"
  if (value === "Disconnected") return "disconnected"
  if (value === "Connecting") return "connecting"
  if (value === "Reconnecting") return "reconnecting"
  if (value === "Interrupted") return "interrupted"
  if (value === "DisconnectingToReconnect") return "switching"
  if (value === "Disconnecting") return "disconnecting"
  return "unknown"
}

// PIA truncates long ids ("sk-str...ized"), so match both spellings.
function isStreaming(id) {
  return id.indexOf("streaming-optimized") !== -1 || id.indexOf("...ized") !== -1
}

function stripStreaming(id) {
  return String(id)
    .replace(/-?streaming-optimized$/i, "")
    .replace(/-?str\.\.\.ized$/i, "")
}

function titleCase(text) {
  var words = String(text || "").split(" ")
  var out = []
  for (var i = 0; i < words.length; i++) {
    var word = words[i]
    if (!word) continue
    var lower = word.toLowerCase()
    if (ACRONYMS[lower]) out.push(ACRONYMS[lower])
    else out.push(word.charAt(0).toUpperCase() + word.slice(1))
  }
  return out.join(" ")
}

// One region id -> { id, title, subtitle, streaming, isAuto }.
// "us-seattle" -> Seattle / US; "ecuador" -> Ecuador; "mx-streaming-optimized"
// -> Mexico (streaming); "nl-netherlands-streaming-optimized" -> Netherlands.
function regionEntry(id) {
  var raw = String(id || "")
  if (raw === "auto") {
    return { id: "auto", title: "Auto", subtitle: "", streaming: false, isAuto: true }
  }
  var streaming = isStreaming(raw)
  var work = stripStreaming(raw)
  if (work === "") {
    return { id: raw, title: titleCase(raw), subtitle: "", streaming: streaming, isAuto: false }
  }
  var tokens = work.split("-")
  var code = COUNTRY_CODES[tokens[0]]
  if (code && tokens.length === 1) {
    return { id: raw, title: COUNTRY_NAMES[tokens[0]] || code, subtitle: "", streaming: streaming, isAuto: false }
  }
  if (code && tokens.length >= 2) {
    var city = tokens.slice(1).join(" ")
    // "nl-netherlands" spells the country out rather than naming a city.
    if (String(COUNTRY_NAMES[tokens[0]] || "").toLowerCase() === city) {
      return { id: raw, title: titleCase(city), subtitle: "", streaming: streaming, isAuto: false }
    }
    return { id: raw, title: titleCase(city), subtitle: code, streaming: streaming, isAuto: false }
  }
  return { id: raw, title: titleCase(work.replace(/-/g, " ")), subtitle: "", streaming: streaming, isAuto: false }
}

// Full `piactl get regions` output -> array of entries, "auto" excluded
// (the panel pins its own translated Auto row above the list). Lines with
// spaces are CLI noise (e.g. "Timed out after 5.001 sec"), never region ids.
function regionModel(rawList) {
  var out = []
  var lines = String(rawList || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var id = lines[i].replace(/\r/g, "").trim()
    if (id === "" || id === "auto" || id.indexOf(" ") !== -1) continue
    out.push(regionEntry(id))
  }
  return out
}

function filterRegions(list, query) {
  var q = String(query || "").trim().toLowerCase()
  if (q === "") return list
  var out = []
  for (var i = 0; i < list.length; i++) {
    var region = list[i]
    var hay = (region.title + " " + region.subtitle + " " + region.id).toLowerCase()
    if (hay.indexOf(q) !== -1) out.push(region)
  }
  return out
}

// Dynamic text (region names, CLI errors) that flows into shared tooltip or
// notification sinks gets neutralized here: no markup, no sprawl.
function cleanText(value) {
  var text = String(value || "").replace(/[<>&"']/g, "")
  text = text.replace(/\s+/g, " ").trim()
  return text.length > 80 ? text.substring(0, 79) + "…" : text
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    parseState: parseState,
    regionEntry: regionEntry,
    regionModel: regionModel,
    filterRegions: filterRegions,
    cleanText: cleanText,
    isStreaming: isStreaming
  }
}
