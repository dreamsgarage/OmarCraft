import QtQuick
import Quickshell
import Quickshell.Io

// Owns the data. One short-lived `bin/omarcraft state` run per refresh (local files only), restarted
// unconditionally so a stalled run can never wedge the panel; job.json is watched so a terminal job
// started from the panel, or from anywhere else, shows up and clears without polling.
Item {
  id: root

  required property string scriptPath
  required property string jobPath

  property var apps: []
  property var counts: ({ installed: 0, available: 0, updates: 0, unpackaged: 0 })
  property var job: null
  property var lastJob: null
  property bool offline: false
  property bool refreshing: false
  property int catalogAgeSeconds: -1
  property bool loaded: false
  property bool busy: false
  property string lastError: ""
  property string actionStatus: ""

  function refresh() {
    if (stateProc.running) stateProc.running = false
    busy = true
    stateProc.running = true
  }

  // Coalesces the bursts a file watcher produces into one run.
  function refreshSoon() {
    refreshTimer.restart()
  }

  // A detached catalog refresh, then a re-read when it pokes the panel back.
  function refreshCatalog() {
    if (!catalogProc.running) catalogProc.running = true
  }

  // The six-hourly check: notifies once per new set of updates, then re-reads.
  function check() {
    if (!checkProc.running) checkProc.running = true
  }

  function flash(text) {
    actionStatus = text
    flashTimer.restart()
  }

  function applyState(text) {
    var s
    try {
      s = JSON.parse(text)
    } catch (e) {
      lastError = "state is not JSON"
      return
    }
    apps = s.apps || []
    counts = s.counts || counts
    job = s.job || null
    lastJob = s.lastJob || null
    offline = s.offline === true
    refreshing = s.refreshing === true
    catalogAgeSeconds = Number(s.catalogAgeSeconds)
    lastError = ""
    loaded = true
  }

  Process {
    id: stateProc
    command: [root.scriptPath, "state"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyState(text)
    }
    onExited: function(exitCode) {
      root.busy = false
      if (exitCode !== 0) root.lastError = "omarcraft state exited with status " + exitCode
    }
  }

  Process {
    id: catalogProc
    command: [root.scriptPath, "refresh", "-f"]
    onExited: root.refreshSoon()
  }

  Process {
    id: checkProc
    command: [root.scriptPath, "check", "--notify"]
    onExited: root.refreshSoon()
  }

  FileView {
    path: root.jobPath
    watchChanges: true
    printErrors: false
    onFileChanged: root.refreshSoon()
    onLoaded: root.refreshSoon()
    onLoadFailed: root.refreshSoon()
  }

  Timer {
    id: refreshTimer
    interval: 150
    onTriggered: root.refresh()
  }

  Timer {
    id: flashTimer
    interval: 2600
    onTriggered: root.actionStatus = ""
  }

  // Every six hours, like Omarchy's own update check; runs with the panel closed because the bar
  // badge depends on it.
  Timer {
    interval: 21600000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.check()
  }

  Component.onCompleted: refresh()
}
