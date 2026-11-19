// Node-runnable tests for Model.js. Run: node tests/model.test.js
// QML's JS engine and Node both load Model.js (ES5, module.exports guard).

const assert = require("assert")
const M = require("../Model.js")

let passed = 0
function ok(name, fn) {
  try { fn(); passed++; console.log("ok  " + name) }
  catch (e) { console.log("FAIL " + name + ": " + e.message); process.exitCode = 1 }
}

ok("parses all daemon states", () => {
  assert.strictEqual(M.parseState("Connected"), "connected")
  assert.strictEqual(M.parseState("Disconnected"), "disconnected")
  assert.strictEqual(M.parseState("Connecting"), "connecting")
  assert.strictEqual(M.parseState("Reconnecting"), "reconnecting")
  assert.strictEqual(M.parseState("Interrupted"), "interrupted")
  assert.strictEqual(M.parseState("DisconnectingToReconnect"), "switching")
  assert.strictEqual(M.parseState("Disconnecting"), "disconnecting")
  assert.strictEqual(M.parseState(""), "unknown")
  assert.strictEqual(M.parseState("Timed out after 5.001 sec"), "unknown")
  assert.strictEqual(M.parseState(null), "unknown")
})

ok("city region gets title and country subtitle", () => {
  const r = M.regionEntry("us-seattle")
  assert.strictEqual(r.id, "us-seattle")
  assert.strictEqual(r.title, "Seattle")
  assert.strictEqual(r.subtitle, "US")
  assert.strictEqual(r.streaming, false)
  assert.strictEqual(r.isAuto, false)
})

ok("bare country region", () => {
  const r = M.regionEntry("france")
  assert.strictEqual(r.title, "France")
  assert.strictEqual(r.subtitle, "")
})

ok("auto region", () => {
  const r = M.regionEntry("auto")
  assert.strictEqual(r.isAuto, true)
  assert.strictEqual(r.title, "Auto")
})

ok("streaming-optimized region is flagged", () => {
  const r = M.regionEntry("de-germany-streaming-optimized")
  assert.strictEqual(r.streaming, true)
  assert.strictEqual(r.title, "Germany")
})

ok("PIA's truncated streaming id resolves", () => {
  const r = M.regionEntry("sk-str...ized")
  assert.strictEqual(r.streaming, true)
  assert.strictEqual(r.title, "Slovakia")
})

ok("dc acronym stays uppercase", () => {
  const r = M.regionEntry("us-washington-dc")
  assert.strictEqual(r.title, "Washington DC")
})

ok("spelled-out country id is not mistaken for a city", () => {
  const r = M.regionEntry("nl-netherlands-streaming-optimized")
  assert.strictEqual(r.title, "Netherlands")
  assert.strictEqual(r.subtitle, "")
})

ok("multi-word city title-cases", () => {
  const r = M.regionEntry("us-salt-lake-city")
  assert.strictEqual(r.title, "Salt Lake City")
  assert.strictEqual(r.subtitle, "US")
})

ok("region list drops auto and CLI noise", () => {
  const list = M.regionModel("auto\nus-seattle\nTimed out after 5.001 sec\n\njp-tokyo")
  assert.strictEqual(list.length, 2)
  assert.strictEqual(list[0].id, "us-seattle")
  assert.strictEqual(list[1].id, "jp-tokyo")
})

ok("filter matches title, subtitle and id", () => {
  const list = M.regionModel("us-seattle\njp-tokyo\nfrance")
  assert.strictEqual(M.filterRegions(list, "seattle").length, 1)
  assert.strictEqual(M.filterRegions(list, "JP").length, 1)
  assert.strictEqual(M.filterRegions(list, "US").length, 1)
  assert.strictEqual(M.filterRegions(list, "").length, 3)
  assert.strictEqual(M.filterRegions(list, "nowhere").length, 0)
})

ok("cleanText strips markup-shaped input and caps length", () => {
  const dirty = '<img src="https://example.invalid/x"> US-Seattle'
  const clean = M.cleanText(dirty)
  assert.ok(clean.indexOf("<") === -1 && clean.indexOf(">") === -1)
  assert.ok(clean.indexOf('"') === -1)
  assert.ok(clean.length <= 80)
  assert.strictEqual(M.cleanText("  a   b  "), "a b")
})

console.log("\n" + passed + " passed")
