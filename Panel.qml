import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// OmarCraft: the ArtCraft Craft apps from the bar. Bar icon + native KeyboardPanel, data from
// Service.qml, every mutation delegated to bin/omarcraft in a floating Omarchy terminal.
// Two layouts under evaluation, switched with `omarchy bar set omarcraft.productivity layout tiles|rows`
// or the `t` key: "tiles" (three per line, the app's own colour) and "rows" (one per line with a caption).
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

  readonly property var sections: Model.sections(craft.apps)
  readonly property var cursorKeys: Model.cursorKeys(craft.apps)
  readonly property int pending: craft.counts.updates || 0
  readonly property bool jobRunning: !!craft.job
  readonly property bool jobFailed: Model.jobFailed(craft)
  readonly property int newApps: Model.newCount(craft.apps)
  // The bar icon turns urgent for pending updates, for Craft apps that appeared since the panel was
  // last open, and after a failed job.
  readonly property bool attention: pending > 0 || newApps > 0 || jobFailed
  readonly property var missingAll: Model.missingIds(craft.apps, "all")
  readonly property var missingCreative: Model.missingIds(craft.apps, "creative")
  readonly property var missingOffice: Model.missingIds(craft.apps, "office")
  readonly property string statusLine: craft.actionStatus !== "" ? craft.actionStatus
    : craft.lastError !== "" ? craft.lastError
    : Model.standingLine(craft)

  property bool cursorActive: false
  property int cursor: 0
  readonly property string cursorKey: cursorKeys.length > 0 ? cursorKeys[Math.max(0, Math.min(cursor, cursorKeys.length - 1))] : ""

  // One confirm at a time: what it would do, and where it sits. In the tiles layout every confirm is
  // the strip under the hero; in rows an app's confirm sits under its row.
  property string confirmKind: ""      // "" | "install" | "update"
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
    cursor = root.tiles ? Model.gridMove(cursorKeys, craft.apps, cursor, dx, dy)
                        : Math.max(0, Math.min(cursorKeys.length - 1, cursor + dy))
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
    run((confirmKind === "update" ? "update " : "install ") + confirmIds.join(" "))
    craft.flash("Opening a terminal…")
    cancelConfirm()
  }

  function launchInstead() {
    if (confirmKind !== "update" || confirmIds.length !== 1) return
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
    if (key.indexOf("app:") !== 0) return
    var id = key.slice(4)
    var app = Model.appById(craft.apps, id)
    if (!app) return
    if (confirmOpen && confirmIds.length === 1 && confirmIds[0] === id) { runConfirm(); return }
    if (app.installed) {
      if (app.updateReady) openConfirm("update", [id], placementFor(key))
      else launch(id)
      return
    }
    openConfirm("install", [id], placementFor(key))
  }

  function confirmGroup(ids) {
    if (ids.length === 0) { craft.flash("Nothing to install"); return }
    openConfirm("install", ids, root.tiles ? "strip" : "group")
  }

  function confirmUpdateAll() {
    var ids = Model.outdatedIds(craft.apps)
    if (ids.length === 0) { craft.flash("No ArtCraft updates pending"); return }
    openConfirm("update", ids, "strip")
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
    function status(): string { return JSON.stringify({ layout: root.layout, counts: craft.counts, job: craft.job, lastJob: craft.lastJob, offline: craft.offline, apps: craft.apps }) }
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
    function update(ids: string): string {
      var list = String(ids || "").trim().split(/\s+/).filter(function(s) { return s.length > 0 })
      if (list.length === 0) list = Model.outdatedIds(craft.apps)
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
      if (panelFlick) panelFlick.contentY = 0
    } else if (root.newApps > 0) {
      // Closing the panel counts as having seen the new apps: the bar stops asking for attention.
      craft.markSeen()
    }
  }

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
        badge: modelData.updateReady ? "↑ " + Model.shortVersion(modelData.aurVersion) : ""
        busy: Model.jobCovers(craft.job, modelData.id)
        failed: root.jobFailed && Model.jobCovers(craft.lastJob, modelData.id)
        actionsEnabled: modelData.installed || !root.jobRunning
        isCursor: root.cursorActive && root.cursorKey === key
        tooltipText: Model.tileTip(modelData, craft)
        foreground: root.foreground
        urgent: root.urgent
        accent: root.accent
        fontFamily: root.fontFamily
        onHovered: root.setCursorTo(key)
        onActivated: { root.setCursorTo(key); root.primary(key) }
        Component.onCompleted: root.registerRow(key, this)
      }
    }
  }

  // Rows of one section, one per line with a caption.
  component RowList: Column {
    property var apps: []
    property bool dimRows: false
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
        actionTip: Model.actionTip(modelData)
        dimmed: parent.dimRows
        busy: Model.jobCovers(craft.job, modelData.id)
        failed: root.jobFailed && Model.jobCovers(craft.lastJob, modelData.id)
        actionsEnabled: modelData.installed || !root.jobRunning
        isCursor: root.cursorActive && root.cursorKey === key
        foreground: root.foreground
        urgent: root.urgent
        fontFamily: root.fontFamily
        extra: root.confirmAt === key ? confirmLine : null
        onHovered: root.setCursorTo(key)
        onActivated: { root.setCursorTo(key); root.primary(key) }
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

      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: {
        if (root.confirmOpen) root.runConfirm()
        else if (root.cursorActive) root.primary(root.cursorKey)
        else root.cursorActive = true
      }
      onCloseRequested: { if (root.confirmOpen) root.cancelConfirm(); else root.close() }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        var k = t.toLowerCase()
        if (k === "u") root.confirmUpdateAll()
        else if (k === "c") root.confirmGroup(root.missingCreative)
        else if (k === "o") root.confirmGroup(root.missingOffice)
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

          // ---------- Updates ----------
          Item {
            visible: root.sections.updates.length > 0
            width: parent.width
            implicitHeight: Math.max(updatesLabel.implicitHeight, updateAll.implicitHeight)

            SectionLabel {
              id: updatesLabel
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "UPDATES · " + root.sections.updates.length
              tone: root.urgent
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
          TileGrid { visible: root.tiles && root.sections.updates.length > 0; apps: root.tiles ? root.sections.updates : [] }
          RowList { visible: !root.tiles && root.sections.updates.length > 0; apps: root.tiles ? [] : root.sections.updates }
          PanelSeparator { width: parent.width; foreground: root.foreground; visible: root.sections.updates.length > 0 }

          // ---------- Installed ----------
          SectionLabel { visible: root.sections.installed.length > 0; text: "INSTALLED · " + root.sections.installed.length }
          TileGrid { visible: root.tiles && root.sections.installed.length > 0; apps: root.tiles ? root.sections.installed : [] }
          RowList { visible: !root.tiles && root.sections.installed.length > 0; apps: root.tiles ? [] : root.sections.installed }
          PanelSeparator { width: parent.width; foreground: root.foreground; visible: root.sections.installed.length > 0 && root.sections.available.length > 0 }

          // ---------- Available ----------
          SectionLabel { visible: root.sections.available.length > 0; text: "AVAILABLE · " + root.sections.available.length }
          TileGrid { visible: root.tiles && root.sections.available.length > 0; apps: root.tiles ? root.sections.available : [] }
          RowList { visible: !root.tiles && root.sections.available.length > 0; apps: root.tiles ? [] : root.sections.available; dimRows: true }

          // ---------- Group chips, each with its key ----------
          Flow {
            width: parent.width
            spacing: Style.space(6)
            visible: root.missingAll.length > 0 && root.sections.available.length > 0

            Button {
              visible: root.missingCreative.length > 0
              iconText: "c"
              iconSize: Style.font.bodySmall
              text: Model.chipLabel("Creative", root.missingCreative.length)
              bordered: true
              fontSize: Style.font.bodySmall
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: !root.jobRunning
              opacity: enabled ? 1.0 : 0.45
              tooltipText: "Photo, Vector, Film, Light, Effect, Design, CAD, Sound, FigCraft"
              onClicked: root.confirmGroup(root.missingCreative)
            }
            Button {
              visible: root.missingOffice.length > 0
              iconText: "o"
              iconSize: Style.font.bodySmall
              text: Model.chipLabel("Office", root.missingOffice.length)
              bordered: true
              fontSize: Style.font.bodySmall
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: !root.jobRunning
              opacity: enabled ? 1.0 : 0.45
              tooltipText: "Word, Deck, Grid, PdfCraft"
              onClicked: root.confirmGroup(root.missingOffice)
            }
          }

          Loader {
            width: parent.width
            active: root.confirmOpen && root.confirmAt === "group"
            visible: active
            sourceComponent: confirmLine
          }

          // ---------- Empty / loading ----------
          Text {
            visible: craft.loaded && root.cursorKeys.length === 0
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

  // The confirm: one line naming what will happen, then Install/Update, Launch instead, Cancel.
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
          text: (root.confirmKind === "update" ? "Update" : "Install") + " ⏎"
          bordered: true
          active: true
          fontSize: Style.font.bodySmall
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.runConfirm()
        }
        Button {
          visible: root.confirmKind === "update" && root.confirmIds.length === 1
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
