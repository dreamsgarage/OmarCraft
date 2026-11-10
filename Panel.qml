import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// OmarCraft: the ArtCraft Craft apps and more from the bar. Bar icon + native KeyboardPanel, data from
// Service.qml, every mutation delegated to bin/omarcraft in a floating Omarchy terminal.
// 0.5.8 (docs/v0.5.8-plan.md, design Round 7): three categories, Creative, 3D Art and Office, each an
// accordion whose open state the widget's settings keep (openCategories); Craft Anything alone in a
// footer; no version numbers anywhere in the panel. Inside an open category the apps show as tiles (three
// per line, the app's own colour) or rows, switched with `t` or
// `omarchy bar set omarcraft.productivity layout tiles|rows`.
Panel {
  id: root
  moduleName: "omarcraft.productivity"
  ipcTarget: "omarcraft.productivity"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool darkBackground: Qt.color(String(Color.popups.background)).hslLightness < 0.5
  readonly property string pluginDir: Model.urlToPath(Qt.resolvedUrl("."))
  readonly property string scriptPath: pluginDir + "/bin/omarcraft"
  // The rocket (Nerd Font md-rocket_launch), the mark the user chose from captures of the real bar.
  readonly property string logo: "\u{F14DE}"

  readonly property string layout: setting("layout", "tiles") === "rows" ? "rows" : "tiles"
  readonly property bool tiles: layout === "tiles"
  readonly property real tileWidth: (column.width - Style.space(6) * (Model.COLUMNS - 1)) / Model.COLUMNS

  readonly property var openIds: Model.parseOpen(setting("openCategories", ""))
  readonly property var categories: Model.categories(craft.apps, openIds)
  readonly property var footerApps: Model.footerApps(craft.apps)
  readonly property var cursorKeys: Model.cursorKeys(craft.apps, openIds)
  readonly property string updateNames: Model.updateNames(craft.apps)
  readonly property int pending: craft.counts.updates || 0
  readonly property bool jobRunning: !!craft.job
  readonly property bool jobFailed: Model.jobFailed(craft)
  readonly property int newApps: Model.newCount(craft.apps)
  // The bar icon turns urgent for pending updates, for Craft apps that appeared since the panel was
  // last open, and after a failed job.
  readonly property bool attention: pending > 0 || newApps > 0 || jobFailed
  readonly property var missingCreative: Model.missingIds(craft.apps, "creative")
  readonly property var missing3d: Model.missingIds(craft.apps, "3d")
  readonly property var missingOffice: Model.missingIds(craft.apps, "office")
  // After a successful update, one line naming what was updated: until the next key, eight seconds, or
  // the panel closing (which marks the job seen).
  property string dismissedSummary: ""
  readonly property string summaryRaw: Model.summaryLine(craft)
  readonly property string summaryText: summaryRaw !== "" && craft.lastJob && String(craft.lastJob.endedAt) === dismissedSummary ? "" : summaryRaw
  readonly property string statusLine: craft.actionStatus !== "" ? craft.actionStatus
    : craft.lastError !== "" ? craft.lastError
    : Model.standingLine(craft)

  property bool cursorActive: false
  // True while the list scrolls and for a moment after (see the Flickable).
  property bool scrolling: false
  Timer { id: scrollQuiet; interval: 300; onTriggered: root.scrolling = false }
  function hoverTo(key) { if (!root.scrolling) root.setCursorTo(key) }
  property int cursor: 0
  readonly property string cursorKey: cursorKeys.length > 0 ? cursorKeys[Math.max(0, Math.min(cursor, cursorKeys.length - 1))] : ""

  // One confirm at a time: what it would do, and where it sits. In the tiles layout every confirm is
  // the strip under the hero; in rows an app's confirm sits under its row.
  property string confirmKind: ""      // "" | "install" | "update" | "system-update" | "remove"
  property var confirmIds: []
  property string confirmAt: ""        // "strip" | "app:<id>" | "group"
  readonly property bool confirmOpen: confirmKind !== ""
  readonly property bool stripOpen: confirmOpen && confirmAt === "strip"

  // With the badge the button paints text wider than an icon; the open-panel dot follows it.
  readonly property real openPanelIndicatorWidth: pending > 0 && !button.vertical ? button.glyphPaintedWidth : 0

  function run(args) {
    if (root.bar) root.bar.run(Util.shellQuote(root.scriptPath) + " " + args)
  }

  function tintFor(app) {
    var t = Model.tintFor(app, root.darkBackground)
    return t !== "" ? Qt.color(t) : root.foreground
  }

  function moveCursor(dx, dy) {
    if (cursorKeys.length === 0) return
    if (!cursorActive) { cursorActive = true; return }
    cursor = Model.gridMove(cursorKeys, craft.apps, root.openIds, cursor, dx, dy, root.tiles)
    cancelConfirm()
    Qt.callLater(ensureCursorVisible)
  }

  function setCursorTo(key) {
    var idx = cursorKeys.indexOf(key)
    if (idx < 0) return
    cursorActive = true
    cursor = idx
  }

  function placementFor(key) {
    return root.tiles ? "strip" : key
  }

  function openConfirm(kind, ids, at) {
    if (jobRunning) { craft.flash("Wait for the running job to finish"); return }
    if (ids.length === 0) return
    confirmKind = kind
    confirmIds = ids
    confirmAt = at
  }

  function cancelConfirm() {
    confirmKind = ""
    confirmIds = []
    confirmAt = ""
  }

  function runConfirm() {
    if (!confirmOpen) return
    // system-update goes through `update`: the CLI sends repo apps to Omarchy's system update.
    run((confirmKind === "update" || confirmKind === "system-update" ? "update " : confirmKind === "remove" ? "remove " : "install ") + confirmIds.join(" "))
    craft.flash("Opening a terminal…")
    cancelConfirm()
  }

  function launchInstead() {
    if ((confirmKind !== "update" && confirmKind !== "system-update") || confirmIds.length !== 1) return
    var id = confirmIds[0]
    cancelConfirm()
    launch(id)
  }

  function launch(id) {
    var app = Model.appById(craft.apps, id)
    if (!app) return
    run("launch " + id)
    craft.flash("Launching " + app.name + "…")
  }

  // Enter, click or the row action. Installed: launch, or ask to update when a newer build exists.
  // Available: ask to install (Enter again runs it).
  function primary(key) {
    if (key.indexOf("cat:") === 0) { toggleCategory(key.slice(4)); return }
    if (key.indexOf("app:") !== 0) return
    var id = key.slice(4)
    var app = Model.appById(craft.apps, id)
    if (!app) return
    if (confirmOpen && confirmIds.length === 1 && confirmIds[0] === id) { runConfirm(); return }
    if (app.installed) {
      if (app.updateReady) openConfirm(app.source === "repo" ? "system-update" : "update", [id], placementFor(key))
      else launch(id)
      return
    }
    openConfirm("install", [id], placementFor(key))
  }

  // x, Delete or a right click on an installed app: ask to remove its package. An app installed some
  // other way is left to the path that installed it.
  function confirmRemove(key) {
    if (!key || key.indexOf("app:") !== 0) return
    var id = key.slice(4)
    var app = Model.appById(craft.apps, id)
    if (!app || !app.installed) return
    if (app.source !== "bin" && app.source !== "repo") { craft.flash(app.name + " was not installed by OmarCraft · remove it the way it was installed"); return }
    setCursorTo(key)
    openConfirm("remove", [id], placementFor(key))
  }

  function confirmGroup(ids, category) {
    if (ids.length === 0) { craft.flash("Nothing to install"); return }
    openConfirm("install", ids, root.tiles ? "strip" : "group:" + (category || ""))
  }

  // Open or close a category; the widget's settings keep it, like the layout.
  function setOpen(list) {
    var next = Model.openString(list)
    if (next === Model.openString(root.openIds)) return
    root.settings = Object.assign({}, root.settings, { openCategories: next })
    if (root.bar && root.bar.shell) root.bar.shell.updateEntryInline(root.moduleName, root.settings)
  }

  function toggleCategory(id) {
    cancelConfirm()
    setOpen(Model.toggled(root.openIds, id))
    Qt.callLater(function() { root.setCursorTo("cat:" + id); root.ensureCursorVisible() })
  }

  // A category with an app the user has not seen opens itself, once per opening of the panel; after that
  // it stays as the user leaves it, even if a refresh arrives while the panel is open.
  property var autoOpened: []
  function openNewCategories() {
    var ids = Model.newCategoryIds(craft.apps)
    var list = root.openIds.slice(), seen = root.autoOpened.slice(), changed = false
    for (var i = 0; i < ids.length; i++) {
      if (seen.indexOf(ids[i]) >= 0) continue
      seen.push(ids[i])
      if (list.indexOf(ids[i]) < 0) { list.push(ids[i]); changed = true }
    }
    root.autoOpened = seen
    if (changed) setOpen(list)
  }

  function dismissSummary() {
    if (root.summaryText !== "" && craft.lastJob) root.dismissedSummary = String(craft.lastJob.endedAt)
  }

  // Update all: every pending app. With an app from a package repo among them, Omarchy's update brings
  // them all at once; AUR apps alone update one package each (Model.updateAllPlan).
  function confirmUpdateAll() {
    var plan = Model.updateAllPlan(craft.apps)
    if (plan.ids.length === 0) {
      craft.flash("No updates pending")
      return
    }
    openConfirm(plan.kind, plan.ids, "strip")
  }

  function refreshNow() {
    craft.flash("Checking the AUR…")
    craft.refreshCatalog()
  }

  function setLayout(name) {
    var next = name === "rows" ? "rows" : "tiles"
    root.settings = Object.assign({}, root.settings, { layout: next })
    if (root.bar && root.bar.shell) root.bar.shell.updateEntryInline(root.moduleName, root.settings)
    cancelConfirm()
    craft.flash(next === "tiles" ? "Tiles layout" : "Rows layout")
  }

  function toggleLayout() {
    setLayout(root.tiles ? "rows" : "tiles")
  }

  // Rows and tiles register themselves so the Flickable can keep the cursor in view.
  property var rowItems: ({})
  function registerRow(key, item) { rowItems[key] = item }
  function ensureCursorVisible() {
    var item = rowItems[cursorKey]
    if (!item || !panelFlick) return
    var top = item.mapToItem(column, 0, 0).y
    var bottom = top + item.height
    if (top < panelFlick.contentY) panelFlick.contentY = Math.max(0, top - Style.space(8))
    else if (bottom > panelFlick.contentY + panelFlick.height)
      panelFlick.contentY = Math.min(panelFlick.contentHeight - panelFlick.height, bottom - panelFlick.height + Style.space(8))
  }

  IpcHandler {
    target: "omarcraft.productivity"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { craft.refreshSoon() }
    function status(): string { return JSON.stringify({ layout: root.layout, counts: craft.counts, job: craft.job, lastJob: craft.lastJob, offline: craft.offline, error: craft.lastError, apps: craft.apps }) }
    function layout(name: string): string {
      if (name !== "tiles" && name !== "rows") return "usage: layout tiles|rows (now " + root.layout + ")"
      root.setLayout(name)
      return "layout " + name
    }
    function launch(id: string): string {
      var app = Model.appById(craft.apps, id)
      if (!app) return "unknown app: " + id
      if (!app.installed) return app.name + " is not installed"
      root.launch(id)
      return "launching " + app.name
    }
    function install(ids: string): string {
      var list = String(ids).trim().split(/\s+/).filter(function(s) { return s.length > 0 })
      if (list.length === 0) return "usage: install <id>..."
      for (var i = 0; i < list.length; i++) if (!Model.appById(craft.apps, list[i])) return "unknown app: " + list[i]
      root.run("install " + list.join(" "))
      return "installing " + list.join(" ")
    }
    function remove(ids: string): string {
      var list = String(ids).trim().split(/\s+/).filter(function(s) { return s.length > 0 })
      if (list.length === 0) return "usage: remove <id>..."
      for (var i = 0; i < list.length; i++) {
        var app = Model.appById(craft.apps, list[i])
        if (!app) return "unknown app: " + list[i]
        if (!app.installed) return app.name + " is not installed"
        if (app.source !== "bin") return app.name + " was not installed as a package by OmarCraft"
      }
      root.run("remove " + list.join(" "))
      return "removing " + list.join(" ")
    }
    function update(ids: string): string {
      var list = String(ids || "").trim().split(/\s+/).filter(function(s) { return s.length > 0 })
      if (list.length === 0) list = Model.updateAllPlan(craft.apps).ids
      if (list.length === 0) return "no ArtCraft updates pending"
      for (var i = 0; i < list.length; i++) if (!Model.appById(craft.apps, list[i])) return "unknown app: " + list[i]
      root.run("update " + list.join(" "))
      return "updating " + list.join(" ")
    }
  }

  onOpenedChanged: {
    if (opened) {
      cancelConfirm()
      cursorActive = false
      cursor = 0
      craft.refresh()
      autoOpened = []
      openNewCategories()
      if (panelFlick) panelFlick.contentY = 0
    } else if (root.newApps > 0 || root.jobFailed || root.summaryRaw !== "") {
      // Closing the panel counts as having seen the new apps and the last job: the bar stops asking for
      // attention and the summary line goes.
      craft.markSeen()
    }
  }

  // New apps can arrive while the panel is open (a check finishing): their category opens then too.
  Connections {
    target: craft
    function onAppsChanged() { if (root.opened) root.openNewCategories() }
  }

  Timer { interval: 8000; running: root.opened && root.summaryText !== ""; onTriggered: root.dismissSummary() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Service {
    id: craft
    scriptPath: root.scriptPath
    jobPath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/omarchy/omarcraft/job.json"
  }

  // While a job runs, keep re-reading so a terminal killed without a trace is noticed.
  Timer { interval: 5000; running: root.jobRunning; repeat: true; onTriggered: craft.refresh() }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.pending > 0 && !vertical ? root.pending + " " + root.logo : root.logo
    // The icon slot and 13 px glyph of the first-party panels (power, network), not the smaller
    // status class: at 10 px the mark was unreadable next to its neighbours.
    slotSize: Style.bar.iconSlot * (root.pending > 0 && !vertical ? 2 : 1)
    active: root.attention
    tooltipText: ""
    onPressed: function(b) {
      if (b === Qt.RightButton) root.refreshNow()
      else if (b === Qt.MiddleButton) root.toggleLayout()
      else root.toggle()
    }
  }

  // Section label: 11 px bold caps, the first-party header style one size up for legibility.
  component SectionLabel: Text {
    property color tone: root.dim
    textFormat: Text.PlainText
    color: tone
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    font.bold: true
    font.letterSpacing: 1.2
    topPadding: Style.space(2)
  }

  // Tiles of one section, three per line.
  component TileGrid: Grid {
    property var apps: []
    width: column.width
    columns: Model.COLUMNS
    columnSpacing: Style.space(6)
    rowSpacing: Style.space(6)
    Repeater {
      model: parent.apps
      delegate: AppTile {
        required property var modelData
        width: root.tileWidth
        key: "app:" + modelData.id
        glyph: modelData.glyph
        name: modelData.name
        tint: root.tintFor(modelData)
        installed: modelData.installed
        badge: Model.badgeFor(modelData)
        badgeColor: Model.badgeIsUpdate(modelData) ? root.urgent : root.accent
        busy: Model.jobCovers(craft.job, modelData.id)
        failed: root.jobFailed && Model.jobCovers(craft.lastJob, modelData.id)
        actionsEnabled: modelData.installed || !root.jobRunning
        isCursor: root.cursorActive && root.cursorKey === key
        tooltipText: root.scrolling ? "" : Model.tileTip(modelData, craft)
        foreground: root.foreground
        urgent: root.urgent
        accent: root.accent
        fontFamily: root.fontFamily
        onHovered: root.hoverTo(key)
        onActivated: { root.setCursorTo(key); root.primary(key) }
        onSecondary: root.confirmRemove(key)
        Component.onCompleted: root.registerRow(key, this)
      }
    }
  }

  // A category's header line: chevron and name, then an update dot, New, "3 of 4" and the install key while
  // something in it is missing. Enter or a click opens or closes it.
  component CategoryHeader: CursorSurface {
    id: hdr
    property var cat: ({})
    readonly property string key: "cat:" + (cat.id || "")
    readonly property bool isCursor: root.cursorActive && root.cursorKey === key
    hasCursor: isCursor
    foreground: root.foreground
    accent: root.accent
    width: column.width
    implicitHeight: Math.max(hdrLeft.implicitHeight, hdrRight.implicitHeight) + Style.space(8)

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) root.hoverTo(hdr.key)
      onClicked: { root.setCursorTo(hdr.key); root.toggleCategory(hdr.cat.id) }
    }

    Row {
      id: hdrLeft
      anchors.left: parent.left
      anchors.leftMargin: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: hdr.cat.open ? "\u{F0140}" : "\u{F0142}"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
      SectionLabel {
        anchors.verticalCenter: parent.verticalCenter
        topPadding: 0
        text: String(hdr.cat.label || "").toUpperCase()
        tone: hdr.isCursor ? root.foreground : root.dim
      }
    }

    Row {
      id: hdrRight
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(8)
      Rectangle {
        visible: (hdr.cat.updates || 0) > 0
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(7); height: width; radius: width / 2
        color: root.urgent
      }
      Text {
        visible: !!hdr.cat.hasNew
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "New"
        color: root.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: (hdr.cat.installed || 0) + " of " + (hdr.cat.total || 0)
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
      Rectangle {
        visible: (hdr.cat.missing || []).length > 0 && !hdr.cat.open
        anchors.verticalCenter: parent.verticalCenter
        width: keyChip.implicitWidth + Style.space(8)
        height: keyChip.implicitHeight + Style.space(2)
        radius: Style.space(3)
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
        Text {
          id: keyChip
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: hdr.cat.key || ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }

    Component.onCompleted: root.registerRow(key, this)
  }

  // Rows of one section, one per line with a caption.
  component RowList: Column {
    property var apps: []
    width: column.width
    spacing: Style.space(2)
    Repeater {
      model: parent.apps
      delegate: AppRow {
        required property var modelData
        width: column.width
        key: "app:" + modelData.id
        glyph: modelData.glyph
        name: modelData.name
        subtext: Model.subtext(modelData, craft)
        actionIcon: Model.actionIcon(modelData)
        actionTip: root.scrolling ? "" : Model.actionTip(modelData)
        dimmed: !modelData.installed
        busy: Model.jobCovers(craft.job, modelData.id)
        failed: root.jobFailed && Model.jobCovers(craft.lastJob, modelData.id)
        actionsEnabled: modelData.installed || !root.jobRunning
        isCursor: root.cursorActive && root.cursorKey === key
        foreground: root.foreground
        urgent: root.urgent
        fontFamily: root.fontFamily
        extra: root.confirmAt === key ? confirmLine : null
        onHovered: root.hoverTo(key)
        onActivated: { root.setCursorTo(key); root.primary(key) }
        onSecondary: root.confirmRemove(key)
        Component.onCompleted: root.registerRow(key, this)
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) { root.dismissSummary(); root.moveCursor(dx, dy) }
      onActivateRequested: {
        root.dismissSummary()
        if (root.confirmOpen) root.runConfirm()
        else if (root.cursorActive) root.primary(root.cursorKey)
        else root.cursorActive = true
      }
      onCloseRequested: { if (root.confirmOpen) root.cancelConfirm(); else root.close() }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onDeleteRequested: if (root.cursorActive) root.confirmRemove(root.cursorKey)
      onTextKey: function(t) {
        root.dismissSummary()
        var k = t.toLowerCase()
        if (k === "u") root.confirmUpdateAll()
        else if (k === "x" && root.cursorActive) root.confirmRemove(root.cursorKey)
        else if (k === "c") root.confirmGroup(root.missingCreative, "creative")
        else if (k === "3") root.confirmGroup(root.missing3d, "3d")
        else if (k === "o") root.confirmGroup(root.missingOffice, "office")
        else if (k === "r") root.refreshNow()
        else if (k === "t") root.toggleLayout()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height

        // While it scrolls, and a moment after, hovering does nothing: no cursor jump, no tooltip. With a
        // trackpad the pointer stays put while the tiles slide under it, and every tile it crossed moved
        // the cursor and started a tooltip; scrolling ran in bursts, about two a second (measured
        // 2026-11-09). The trackpad itself scrolls 1:1 through Flickable.
        onContentYChanged: { root.scrolling = true; scrollQuiet.restart() }
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(10)

          // ---------- Hero: rocket logo · OmarCraft · "4 OF 13 INSTALLED · 2 UPDATES" · refresh ----------
          Item {
            width: parent.width
            implicitHeight: Math.max(heroLogo.implicitHeight, heroLabels.implicitHeight, heroRefresh.implicitHeight)

            Text {
              id: heroLogo
              textFormat: Text.PlainText
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: root.logo
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }

            Column {
              id: heroLabels
              anchors.left: heroLogo.right
              anchors.leftMargin: Style.space(14)
              anchors.right: heroRefresh.left
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(3)

              Text {
                textFormat: Text.PlainText
                text: "OmarCraft"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }
              Row {
                spacing: Style.space(6)
                Text {
                  textFormat: Text.PlainText
                  text: Model.metaLine(craft).toUpperCase()
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  font.letterSpacing: 1.2
                }
                Text {
                  textFormat: Text.PlainText
                  visible: text !== ""
                  text: Model.metaUpdates(craft).toUpperCase()
                  color: root.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  font.letterSpacing: 1.2
                }
              }
            }

            Button {
              id: heroRefresh
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              iconText: "\u{F0450}"
              iconSpinning: craft.busy || craft.refreshing
              bordered: true
              tooltipText: Model.refreshTip(craft)
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.refreshNow()
            }
          }

          // After a successful update: "✓ Updated PhotoCraft and WordCraft".
          Row {
            visible: root.summaryText !== ""
            width: parent.width
            spacing: Style.space(6)
            Text {
              textFormat: Text.PlainText
              text: "\u{F012C}"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
            Text {
              width: parent.width - Style.space(24)
              textFormat: Text.PlainText
              text: root.summaryText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }
          }

          // Only while something needs saying: a flash, an error, a running or failed job, offline.
          Text {
            visible: root.statusLine !== ""
            width: parent.width
            textFormat: Text.PlainText
            text: root.statusLine
            color: craft.lastError !== "" || root.jobFailed ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          // The confirm strip: every confirm in the tiles layout, Update all in both.
          Loader {
            width: parent.width
            active: root.stripOpen
            visible: active
            sourceComponent: confirmLine
          }

          PanelSeparator { width: parent.width; foreground: root.foreground }

          // ---------- Updates: the names and Update all; the tiles stay in their category ----------
          Item {
            visible: root.pending > 0
            width: parent.width
            implicitHeight: Math.max(updatesText.implicitHeight, updateAll.implicitHeight)

            Column {
              id: updatesText
              anchors.left: parent.left
              anchors.right: updateAll.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)
              SectionLabel {
                text: "UPDATES · " + root.pending
                tone: root.urgent
              }
              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: root.updateNames
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
            }
            Button {
              id: updateAll
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              visible: !root.jobRunning
              text: "Update all · u"
              iconText: root.logo
              bordered: true
              fontSize: Style.font.bodySmall
              foreground: root.urgent
              accent: root.urgent
              fontFamily: root.fontFamily
              tooltipText: "Every app with a newer build"
              onClicked: root.confirmUpdateAll()
            }
          }
          PanelSeparator { width: parent.width; foreground: root.foreground; visible: root.pending > 0 }

          // ---------- Categories: one header line each, opened with Enter ----------
          Repeater {
            model: root.categories
            delegate: Column {
              id: catBlock
              required property var modelData
              width: column.width
              spacing: Style.space(6)

              CategoryHeader { cat: catBlock.modelData }
              TileGrid { visible: root.tiles && catBlock.modelData.open; apps: root.tiles && catBlock.modelData.open ? catBlock.modelData.apps : [] }
              RowList { visible: !root.tiles && catBlock.modelData.open; apps: !root.tiles && catBlock.modelData.open ? catBlock.modelData.apps : [] }
              Item {
                visible: catBlock.modelData.open && catBlock.modelData.missing.length > 0
                width: parent.width
                implicitHeight: installMissing.implicitHeight
                Button {
                  id: installMissing
                  anchors.right: parent.right
                  iconText: catBlock.modelData.key
                  iconSize: Style.font.bodySmall
                  text: "Install " + catBlock.modelData.missing.length
                  bordered: true
                  fontSize: Style.font.bodySmall
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  enabled: !root.jobRunning
                  opacity: enabled ? 1.0 : 0.45
                  tooltipText: Model.namesFor(craft.apps, catBlock.modelData.missing).join(", ")
                  onClicked: root.confirmGroup(catBlock.modelData.missing, catBlock.modelData.id)
                }
              }
              Loader {
                width: parent.width
                active: root.confirmOpen && root.confirmAt === "group:" + catBlock.modelData.id
                visible: active
                sourceComponent: confirmLine
              }
            }
          }

          // ---------- Footer: Craft Anything, alone, never collapsed ----------
          PanelSeparator { width: parent.width; foreground: root.foreground; visible: root.footerApps.length > 0 }
          RowList { visible: root.footerApps.length > 0; apps: root.footerApps }

          // ---------- Empty / loading ----------
          Text {
            visible: craft.loaded && root.categories.length === 0 && root.footerApps.length === 0
            width: parent.width
            textFormat: Text.PlainText
            text: craft.refreshing ? "Checking the AUR for the Craft apps…" : "No Craft app has an AUR build yet."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  // The confirm: one line naming what will happen, then Install/Update/Remove, Launch instead, Cancel.
  // Remove is the one destructive action, so its button takes the urgent colour.
  Component {
    id: confirmLine
    Column {
      spacing: Style.space(6)

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: Model.confirmText(root.confirmKind, craft.apps, root.confirmIds)
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }
      Flow {
        width: parent.width
        spacing: Style.space(8)
        Button {
          text: (root.confirmKind === "update" ? "Update" : root.confirmKind === "system-update" ? "Update system" : root.confirmKind === "remove" ? "Remove" : "Install") + " ⏎"
          bordered: true
          active: true
          fontSize: Style.font.bodySmall
          foreground: root.foreground
          accent: root.confirmKind === "remove" ? root.urgent : root.accent
          fontFamily: root.fontFamily
          onClicked: root.runConfirm()
        }
        Button {
          visible: (root.confirmKind === "update" || root.confirmKind === "system-update") && root.confirmIds.length === 1
          text: "Launch instead"
          fontSize: Style.font.bodySmall
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.launchInstead()
        }
        Button {
          text: "Cancel Esc"
          fontSize: Style.font.bodySmall
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.cancelConfirm()
        }
      }
    }
  }
}
