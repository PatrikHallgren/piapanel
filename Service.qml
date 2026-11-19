import QtQuick
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

// Talks to the PIA daemon through piactl. No polling loop: a persistent
// `piactl monitor connectionstate` pushes every state change the moment it
// happens; the light `get` commands run on demand (panel open, after an
// action). An idle widget runs nothing beyond that one monitor process.
Item {
  id: root

  property var settings: ({})
  property bool regionsWanted: false

  // Public state
  property bool installed: false
  property string connectionState: ""   // raw value, e.g. "Connected"
  property string stateKind: "unknown"  // semantic kind, see Model.parseState
  readonly property bool connected: stateKind === "connected"
  readonly property bool transitioning: stateKind === "connecting" || stateKind === "reconnecting" || stateKind === "switching" || stateKind === "disconnecting"
  property string region: ""            // currently selected region id, or "auto"
  property string vpnIp: ""
  property var regions: []
  property bool regionsLoaded: false
  property string actionStatus: ""
  property string lastError: ""

  // Optimistic toggle so the switch throws the instant it is clicked; the
  // monitor confirms or corrects within a second. -1 = follow the daemon.
  property int _desired: -1
  readonly property bool active: _desired === -1 ? connected : (_desired === 1)

  property string _regionsSig: "[]"
  property var _actionAfter: null
  property string _actionOutput: ""
  property string _actionError: ""

  function refresh(fetchRegions) {
    if (!installed) return
    if (!stateGet.running) stateGet.running = true
    if (!regionGet.running) regionGet.running = true
    if (connected && !vpnIpGet.running) vpnIpGet.running = true
    if ((fetchRegions === true || regionsWanted) && !regionsGet.running) regionsGet.running = true
  }

  function elideError(text) {
    var value = String(text || "").replace(/\s+/g, " ").trim()
    return value.length > 140 ? value.substring(0, 137) + "…" : value
  }

  function resetUnavailable() {
    connectionState = "Unknown"
    stateKind = "unknown"
    region = ""
    vpnIp = ""
    publishRegions([])
    regionsLoaded = false
  }

  function publishRegions(next) {
    var sig = JSON.stringify(next)
    if (sig === _regionsSig) return
    _regionsSig = sig
    regions = next
  }

  function toggleConnection() {
    if (!installed) return
    if (active) {
      _desired = 0
      runAction(["piactl", "disconnect"])
    } else {
      _desired = 1
      runAction(["piactl", "connect"])
    }
  }

  function setRegion(id) {
    if (!installed) return
    var target = String(id || "")
    if (target === "" || target === region) return
    region = target
    runAction(["piactl", "set", "region", target])
  }

  function runAction(command, after) {
    if (actionProcess.running) return
    _actionOutput = ""
    _actionError = ""
    _actionAfter = after || null
    actionProcess.command = command
    actionProcess.running = true
  }

  function handleMonitorLine(line) {
    var value = String(line || "").replace(/\s+/g, " ").trim()
    if (value === "") return
    var kind = Model.parseState(value)
    if (kind === "unknown") {
      if (!/timed out/i.test(value) && !/failed/i.test(value)) return
      resetUnavailable()
      return
    }
    connectionState = value
    stateKind = kind
    if (_desired !== -1) {
      var settledOn = _desired === 1 && kind === "connected"
      var settledOff = _desired === 0 && kind === "disconnected"
      if (settledOn || settledOff) _desired = -1
    }
  }

  // The monitor: long-lived, pushed lines. piactl monitor exits when the
  // daemon goes away (service stopped, PIA update) — restart it periodically.
  Process {
    id: monitorProcess
    running: root.installed
    command: ["piactl", "monitor", "connectionstate"]
    stdout: SplitParser { onRead: function(data) { root.handleMonitorLine(data) } }
    onExited: function(exitCode) {
      root.resetUnavailable()
      monitorRetry.restart()
    }
  }

  Timer {
    id: monitorRetry
    interval: 5000
    repeat: false
    onTriggered: if (root.installed) monitorProcess.running = true
  }

  Process {
    id: stateGet
    running: false
    command: ["piactl", "get", "connectionstate"]
    stdout: StdioCollector {
      id: stateStdout
      waitForEnd: true
      onStreamFinished: {
        var value = String(stateStdout.text || "").replace(/\s+/g, " ").trim()
        var kind = Model.parseState(value)
        root.connectionState = value
        root.stateKind = kind
        // A reload can tear down vpnIpGet before this collector's last
        // stream event lands; the guard keeps the teardown quiet.
        if (kind === "connected" && root.vpnIpGet) root.vpnIpGet.running = true
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.resetUnavailable()
    }
  }

  Process {
    id: regionGet
    running: false
    command: ["piactl", "get", "region"]
    stdout: StdioCollector {
      id: regionStdout
      onStreamFinished: root.region = Model.cleanText(regionStdout.text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.region = ""
    }
  }

  Process {
    id: vpnIpGet
    running: false
    command: ["piactl", "get", "vpnip"]
    stdout: StdioCollector {
      id: vpnStdout
      onStreamFinished: {
        var value = Model.cleanText(vpnStdout.text)
        root.vpnIp = /^unknown$/i.test(value) ? "" : value
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.vpnIp = ""
    }
  }

  Process {
    id: regionsGet
    running: false
    command: ["piactl", "get", "regions"]
    stdout: StdioCollector {
      id: regionsStdout
      waitForEnd: true
      onStreamFinished: {
        root.publishRegions(Model.regionModel(regionsStdout.text))
        root.regionsLoaded = true
      }
    }
  }

  Process {
    id: actionProcess
    running: false
    command: []
    stdout: StdioCollector { id: actionStdout; waitForEnd: true; onStreamFinished: root._actionOutput = text }
    stderr: StdioCollector { id: actionStderr; waitForEnd: true; onStreamFinished: root._actionError = text }
    onExited: function(exitCode) {
      var stdout = String(actionStdout.text || root._actionOutput || "")
      var stderr = String(actionStderr.text || root._actionError || "")
      if (exitCode !== 0) {
        root._desired = -1
        root.lastError = root.elideError(stderr || stdout || "Command failed")
        root.actionStatus = root.lastError
        actionStatusTimer.restart()
      } else {
        root.lastError = ""
        root.actionStatus = ""
      }
      if (root._actionAfter) root._actionAfter()
      Qt.callLater(function() { root.refresh(false) })
    }
  }

  Timer {
    id: actionStatusTimer
    interval: 2600
    repeat: false
    onTriggered: root.actionStatus = ""
  }

  // One-shot at startup: confirm piactl exists and the daemon answers.
  Process {
    id: whichProcess
    running: true
    command: ["sh", "-c", "command -v piactl >/dev/null 2>&1 && piactl get connectionstate >/dev/null 2>&1 || exit 1"]
    onExited: function(exitCode) {
      root.installed = exitCode === 0
      if (root.installed) root.refresh(false)
    }
  }
}
