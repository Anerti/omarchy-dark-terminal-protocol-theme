import QtQuick
import QtQuick.Effects

Item {
  id: root

  property alias text: label.text
  property alias color: label.color
  property alias horizontalAlignment: label.horizontalAlignment
  property string family: ""
  property real size: 12
  property real spacing: 0
  property color glowColor: "transparent"

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  Text {
    id: label
    anchors.fill: parent
    visible: false
    font.family: root.family
    font.pixelSize: root.size
    font.letterSpacing: root.spacing
    textFormat: Text.PlainText
    elide: Text.ElideRight
  }

  MultiEffect {
    anchors.fill: label
    source: label
    shadowEnabled: root.glowColor.a > 0
    shadowColor: root.glowColor
    shadowBlur: 0.45
    blurMax: 16
    shadowHorizontalOffset: 0
    shadowVerticalOffset: 0
    autoPaddingEnabled: true
  }
}
