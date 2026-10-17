import QtQuick
import qs.Commons
import qs.Ui

// One tile of the grid layout: the app's glyph in its own ArtCraft colour over its name. Three per line.
// Installed tiles carry the colour at full strength and a tinted outline; available tiles are dimmed.
CursorSurface {
  id: tile

  required property string key
  required property string glyph
  required property string name
  property color tint: foreground
  property bool dimmed: false
  property bool busy: false
  property bool failed: false
  property bool updateReady: false
  property bool actionsEnabled: true
  property bool isCursor: false
  property color urgent: Color.urgent
  property string fontFamily: Style.font.family
  property string tooltipText: ""

  signal hovered()
  signal activated()

  hasCursor: isCursor
  bordered: true
  readonly property real strength: dimmed && !busy ? 0.45 : 1.0
  readonly property color glyphColor: failed ? urgent : Qt.rgba(tint.r, tint.g, tint.b, strength)

  implicitHeight: body.implicitHeight + Style.space(16)

  // The outline carries the app colour at low alpha so the grid reads as a palette, not a border maze.
  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: "transparent"
    border.width: 1
    border.color: Qt.rgba(tile.tint.r, tile.tint.g, tile.tint.b, tile.dimmed && !tile.busy ? 0.18 : 0.45)
    visible: !tile.isCursor
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    enabled: tile.actionsEnabled
    onContainsMouseChanged: if (containsMouse) tile.hovered()
    onClicked: tile.activated()
  }

  Column {
    id: body
    anchors.centerIn: parent
    width: parent.width - Style.space(12)
    spacing: Style.space(4)

    Item {
      width: parent.width
      height: Style.font.display + Style.space(4)

      Text {
        id: glyphText
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: tile.busy ? "\u{F0996}" : tile.glyph
        color: tile.glyphColor
        font.family: tile.fontFamily
        font.pixelSize: Style.font.display

        RotationAnimator on rotation {
          running: tile.busy
          from: 0
          to: 360
          duration: 800
          loops: Animation.Infinite
        }
      }

      // A small update mark in the corner, the urgent colour, like the bar badge.
      Text {
        visible: tile.updateReady && !tile.busy
        anchors.right: parent.right
        anchors.top: parent.top
        textFormat: Text.PlainText
        text: "\u{F0450}"
        color: tile.urgent
        font.family: tile.fontFamily
        font.pixelSize: Style.font.iconSmall
      }
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: tile.name
      color: tile.foreground
      opacity: tile.dimmed && !tile.busy ? 0.7 : 1.0
      font.family: tile.fontFamily
      font.pixelSize: Style.font.bodySmall
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
    }
  }

  PanelToolTip {
    visible: mouse.containsMouse && tile.tooltipText !== ""
    text: tile.tooltipText
    fontFamily: tile.fontFamily
  }
}
