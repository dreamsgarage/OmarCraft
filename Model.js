// Pure helpers for the OmarCraft panel. No QML, no I/O: everything here is a function of the
// state JSON that bin/omarcraft prints, so it can be read, and tested, without the shell.

var SUITE_SIZE = 20
var COLUMNS = 3

// The panel's categories (0.5.8, the author's choice), in the order shown, each with the key that installs what is
// missing in it. An app's group comes from bin/omarcraft (GROUP_OF); a group not listed here is Creative,
// like there. Craft Anything's group, "solo", is the footer, outside every category.
var CATEGORIES = [
  { id: "office", label: "Office", key: "o" },
  { id: "creative", label: "Creative", key: "c" },
  { id: "3d", label: "3D Art", key: "3" }
]
var FOOTER_GROUP = "solo"

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

// An app the panel can show: installed, or with a build to install.
function shown(app) {
  return !!app && (app.installed || !!app.aurVersion)
}

function categoryOf(app) {
  var g = app ? app.group : ""
  if (g === FOOTER_GROUP) return FOOTER_GROUP
  for (var i = 0; i < CATEGORIES.length; i++) if (CATEGORIES[i].id === g) return g
  return "creative"
}

// The open categories, kept in the widget's settings as "creative,3d" (a string survives every settings
// store). Unknown ids are dropped; nothing kept means all closed (the first run).
function parseOpen(value) {
  var out = []
  var parts = String(value || "").split(",")
  for (var i = 0; i < parts.length; i++) {
    var id = parts[i].trim()
    for (var k = 0; k < CATEGORIES.length; k++) if (CATEGORIES[k].id === id && out.indexOf(id) < 0) out.push(id)
  }
  return out
}

function openString(list) {
  return parseOpen((list || []).join(",")).join(",")
}

function toggled(openIds, id) {
  var list = parseOpen((openIds || []).join(","))
  var at = list.indexOf(id)
  if (at >= 0) list.splice(at, 1)
  else list.push(id)
  return parseOpen(list.join(","))
}

// The categories as the panel draws them, each with what its header shows. Empty ones are left out.
function categories(apps, openIds) {
  var open = openIds || []
  var out = []
  for (var k = 0; k < CATEGORIES.length; k++) {
    var c = CATEGORIES[k]
    var list = [], missing = [], installed = 0, updates = 0, fresh = false
    for (var i = 0; i < (apps || []).length; i++) {
      var a = apps[i]
      if (!shown(a) || categoryOf(a) !== c.id) continue
      list.push(a)
      if (a.installed) installed++
      else missing.push(a.id)
      if (a.updateReady) updates++
      if (a.new && !a.installed) fresh = true
    }
    if (list.length === 0) continue
    out.push({ id: c.id, label: c.label, key: c.key, apps: list, installed: installed, total: list.length,
               updates: updates, hasNew: fresh, missing: missing, open: open.indexOf(c.id) >= 0 })
  }
  return out
}

// Craft Anything: the footer line, never collapsed.
function footerApps(apps) {
  var out = []
  for (var i = 0; i < (apps || []).length; i++) if (shown(apps[i]) && categoryOf(apps[i]) === FOOTER_GROUP) out.push(apps[i])
  return out
}

// The categories that have an app the user has not seen. The panel opens each of them once per opening;
// after that it stays as the user leaves it (the new flag clears when the panel closes).
function newCategoryIds(apps) {
  var out = []
  var cats = categories(apps, [])
  for (var i = 0; i < cats.length; i++) if (cats[i].hasNew) out.push(cats[i].id)
  return out
}

// The ordered keys the cursor walks: each category's header, its apps while it is open, then the footer.
function cursorKeys(apps, openIds) {
  var keys = []
  var cats = categories(apps, openIds)
  for (var k = 0; k < cats.length; k++) {
    keys.push("cat:" + cats[k].id)
    if (cats[k].open) for (var i = 0; i < cats[k].apps.length; i++) keys.push("app:" + cats[k].apps[i].id)
  }
  var foot = footerApps(apps)
  for (var j = 0; j < foot.length; j++) keys.push("app:" + foot[j].id)
  return keys
}

// The cursor's spans: a header alone, an open category's tiles, the footer. In tiles, j/k jump a whole line
// within a category's tiles and leave it at its edge; h/l step one key; everything else moves one key.
function spans(apps, openIds) {
  var out = [], at = 0
  var cats = categories(apps, openIds)
  for (var k = 0; k < cats.length; k++) {
    out.push({ lo: at, hi: at + 1, grid: false }); at++
    if (cats[k].open && cats[k].apps.length > 0) { out.push({ lo: at, hi: at + cats[k].apps.length, grid: true }); at += cats[k].apps.length }
  }
  var foot = footerApps(apps).length
  if (foot > 0) out.push({ lo: at, hi: at + foot, grid: false })
  return out
}

function gridMove(keys, apps, openIds, cursor, dx, dy, tiles) {
  var n = keys.length
  if (n === 0) return 0
  if (dx !== 0) return Math.max(0, Math.min(n - 1, cursor + dx))
  if (!tiles) return Math.max(0, Math.min(n - 1, cursor + dy))
  var list = spans(apps, openIds)
  for (var k = 0; k < list.length; k++) {
    var lo = list[k].lo, hi = list[k].hi
    if (cursor < lo || cursor >= hi) continue
    if (!list[k].grid) return Math.max(0, Math.min(n - 1, cursor + dy))
    var target = cursor + dy * COLUMNS
    if (target >= lo && target < hi) return target
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

// What Update all updates: every pending app that updates alone, one package each (AUR apps, and apps
// from Omarchy's repo, whose source reads "bin"). Only when nothing else is pending do the apps that
// update with the system (source "repo": the Arch repos) make it Omarchy's update ("system-update").
function updateAllPlan(apps) {
  var one = [], sys = []
  for (var i = 0; i < (apps || []).length; i++) {
    var a = apps[i]
    if (!a.updateReady) continue
    if (a.source === "repo") sys.push(a.id)
    else one.push(a.id)
  }
  return one.length > 0 ? { kind: "update", ids: one } : { kind: "system-update", ids: sys }
}

// The tile badge, never a version (0.5.8): "Update" for a newer build, "New" for an app not seen yet.
function badgeFor(app) {
  if (!app) return ""
  if (app.installed && app.updateReady) return "Update"
  if (app.new && !app.installed && app.aurVersion) return "New"
  return ""
}

function badgeIsUpdate(app) {
  return !!app && app.installed && app.updateReady
}

// "A", "A and B", "A, B and C", "A, B, C and 2 more".
function joinNames(names) {
  var n = names.length
  if (n === 0) return ""
  if (n === 1) return names[0]
  if (n <= 3) return names.slice(0, n - 1).join(", ") + " and " + names[n - 1]
  return names.slice(0, 3).join(", ") + " and " + (n - 3) + " more"
}

// The apps with an update, by name, for the UPDATES strip.
function updateNames(apps) {
  var names = []
  for (var i = 0; i < (apps || []).length; i++) if (apps[i].installed && apps[i].updateReady) names.push(apps[i].name)
  return names.join(" · ")
}

// After a successful update, one line naming what was updated, until it is seen (0.5.8).
function summaryLine(craft) {
  var lj = craft ? craft.lastJob : null
  if (!lj || craft.job || lj.seen || Number(lj.exit) !== 0) return ""
  if (lj.verb !== "update" && lj.verb !== "system-update") return ""
  var ids = Array.isArray(lj.ids) ? lj.ids : []
  if (ids.length === 0) return ""
  return "Updated " + joinNames(namesFor(craft.apps, ids))
}

function verbFor(kind) {
  return kind === "update" ? "Updating " : kind === "remove" ? "Removing " : kind === "system-update" ? "Updating with the system: " : "Installing "
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
  return !craft.job && !!craft.lastJob && Number(craft.lastJob.exit) !== 0 && !craft.lastJob.seen
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

// The hero's uppercase line, first part. Short: it shares the line with the updates part.
function metaLine(craft) {
  var c = craft.counts || {}
  // The tools the panel shows: an app in ArtCraft's list that nobody packaged yet (MailCraft, 2026-11-10)
  // is not counted.
  var total = 0
  for (var t = 0; t < (craft.apps || []).length; t++) if (shown(craft.apps[t])) total++
  if (total === 0) total = SUITE_SIZE
  if (craft.job) {
    var ids = craft.job.ids || []
    var verb = verbFor(craft.job.verb)
    if (craft.job.verb === "system-update") return "Updating the system…"
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
  if (jobCovers(craft.job, app.id)) return verbFor(craft.job.verb).replace(/: $/, "").trim() + "…"
  if (app.installed) {
    if (app.source === "source") return "Source build · updates via omarchy update"
    if (app.updateReady && app.source === "repo") return "Update with the system"
    if (app.updateReady) return "Update ready"
    return "Installed"
  }
  var where = app.kind === "repo" ? " · from " + repoName(app.repo) : " · prebuilt, no compiling"
  if (app.new) return "New · install" + where
  return "Install" + where
}

// The repo a repo tool installs from, as a person names it.
function repoName(repo) {
  if (repo === "omarchy") return "Omarchy's repo"
  if (!repo || repo === "core" || repo === "extra" || repo === "multilib") return "the Arch repos"
  return "the " + repo + " repo"
}

// Tiles have no caption; the same words go in the tooltip, plus how to remove an installed package.
function tileTip(app, craft) {
  var tip = app.name + " · " + subtext(app, craft)
  if (app.installed && (app.source === "bin" || app.source === "repo") && !jobCovers(craft.job, app.id)) tip += " · right-click or x to remove"
  return tip
}

function actionIcon(app) {
  if (!app.installed) return "\u{F01DA}"
  return app.updateReady ? "\u{F0450}" : "\u{F040A}"
}

function actionTip(app) {
  if (!app.installed) return "Install " + app.name
  if (app.updateReady && app.source === "repo") return app.name + "'s update comes with the system update"
  if (app.updateReady) return "Update " + app.name
  return "Launch " + app.name
}

// "Install PhotoCraft · a terminal will open and ask for your password"
// "Remove PhotoCraft · a terminal will open and ask for your password · your files stay"
// "Typesetter comes with the system update · a terminal will run Omarchy's update and ask for your password"
// Names only: a version means nothing to a person deciding (0.5.8).
function confirmText(kind, apps, ids) {
  var names = namesFor(apps, ids)
  var what = ids.length <= 3 ? joinNames(names) : ids.length + " apps"
  if (kind === "system-update")
    return what + (ids.length === 1 ? " comes" : " come") + " with the system update · a terminal will run Omarchy's update and ask for your password"
  var verb = kind === "update" ? "Update " : kind === "remove" ? "Remove " : "Install "
  return verb + what + " · a terminal will open and ask for your password" + (kind === "remove" ? " · your files stay" : "")
}
