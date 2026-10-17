import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// OmarCraft: the ArtCraft Craft apps from the bar. Bar icon + native KeyboardPanel, data from
// Service.qml, every mutation delegated to bin/omarcraft in a floating Omarchy terminal.
Panel {
  id: root
  moduleName: "omarcraft.productivity"
  ipcTarget: "omarcraft.productivity"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string pluginDir: Model.urlToPath(Qt.resolvedUrl("."))
  readonly property string scriptPath: pluginDir + "/bin/omarcraft"

  readonly property var sections: Model.sections(craft.apps)
  readonly property var cursorKeys: Model.cursorKeys(craft.apps)
  readonly property int pending: craft.counts.updates || 0
  readonly property bool jobRunning: !!craft.job
  readonly property bool jobFailed: Model.jobFailed(craft)
  readonly property bool attention: pending > 0 || jobFailed
  readonly property var missingAll: Model.missingIds(craft.apps, "all")
  readonly property var missingCreative: Model.missingIds(craft.apps, "creative")
  readonly property var missingOffice: Model.missingIds(craft.apps, "office")

  property bool cursorActive: false
  property int cursor: 0
  readonly property string cursorKey: cursorKeys.length > 0 ? cursorKeys[Math.max(0, Math.min(cursor, cursorKeys.length - 1))] : ""

  // One inline confirm at a time: what it would do, and which row or control it sits under.
  property string confirmKind: ""      // "" | "install" | "update"
  property var confirmIds: []
  property string confirmAt: ""        // "app:<id>" | "group" | "update"
  readonly property bool confirmOpen: confirmKind !== ""

  // With the badge the button paints text wider than an icon; the open-panel dot follows it.
  readonly property real openPanelIndicatorWidth: pending > 0 && !button.vertical ? button.glyphPaintedWidth : 0

  function run(args) {
    if (root.bar) root.bar.run(Util.shellQuote(root.scriptPath) + " " + args)
  }

  function moveCursor(delta) {
    if (cursorKeys.length === 0) return
    if (!cursorActive) { cursorActive = true; return }
    cursor = Math.max(0, Math.min(cursorKeys.length - 1, cursor + delta))
    cancelConfirm()
    Qt.callLater(ensureCursorVisible)
  }

  function setCursorTo(key) {
    var idx = cursorKeys.indexOf(key)
    if (idx < 0) return
    cursorActive = true
    cursor = idx
  }

  function openConfirm(kind, ids, at) {
    if (jobRunning) { craft.flash("Wait for the running job to finish"); return }
    if (kind === "install" && ids.length === 0) return
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
    if (confirmKind === "update") run("update")
    else run("install " + confirmIds.join(" "))
    craft.flash("Opening a terminal…")
    cancelConfirm()
  }

  // Enter, click or the row action: launch an installed app, confirm an available one, open Studio.
  function primary(key) {
    if (key === "studio") { run("studio"); craft.flash("Opening ArtCraft Studio…"); return }
    if (key.indexOf("app:") !== 0) return
    var id = key.slice(4)
    var app = Model.appById(craft.apps, id)
    if (!app) return
    if (app.installed) { run("launch " + id); craft.flash("Launching " + app.name + "…"); return }
    if (confirmAt === key) { runConfirm(); return }
    openConfirm("install", [id], key)
  }

  function confirmGroup(ids) {
    if (ids.length === 0) { craft.flash("Nothing to install"); return }
    openConfirm("install", ids, "group")
  }

  function confirmUpdate() {
    if (pending === 0) { craft.flash("No ArtCraft updates pending"); return }
    openConfirm("update", [], "update")
  }

  function refreshNow() {
    craft.flash("Checking the AUR…")
    craft.refreshCatalog()
  }

  // Rows register themselves so the Flickable can keep the cursor in view.
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
    function status(): string { return JSON.stringify({ counts: craft.counts, job: craft.job, lastJob: craft.lastJob, offline: craft.offline, apps: craft.apps }) }
    function launch(id: string): string {
      var app = Model.appById(craft.apps, id)
      if (!app) return "unknown app: " + id
      if (!app.installed) return app.name + " is not installed"
      root.run("launch " + id)
      return "launching " + app.name
    }
    function install(ids: string): string {
      var list = String(ids).trim().split(/\s+/).filter(function(s) { return s.length > 0 })
      if (list.length === 0) return "usage: install <id>..."
      for (var i = 0; i < list.length; i++) if (!Model.appById(craft.apps, list[i])) return "unknown app: " + list[i]
      root.run("install " + list.join(" "))
      return "installing " + list.join(" ")
    }
    function update(): string {
      if (root.pending === 0) return "no ArtCraft updates pending"
      root.run("update")
      return "updating"
    }
    function studio(): void { root.run("studio") }
  }

  onOpenedChanged: {
    if (opened) {
      cancelConfirm()
      cursorActive = false
      cursor = 0
      craft.refresh()
      if (panelFlick) panelFlick.contentY = 0
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
    text: root.pending > 0 && !vertical ? root.pending + " \u{F03D8}" : "\u{F03D8}"
    slotSize: Style.bar.statusSlot * (root.pending > 0 && !vertical ? 2 : 1)
    fontSize: Style.font.caption
    active: root.attention
    tooltipText: ""
    onPressed: function(b) {
      if (b === Qt.RightButton) root.run("studio")
      else if (b === Qt.MiddleButton) root.refreshNow()
      else root.toggle()
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

      onMoveRequested: function(dx, dy) { if (dy !== 0) root.moveCursor(dy) }
      onActivateRequested: {
        if (root.confirmOpen) root.runConfirm()
        else if (root.cursorActive) root.primary(root.cursorKey)
        else { root.cursorActive = true }
      }
      onCloseRequested: { if (root.confirmOpen) root.cancelConfirm(); else root.close() }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        var k = t.toLowerCase()
        if (k === "u") root.confirmUpdate()
        else if (k === "a") root.confirmGroup(root.missingAll)
        else if (k === "c") root.confirmGroup(root.missingCreative)
        else if (k === "o") root.confirmGroup(root.missingOffice)
        else if (k === "s") root.primary("studio")
        else if (k === "r") root.refreshNow()
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

          // ---------- Hero ----------
          PanelHero {
            width: parent.width
            title: "ArtCraft"
            meta: Model.metaLine(craft)
            foreground: root.foreground
            fontFamily: root.fontFamily

            iconComponent: Component {
              Text {
                textFormat: Text.PlainText
                text: "\u{F03D8}"
                color: root.attention ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }

            trailingControl: Component {
              Button {
                iconText: "\u{F0450}"
                iconSpinning: craft.busy || craft.refreshing
                tooltipText: "Check the AUR now"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.refreshNow()
              }
            }
          }

          // ---------- Status line + Update all ----------
          Item {
            width: parent.width
            implicitHeight: Math.max(statusText.implicitHeight, updateAll.visible ? updateAll.implicitHeight : 0)

            Text {
              id: statusText
              textFormat: Text.PlainText
              anchors.left: parent.left
              anchors.right: updateAll.visible ? updateAll.left : parent.right
              anchors.rightMargin: updateAll.visible ? Style.space(8) : 0
              anchors.verticalCenter: parent.verticalCenter
              text: craft.actionStatus !== "" ? craft.actionStatus
                  : craft.lastError !== "" ? craft.lastError
                  : Model.standingLine(craft)
              color: craft.lastError !== "" || root.jobFailed ? root.urgent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }

            Button {
              id: updateAll
              visible: root.pending > 0 && !root.jobRunning
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "Update all"
              iconText: "\u{F0450}"
              bordered: true
              fontSize: Style.font.bodySmall
              foreground: root.foreground
              fontFamily: root.fontFamily
              tooltipText: "Runs Omarchy's AUR update"
              onClicked: root.confirmUpdate()
            }
          }

          Loader {
            width: parent.width
            active: root.confirmAt === "update"
            visible: active
            sourceComponent: confirmLine
          }

          // ---------- Installed ----------
          PanelSeparator { width: parent.width; foreground: root.foreground; visible: root.sections.installed.length > 0 }
          PanelSectionHeader {
            visible: root.sections.installed.length > 0
            text: "INSTALLED"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }
          Repeater {
            model: root.sections.installed
            delegate: AppRow {
              required property var modelData
              width: column.width
              key: "app:" + modelData.id
              glyph: modelData.glyph
              name: modelData.name
              subtext: Model.subtext(modelData, craft)
              actionIcon: Model.actionIcon(modelData)
              actionTip: Model.actionTip(modelData)
              busy: Model.jobCovers(craft.job, modelData.id)
              failed: root.jobFailed && Model.jobCovers(craft.lastJob, modelData.id)
              actionsEnabled: true
              isCursor: root.cursorActive && root.cursorKey === key
              foreground: root.foreground
              urgent: root.urgent
              fontFamily: root.fontFamily
              onHovered: root.setCursorTo(key)
              onActivated: { root.setCursorTo(key); root.primary(key) }
              Component.onCompleted: root.registerRow(key, this)
            }
          }

          // ---------- Available ----------
          PanelSeparator { width: parent.width; foreground: root.foreground; visible: root.sections.available.length > 0 }
          PanelSectionHeader {
            visible: root.sections.available.length > 0
            text: "AVAILABLE"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }
          Repeater {
            model: root.sections.available
            delegate: AppRow {
              required property var modelData
              width: column.width
              key: "app:" + modelData.id
              glyph: modelData.glyph
              name: modelData.name
              subtext: Model.subtext(modelData, craft)
              actionIcon: Model.actionIcon(modelData)
              actionTip: Model.actionTip(modelData)
              dimmed: true
              busy: Model.jobCovers(craft.job, modelData.id)
              failed: root.jobFailed && Model.jobCovers(craft.lastJob, modelData.id)
              actionsEnabled: !root.jobRunning
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

          // ---------- Group chips ----------
          Flow {
            width: parent.width
            spacing: Style.space(6)
            visible: root.missingAll.length > 0 && root.sections.available.length > 0

            Button {
              text: Model.chipLabel("Install all", root.missingAll.length)
              bordered: true
              fontSize: Style.font.bodySmall
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: !root.jobRunning
              opacity: enabled ? 1.0 : 0.45
              tooltipText: "a"
              onClicked: root.confirmGroup(root.missingAll)
            }
            Button {
              visible: root.missingCreative.length > 0
              text: Model.chipLabel("Creative", root.missingCreative.length)
              bordered: true
              fontSize: Style.font.bodySmall
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: !root.jobRunning
              opacity: enabled ? 1.0 : 0.45
              tooltipText: "c · Photo, Vector, Film, Light, Effect, Design, CAD, Sound, FigCraft"
              onClicked: root.confirmGroup(root.missingCreative)
            }
            Button {
              visible: root.missingOffice.length > 0
              text: Model.chipLabel("Office", root.missingOffice.length)
              bordered: true
              fontSize: Style.font.bodySmall
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: !root.jobRunning
              opacity: enabled ? 1.0 : 0.45
              tooltipText: "o · Word, Deck, Grid, PdfCraft"
              onClicked: root.confirmGroup(root.missingOffice)
            }
          }

          Loader {
            width: parent.width
            active: root.confirmAt === "group"
            visible: active
            sourceComponent: confirmLine
          }

          // ---------- Studio ----------
          PanelSeparator { width: parent.width; foreground: root.foreground }
          PanelSectionHeader {
            text: "STUDIO"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }
          AppRow {
            id: studioRow
            width: column.width
            key: "studio"
            glyph: "\u{F0F49}"
            name: "ArtCraft Studio"
            subtext: craft.studioInstalled ? "Web app · in your app launcher" : "Web app · needs an ArtCraft account"
            actionIcon: "\u{F059F}"
            actionTip: "Open ArtCraft Studio"
            isCursor: root.cursorActive && root.cursorKey === key
            foreground: root.foreground
            urgent: root.urgent
            fontFamily: root.fontFamily
            onHovered: root.setCursorTo(key)
            onActivated: { root.setCursorTo(key); root.primary(key) }
            Component.onCompleted: root.registerRow(key, this)
          }

          // ---------- Empty / loading ----------
          Text {
            visible: craft.loaded && root.sections.installed.length + root.sections.available.length === 0
            width: parent.width
            textFormat: Text.PlainText
            text: craft.refreshing ? "Checking the AUR for the Craft apps…" : "No Craft app has an AUR build yet."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }

          // ---------- Key legend ----------
          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: "j/k move · ⏎ launch or install · u update · a/c/o install all/creative/office · s studio · r refresh · esc"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  // The inline confirm: one caption naming what will happen, then Install/Update and Cancel.
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
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
      Row {
        spacing: Style.space(8)
        Button {
          text: (root.confirmKind === "update" ? "Update" : "Install") + " ⏎"
          bordered: true
          fontSize: Style.font.bodySmall
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.runConfirm()
        }
        Button {
          text: "Cancel esc"
          fontSize: Style.font.bodySmall
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.cancelConfirm()
        }
      }
    }
  }
}
