import QtQuick
import Quickshell
import Quickshell.Io

// Owns the data. One short-lived `bin/omarcraft state` run per refresh (local files only). A read in
// flight is never killed by a newer request: the request is queued and served by one more run when
// the first ends. Only a read older than stallMs is restarted, so a wedged process cannot freeze the
// panel. job.json is watched so a terminal job started from the panel, or from anywhere else, shows
// up and clears without polling.
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
  property bool rerun: false
  property double startedAt: 0
  readonly property int stallMs: 10000
  // The watchdog for the two network runs (the review of 0.5.6, omacom/omarchy-plugin-marketplace#14528):
  // a check or a catalog refresh still running after watchdogMs is ended, so it cannot hold back the
  // next one. The script bounds its own parts (curl --max-time, checkupdates REPO_CHECK_SECONDS); this is
  // the panel's backstop for the whole run.
  readonly property int watchdogMs: 300000
  property double catalogStartedAt: 0
  property double checkStartedAt: 0

  function refresh() {
    if (stateProc.running) {
      if (Date.now() - startedAt < stallMs) {
        rerun = true
        return
      }
      stateProc.running = false
    }
    busy = true
    startedAt = Date.now()
    stateProc.running = true
  }

  // Coalesces the bursts a file watcher produces into one run.
  function refreshSoon() {
    refreshTimer.restart()
  }

  // A detached catalog refresh, then a re-read when it pokes the panel back.
  function refreshCatalog() {
    if (catalogProc.running) return
    catalogStartedAt = Date.now()
    catalogProc.running = true
  }

  // The six-hourly check: notifies once per new set of updates, then re-reads.
  function check() {
    if (checkProc.running) return
    checkStartedAt = Date.now()
    checkProc.running = true
  }

  // Marks every catalog app as seen (the panel was open), then re-reads so `new` clears.
  function markSeen() {
    if (!seenProc.running) seenProc.running = true
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
      // Empty output is a run that ended early; a later run will say what is true.
      if (String(text || "").trim() !== "") lastError = "state is not JSON"
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
    onExited: function(exitCode, exitStatus) {
      root.busy = false
      // A normal exit with a status is a real failure. A signal exit (exitStatus 1) is a stalled run
      // this service restarted, or a crash; the next read tells the truth, so nothing is shown.
      if (exitStatus === 0 && exitCode !== 0) root.lastError = "omarcraft state exited with status " + exitCode
      if (root.rerun) {
        root.rerun = false
        Qt.callLater(root.refresh)
      }
    }
  }

  Process {
    id: catalogProc
    command: [root.scriptPath, "refresh", "-f"]
    onExited: root.refreshSoon()
  }

  Process {
    id: seenProc
    command: [root.scriptPath, "seen"]
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
    interval: 30000
    repeat: true
    running: catalogProc.running || checkProc.running
    onTriggered: {
      var now = Date.now()
      if (catalogProc.running && now - root.catalogStartedAt > root.watchdogMs) catalogProc.running = false
      if (checkProc.running && now - root.checkStartedAt > root.watchdogMs) checkProc.running = false
    }
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
