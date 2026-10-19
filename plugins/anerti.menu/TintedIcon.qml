import QtQuick
import QtQuick.Effects

Item {
  id: root

  property alias source: image.source
  property real size: 22
  property color tint: "#2cae2e"
  property bool inverted: false
  property color glowColor: "transparent"

  width: size
  height: size

  Image {
    id: image
    anchors.fill: parent
    visible: false
    fillMode: Image.PreserveAspectFit
    sourceSize.width: root.size * Screen.devicePixelRatio
    sourceSize.height: root.size * Screen.devicePixelRatio
    asynchronous: true
  }

  MultiEffect {
    anchors.fill: image
    source: image
    colorization: 1.0
    colorizationColor: root.tint
    brightness: root.inverted ? -1.0 : 0.12
    shadowEnabled: !root.inverted && root.glowColor.a > 0
    shadowColor: root.glowColor
    shadowBlur: 0.5
    shadowHorizontalOffset: 0
    shadowVerticalOffset: 0
    autoPaddingEnabled: true
  }
}
