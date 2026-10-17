import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Left click opens the OmarCraft picker, right click opens ArtCraft Studio,
// middle click checks for updates now. Every six hours it asks bin/omarcraft
// for pending app updates; when there are some the icon turns urgent, the
// tooltip lists them and the picker leads with "Update apps".
BarWidget {
  id: root
  moduleName: "omarcraft.productivity"

  readonly property string script: Qt.resolvedUrl("bin/omarcraft").toString().replace(/^file:\/\//, "")
  property var pending: []

  function run(args) {
    if (root.bar) root.bar.run("'" + root.script + "' " + args)
  }

  function refresh() {
    if (!checkProc.running) checkProc.running = true
  }

  function open() {
    root.run("menu")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // omarchy-shell omarcraft.productivity open|refresh  (for keybindings and scripts)
  IpcHandler {
    target: "omarcraft.productivity"

    function open(): void {
      root.open()
    }

    function refresh(): void {
      root.broadcast("refresh")
    }
  }

  Process {
    id: checkProc
    command: [root.script, "check", "--notify"]
    stdout: StdioCollector {
      id: checkOut
    }
    onExited: function(exitCode) {
      root.pending = exitCode === 0 ? checkOut.text.trim().split("\n") : []
    }
  }

  Timer {
    interval: 21600000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: String.fromCodePoint(0xf03d8)
    slotSize: Style.bar.statusSlot
    active: root.pending.length > 0
    tooltipText: root.pending.length > 0
      ? "ArtCraft updates:\n" + root.pending.join("\n")
      : "OmarCraft"
    onPressed: function(b) {
      if (b === Qt.RightButton) root.run("studio")
      else if (b === Qt.MiddleButton) root.refresh()
      else root.open()
    }
  }
}
