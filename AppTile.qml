import QtQuick
import qs.Commons
import qs.Ui

// One tile of the grid layout: the app's glyph in its own ArtCraft colour over its name, three per
// line. Installed tiles carry a tinted fill; available tiles only an outline, with the name kept at
// full contrast. The cursor tile takes the accent: 2 px outline, tinted fill, white name.
CursorSurface {
  id: tile

  required property string key
  required property string glyph
  required property string name
  property color tint: foreground
  property bool installed: false
  property bool busy: false
  property bool failed: false
  property string badge: ""          // "↑ 0.8.0" on a tile with a newer build
  property bool actionsEnabled: true
  property bool isCursor: false
  property color urgent: Color.urgent
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  property string tooltipText: ""

  signal hovered()
  signal activated()
  signal secondary()      // right click: the remove confirm for an installed app

  hasCursor: false
  readonly property color glyphColor: failed ? urgent
    : isCursor ? tint
    : installed || busy ? tint
    : Qt.rgba(tint.r, tint.g, tint.b, 0.6)

  implicitHeight: body.implicitHeight + Style.space(18)

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: tile.isCursor ? Qt.rgba(tile.accent.r, tile.accent.g, tile.accent.b, 0.22)
         : tile.installed ? Qt.rgba(tile.tint.r, tile.tint.g, tile.tint.b, 0.12)
         : "transparent"
    border.width: tile.isCursor ? Math.max(2, Style.space(2)) : 1
    border.color: tile.isCursor ? tile.accent
                : Qt.rgba(tile.tint.r, tile.tint.g, tile.tint.b, tile.installed ? 0.55 : 0.28)
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    enabled: tile.actionsEnabled
    onContainsMouseChanged: if (containsMouse) tile.hovered()
    onClicked: function(mouse) { if (mouse.button === Qt.RightButton) tile.secondary(); else tile.activated() }
  }

  // The update badge, the urgent colour, top-right like the bar count.
  Rectangle {
    visible: tile.badge !== "" && !tile.busy
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: Style.space(5)
    width: badgeText.implicitWidth + Style.space(10)
    height: badgeText.implicitHeight + Style.space(3)
    radius: height / 2
    color: tile.urgent

    Text {
      id: badgeText
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: tile.badge
      color: Color.popups.background
      font.family: tile.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  Column {
    id: body
    anchors.centerIn: parent
    width: parent.width - Style.space(12)
    spacing: Style.space(6)

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
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: tile.name
      color: tile.isCursor ? "#ffffff" : tile.foreground
      font.family: tile.fontFamily
      font.pixelSize: Style.font.subtitle
      font.weight: tile.isCursor ? Font.Bold : Font.DemiBold
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
