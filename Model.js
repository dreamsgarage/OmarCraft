// Pure helpers for the OmarCraft panel. No QML, no I/O: everything here is a function of the
// state JSON that bin/omarcraft prints, so it can be read, and tested, without the shell.

var SUITE_SIZE = 13
var COLUMNS = 3

function urlToPath(url) {
  var s = String(url || "")
  if (s.indexOf("file://") === 0) s = s.slice(7)
  return decodeURIComponent(s).replace(/\/+$/, "")
}

// Apps with an AUR build, split the way the panel shows them: a pending update puts an app in
// `updates` instead of `installed`. Unpackaged apps are hidden.
function sections(apps) {
  var updates = [], installed = [], available = []
  for (var i = 0; i < (apps || []).length; i++) {
    var a = apps[i]
    if (a.installed && a.updateReady) updates.push(a)
    else if (a.installed) installed.push(a)
    else if (a.aurVersion) available.push(a)
  }
  return { updates: updates, installed: installed, available: available }
}

// The ordered keys the cursor walks: updates, installed, available.
function cursorKeys(apps) {
  var s = sections(apps), keys = []
  var all = s.updates.concat(s.installed, s.available)
  for (var i = 0; i < all.length; i++) keys.push("app:" + all[i].id)
  return keys
}

// In the grid, j/k jump a whole line within the same section and stop at its edge; h/l step one tile.
function gridMove(keys, apps, cursor, dx, dy) {
  var n = keys.length
  if (n === 0) return 0
  if (dx !== 0) return Math.max(0, Math.min(n - 1, cursor + dx))
  var s = sections(apps)
  var a = s.updates.length, b = a + s.installed.length, c = b + s.available.length
  var bounds = [[0, a], [a, b], [b, c]]
  for (var k = 0; k < bounds.length; k++) {
    var lo = bounds[k][0], hi = bounds[k][1]
    if (cursor < lo || cursor >= hi) continue
    var target = cursor + dy * COLUMNS
    if (target >= lo && target < hi) return target
    // Past the section edge: land on the first tile of the next section, or the last of the previous.
    if (dy > 0) return Math.min(n - 1, hi)
    return Math.max(0, lo - 1)
  }
  return cursor
}

function appById(apps, id) {
  for (var i = 0; i < (apps || []).length; i++) if (apps[i].id === id) return apps[i]
  return null
}

function missingIds(apps, group) {
  var ids = []
  for (var i = 0; i < (apps || []).length; i++) {
    var a = apps[i]
    if (a.installed || !a.aurVersion) continue
    if (group === "all" || a.group === group) ids.push(a.id)
  }
  return ids
}

// Craft apps that appeared in the catalog since the panel was last closed and are not installed.
function newCount(apps) {
  var n = 0
  for (var i = 0; i < (apps || []).length; i++) if (apps[i].new && !apps[i].installed && apps[i].aurVersion) n++
  return n
}

function outdatedIds(apps) {
  var ids = []
  for (var i = 0; i < (apps || []).length; i++) if (apps[i].updateReady) ids.push(apps[i].id)
  return ids
}

function namesFor(apps, ids) {
  var names = []
  for (var i = 0; i < ids.length; i++) {
    var a = appById(apps, ids[i])
    names.push(a ? a.name : ids[i])
  }
  return names
}

function jobCovers(job, id) {
  return !!job && Array.isArray(job.ids) && job.ids.indexOf(id) >= 0
}

function jobFailed(craft) {
  return !craft.job && !!craft.lastJob && Number(craft.lastJob.exit) !== 0
}

// The app's own ArtCraft colour, picked for the panel background it sits on; "" when the catalog
// carried none, so the caller falls back to the theme foreground.
function tintFor(app, darkBackground) {
  if (!app) return ""
  var c = darkBackground ? app.inkDark : app.inkLight
  if (!c) c = app.color
  return c || ""
}

// "0.8.0-1" → "0.8.0": the pkgrel means nothing to a person reading a badge.
function shortVersion(v) {
  return String(v || "").replace(/-\d+$/, "")
}

function ageText(seconds) {
  var s = Number(seconds)
  if (!(s >= 0)) return "never"
  if (s < 90) return "just now"
  if (s < 5400) return Math.round(s / 60) + " min ago"
  if (s < 172800) return Math.round(s / 3600) + " h ago"
  return Math.round(s / 86400) + " days ago"
}

// The hero's uppercase line, first part. Short: it shares the line with the updates part.
function metaLine(craft) {
  var c = craft.counts || {}
  var total = (craft.apps || []).length || SUITE_SIZE
  if (craft.job) {
    var ids = craft.job.ids || []
    var verb = craft.job.verb === "update" ? "Updating " : craft.job.verb === "remove" ? "Removing " : "Installing "
    if (ids.length === 1) {
      var a = appById(craft.apps, ids[0])
      return verb + (a ? a.name : ids[0]) + "…"
    }
    return verb + ids.length + " apps…"
  }
  if (jobFailed(craft)) return "Last job failed"
  if (craft.offline) return "Offline · cached list"
  if (craft.refreshing && (c.available || 0) + (c.installed || 0) === 0) return "Checking the AUR…"
  if ((c.installed || 0) === 0) return "Nothing installed yet"
  return c.installed + " of " + total + " installed"
}

// The hero's second part, in the urgent colour: "· 2 updates", or "" when there is nothing pending.
function metaUpdates(craft) {
  var c = craft.counts || {}
  if (craft.job || jobFailed(craft) || craft.offline) return ""
  if ((c.updates || 0) === 0) return ""
  return "· " + c.updates + (c.updates === 1 ? " update" : " updates")
}

// The caption under the hero: only while something needs saying. Empty otherwise, and hidden.
function standingLine(craft) {
  if (craft.job) return "A terminal is open and may ask for your password."
  if (jobFailed(craft)) {
    var lj = craft.lastJob
    return lj.interrupted ? "Last job was interrupted · see the terminal"
                          : "Last job exited with status " + lj.exit + " · see the terminal"
  }
  if (craft.offline) return "Could not reach the AUR · list from " + ageText(craft.catalogAgeSeconds)
  return ""
}

function refreshTip(craft) {
  return "Check the AUR now · list from " + ageText(craft.catalogAgeSeconds)
}

function subtext(app, craft) {
  if (jobCovers(craft.job, app.id)) return craft.job.verb === "update" ? "Updating…" : craft.job.verb === "remove" ? "Removing…" : "Installing…"
  if (app.installed) {
    if (app.source === "source") return "Source build · updates via omarchy update"
    if (app.updateReady) return "Update ready " + app.installedVersion + " → " + app.aurVersion
    return app.installedVersion
  }
  if (app.new) return "New · install " + app.aurVersion
  return "Install " + app.aurVersion + " · prebuilt, no compiling"
}

// Tiles have no caption; the same words go in the tooltip, plus how to remove an installed package.
function tileTip(app, craft) {
  var tip = app.name + " · " + subtext(app, craft)
  if (app.installed && app.source === "bin" && !jobCovers(craft.job, app.id)) tip += " · right-click or x to remove"
  return tip
}

function actionIcon(app) {
  if (!app.installed) return "\u{F01DA}"
  return app.updateReady ? "\u{F0450}" : "\u{F040A}"
}

function actionTip(app) {
  if (!app.installed) return "Install " + app.name + " " + app.aurVersion
  if (app.updateReady) return "Update " + app.name + " to " + app.aurVersion
  return "Launch " + app.name
}

// "Install PhotoCraft 0.9.0 · a terminal will open and ask for your password"
// "Remove PhotoCraft 0.9.0 · a terminal will open and ask for your password · your files stay"
function confirmText(kind, apps, ids) {
  var parts = []
  for (var i = 0; i < ids.length; i++) {
    var a = appById(apps, ids[i])
    var name = a ? a.name : ids[i]
    if (kind === "update" && a) parts.push(name + " " + shortVersion(a.installedVersion) + " → " + shortVersion(a.aurVersion))
    else if (kind === "remove" && a) parts.push(name + (a.installedVersion ? " " + shortVersion(a.installedVersion) : ""))
    else parts.push(name + (a && a.aurVersion ? " " + shortVersion(a.aurVersion) : ""))
  }
  var verb = kind === "update" ? "Update " : kind === "remove" ? "Remove " : "Install "
  var head = verb + (ids.length <= 3 ? parts.join(", ") : ids.length + " apps")
  return head + " · a terminal will open and ask for your password" + (kind === "remove" ? " · your files stay" : "")
}

function chipLabel(label, count) {
  return label + " · " + count
}
