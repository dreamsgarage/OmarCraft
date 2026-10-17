// Pure helpers for the OmarCraft panel. No QML, no I/O: everything here is a function of the
// state JSON that bin/omarcraft prints, so it can be read, and tested, without the shell.

var SUITE_SIZE = 13
var COLUMNS = 3

function urlToPath(url) {
  var s = String(url || "")
  if (s.indexOf("file://") === 0) s = s.slice(7)
  return decodeURIComponent(s).replace(/\/+$/, "")
}

// Apps with an AUR build, split the way the panel shows them. Unpackaged apps are hidden.
function sections(apps) {
  var installed = [], available = []
  for (var i = 0; i < (apps || []).length; i++) {
    var a = apps[i]
    if (a.installed) installed.push(a)
    else if (a.aurVersion) available.push(a)
  }
  return { installed: installed, available: available }
}

// The ordered keys the cursor walks: installed, available, studio.
function cursorKeys(apps) {
  var s = sections(apps), keys = []
  for (var i = 0; i < s.installed.length; i++) keys.push("app:" + s.installed[i].id)
  for (var j = 0; j < s.available.length; j++) keys.push("app:" + s.available[j].id)
  keys.push("studio")
  return keys
}

// In the grid, j/k jump a whole line within the same section and stop at its edge; h/l step one tile.
function gridMove(keys, apps, cursor, dx, dy) {
  var n = keys.length
  if (n === 0) return 0
  if (dx !== 0) return Math.max(0, Math.min(n - 1, cursor + dx))
  var s = sections(apps)
  var bounds = [[0, s.installed.length], [s.installed.length, s.installed.length + s.available.length], [n - 1, n]]
  for (var b = 0; b < bounds.length; b++) {
    var lo = bounds[b][0], hi = bounds[b][1]
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

function ageText(seconds) {
  var s = Number(seconds)
  if (!(s >= 0)) return "never"
  if (s < 90) return "just now"
  if (s < 5400) return Math.round(s / 60) + " min ago"
  if (s < 172800) return Math.round(s / 3600) + " h ago"
  return Math.round(s / 86400) + " days ago"
}

// The hero's uppercase line. One short phrase; PanelHero elides past ~28 characters at 380 px.
function metaLine(craft) {
  var c = craft.counts || {}
  var total = (craft.apps || []).length || SUITE_SIZE
  if (craft.job) {
    var ids = craft.job.ids || []
    var verb = craft.job.verb === "update" ? "Updating " : "Installing "
    if (ids.length === 1) {
      var a = appById(craft.apps, ids[0])
      return verb + (a ? a.name : ids[0]) + "…"
    }
    return verb + ids.length + " apps…"
  }
  if (jobFailed(craft)) return "Last job failed"
  if (craft.offline) return "Offline · cached list"
  if (craft.refreshing && (c.available || 0) + (c.installed || 0) === 0) return "Checking the AUR…"
  if ((c.updates || 0) > 0) return c.updates + (c.updates === 1 ? " update ready" : " updates ready")
  if ((c.installed || 0) === 0) return "Nothing installed yet"
  return c.installed + " of " + total + " installed"
}

// The caption under the hero when nothing transient is showing.
function standingLine(craft) {
  if (craft.job) return "A terminal is open and may ask for your password."
  if (jobFailed(craft)) {
    var lj = craft.lastJob
    return lj.interrupted ? "Last job was interrupted · see the terminal"
                          : "Last job exited with status " + lj.exit + " · see the terminal"
  }
  if (craft.offline) return "Could not reach the AUR · list from " + ageText(craft.catalogAgeSeconds)
  return "Prebuilt · nothing compiled · list from " + ageText(craft.catalogAgeSeconds)
}

function subtext(app, craft) {
  if (jobCovers(craft.job, app.id)) return craft.job.verb === "update" ? "Updating…" : "Installing…"
  if (app.installed) {
    if (app.source === "source") return "Source build · updates via omarchy update"
    if (app.updateReady) return "Update ready " + app.installedVersion + " → " + app.aurVersion
    return app.installedVersion
  }
  if (app.new) return "New · install " + app.aurVersion
  return "Install " + app.aurVersion + " · prebuilt, no compiling"
}

// Tiles have no caption; the same words go in the tooltip.
function tileTip(app, craft) {
  return app.name + " · " + subtext(app, craft)
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

function confirmText(kind, apps, ids) {
  var pkgs = []
  for (var i = 0; i < ids.length; i++) {
    var a = appById(apps, ids[i])
    if (kind === "update" && a)
      pkgs.push(ids[i] + "-bin " + a.installedVersion + " → " + a.aurVersion)
    else
      pkgs.push(ids[i] + "-bin" + (a && a.aurVersion ? " " + a.aurVersion : ""))
  }
  var head = ids.length === 1 ? pkgs[0] : pkgs.join(", ") + " · " + ids.length + " packages"
  var how = kind === "update" ? " · via the AUR helper" : " · via Omarchy's AUR add"
  return head + how + " · a terminal opens and asks your password"
}

function chipLabel(label, count) {
  return label + " · " + count
}
