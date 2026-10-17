import QtQuick
import qs.Commons
import qs.Ui

// One row of the panel: glyph · name over subtext · one action at the right edge. The recipe is the
// Network panel's row; the optional `extra` slot below the body hosts the inline confirm line.
CursorSurface {
  id: row

  required property string key
  required property string glyph
  required property string name
  required property string subtext
  required property string actionIcon
  required property string actionTip
  property bool dimmed: false
  property bool busy: false
  property bool failed: false
  property bool actionsEnabled: true
  property bool isCursor: false
  property color urgent: Color.urgent
  property string fontFamily: Style.font.family
  property Component extra: null

  signal hovered()
  signal activated()

  hasCursor: isCursor
  readonly property color glyphColor: failed ? urgent : (dimmed && !busy ? Qt.darker(foreground, 1.5) : foreground)
  readonly property color subtextColor: failed ? urgent : (busy ? foreground : Qt.darker(foreground, 1.5))

  implicitHeight: body.implicitHeight + (extraLoader.item ? extraLoader.implicitHeight + Style.spacing.md : 0)

  MouseArea {
    id: rowMouse
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: body.implicitHeight
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    enabled: row.actionsEnabled
    onContainsMouseChanged: if (containsMouse) row.hovered()
    onClicked: row.activated()
  }

  Item {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.leftMargin: Style.space(10)
    anchors.rightMargin: Style.space(10)
    implicitHeight: Math.max(glyphText.implicitHeight, info.implicitHeight, action.implicitHeight) + Style.spacing.rowPaddingX

    Text {
      id: glyphText
      textFormat: Text.PlainText
      text: row.busy ? "\u{F0996}" : row.glyph
      color: row.glyphColor
      font.family: row.fontFamily
      font.pixelSize: Style.font.title
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(18)
      horizontalAlignment: Text.AlignHCenter

      RotationAnimator on rotation {
        running: row.busy
        from: 0
        to: 360
        duration: 800
        loops: Animation.Infinite
      }
      onVisibleChanged: if (!row.busy) rotation = 0
    }

    PanelActionButton {
      id: action
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      iconText: row.actionIcon
      tooltipText: row.actionTip
      foreground: row.foreground
      fontFamily: row.fontFamily
      enabled: row.actionsEnabled && !row.busy
      opacity: enabled ? 1.0 : 0.45
      onClicked: row.activated()
      onHovered: function(on) { if (on) row.hovered() }
    }

    Column {
      id: info
      spacing: Style.space(1)
      anchors.left: glyphText.right
      anchors.leftMargin: Style.space(10)
      anchors.right: action.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter

      Text {
        textFormat: Text.PlainText
        text: row.name
        color: row.foreground
        opacity: row.dimmed && !row.busy ? 0.75 : 1.0
        font.family: row.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        width: parent.width
      }
      Text {
        textFormat: Text.PlainText
        text: row.subtext
        visible: row.subtext !== ""
        height: visible ? implicitHeight : 0
        color: row.subtextColor
        font.family: row.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        width: parent.width
      }
    }
  }

  Loader {
    id: extraLoader
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: body.bottom
    anchors.topMargin: item ? Style.spacing.md : 0
    anchors.leftMargin: Style.space(10) + Style.space(18) + Style.space(10)
    anchors.rightMargin: Style.space(10)
    sourceComponent: row.extra
  }
}
