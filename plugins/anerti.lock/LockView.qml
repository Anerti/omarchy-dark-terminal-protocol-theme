import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons

// The Omarchy terminal lock screen, as in the mockup: the Omarchy mark in
// Vault-Tec wings, the OMARCHY wordmark, a block-cursor password field with the
// lock icon to its left, and
// the PLEASE STAND BY card once the password checks out. Nothing is printed
// under the field: a wrong password shakes it and turns its border red and
// dashed, the dashes being the cue that does not rely on colour.
Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false
  // Set by the service between a successful check and the unlock.
  property bool granting: false
  // Version, kernel and hostname from the service; a plain name until it answers.
  property string systemLine: ""

  readonly property color fg: "#2cae2e"
  readonly property color fgBright: "#d6ffe3"
  readonly property color urgent: "#ff5a3c"
  readonly property color lineStrong: Qt.rgba(44 / 255, 174 / 255, 46 / 255, 0.6)
  readonly property color bgDeep: "#020a05"
  readonly property string textFamily: shareTech.status === FontLoader.Ready ? shareTech.name : Style.font.family

  readonly property bool errorState: failureMessage.length > 0
  readonly property bool cursorOn: inputEnabled && !authenticatingPassword && !granting
  readonly property real rem: px(16)

  function px(n) { return Style.space(n) }
  function green(a) { return Qt.rgba(44 / 255, 174 / 255, 46 / 255, a) }

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  onFailedAttemptsChanged: if (failedAttempts > 0) shake.restart()
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  FontLoader {
    id: shareTech
    source: Qt.resolvedUrl("assets/fonts/ShareTechMono-Regular.ttf")
  }

  // .lock background: a faint green bloom above centre over a deep radial.
  Canvas {
    id: backdrop
    anchors.fill: parent
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function ellipse(ctx, cx, cy, rx, ry, stops) {
      ctx.save()
      ctx.translate(cx, cy)
      ctx.scale(rx, ry)
      var g = ctx.createRadialGradient(0, 0, 0, 0, 0, 1)
      for (var i = 0; i < stops.length; i++) g.addColorStop(stops[i][0], stops[i][1])
      ctx.fillStyle = g
      ctx.fillRect(-cx / rx, -cy / ry, width / rx, height / ry)
      ctx.restore()
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.fillStyle = root.bgDeep
      ctx.fillRect(0, 0, width, height)
      ellipse(ctx, width / 2, height / 2, width * 1.3, height * 1.1,
        [[0, "#0b2416"], [0.5, "#06170d"], [1, "#020a05"]])
      ellipse(ctx, width / 2, height * 0.44, width * 0.6, height * 0.55,
        [[0, "rgba(44,174,46,0.10)"], [0.62, "rgba(0,0,0,0)"], [1, "rgba(0,0,0,0)"]])
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
    onPositionChanged: root.wakeRequested()
  }

  component Caption: Text {
    property real tracking: 0
    readonly property int size: Math.round(root.rem * 0.74)
    color: root.fg
    opacity: 0.92
    font.family: root.textFamily
    font.pixelSize: size
    font.letterSpacing: size * tracking
    // Qt spaces after the last glyph too; pad the front the same so it centres.
    leftPadding: size * tracking
    horizontalAlignment: Text.AlignHCenter
    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: root.green(0.35)
      shadowBlur: 0.4
      shadowHorizontalOffset: 0
      shadowVerticalOffset: 0
      autoPaddingEnabled: true
    }
  }

  Caption {
    anchors.top: parent.top
    anchors.topMargin: root.px(18)
    anchors.horizontalCenter: parent.horizontalCenter
    text: "OMARCHY (TM) TERMINAL PROTOCOL"
    tracking: 0.12
  }

  Column {
    anchors.centerIn: parent
    spacing: root.px(20)

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: root.px(24)

      Item {
        id: emblem
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(root.width * 0.78, root.px(560))
        height: width * 360 / 930.07
        opacity: 0.92
        transformOrigin: Item.Center

        Image {
          id: emblemImage
          anchors.fill: parent
          source: Qt.resolvedUrl("assets/vaulttec-omarchy.svg")
          sourceSize.width: width * 2
          sourceSize.height: height * 2
          fillMode: Image.PreserveAspectFit
          smooth: true
          visible: false
        }

        // The mockup's three stacked drop-shadows: wide haze, then a tight glow.
        MultiEffect {
          anchors.fill: emblemImage
          source: emblemImage
          shadowEnabled: true
          shadowColor: root.green(0.4)
          shadowBlur: 1.0
          blurMax: 64
          shadowHorizontalOffset: 0
          shadowVerticalOffset: 0
          autoPaddingEnabled: true
        }

        MultiEffect {
          anchors.fill: emblemImage
          source: emblemImage
          shadowEnabled: true
          shadowColor: root.green(0.6)
          shadowBlur: 0.35
          blurMax: 16
          shadowHorizontalOffset: 0
          shadowVerticalOffset: 0
          autoPaddingEnabled: true
        }

        // @keyframes holo
        SequentialAnimation {
          running: root.loadBackground && root.visible && !root.granting
          loops: Animation.Infinite
          ParallelAnimation {
            NumberAnimation { target: emblem; property: "opacity"; to: 1; duration: 2250; easing.type: Easing.InOutSine }
            NumberAnimation { target: emblem; property: "scale"; to: 1.012; duration: 2250; easing.type: Easing.InOutSine }
          }
          ParallelAnimation {
            NumberAnimation { target: emblem; property: "opacity"; to: 0.92; duration: 2250; easing.type: Easing.InOutSine }
            NumberAnimation { target: emblem; property: "scale"; to: 1; duration: 2250; easing.type: Easing.InOutSine }
          }
        }
      }

      Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.px(2)
        opacity: 0.92

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          readonly property int size: Math.round(root.rem * 1.5)
          text: "OMARCHY"
          color: root.fg
          font.family: root.textFamily
          font.pixelSize: size
          font.letterSpacing: size * 0.42
          leftPadding: size * 0.42
          lineHeight: 1.1
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          readonly property int size: Math.round(root.rem * 0.8)
          text: "BEAUTIFUL, FUN & AGENTIC LINUX"
          color: root.fg
          font.family: root.textFamily
          font.pixelSize: size
          font.letterSpacing: size * 0.52
          leftPadding: size * 0.52
          lineHeight: 1.4
        }
      }
    }

    Item {
      id: fieldWrap
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(root.px(381), root.width * 0.82)
      height: root.px(67)
      transform: Translate { id: shakeShift }

      SequentialAnimation {
        id: shake
        NumberAnimation { target: shakeShift; property: "x"; to: -root.px(8); duration: 80 }
        NumberAnimation { target: shakeShift; property: "x"; to: root.px(8); duration: 80 }
        NumberAnimation { target: shakeShift; property: "x"; to: -root.px(5); duration: 80 }
        NumberAnimation { target: shakeShift; property: "x"; to: root.px(5); duration: 80 }
        NumberAnimation { target: shakeShift; property: "x"; to: 0; duration: 80 }
      }

      readonly property color borderColor: root.errorState ? root.urgent : (root.granting ? root.fg : root.lineStrong)
      readonly property color glowColor: root.errorState ? Qt.rgba(1, 90 / 255, 60 / 255, 0.45)
        : root.green(root.granting ? 0.5 : (passwordInput.activeFocus ? 0.4 : 0.18))

      // Lock icon, 14px left of the field.
      Item {
        anchors.right: parent.left
        anchors.rightMargin: root.px(14)
        anchors.verticalCenter: parent.verticalCenter
        width: root.px(23)
        height: root.px(26)

        Image {
          id: lockImage
          anchors.fill: parent
          source: Qt.resolvedUrl("assets/lock.png")
          sourceSize.width: width * 2
          sourceSize.height: height * 2
          fillMode: Image.PreserveAspectFit
          visible: false
        }

        MultiEffect {
          anchors.fill: lockImage
          source: lockImage
          colorization: 1.0
          colorizationColor: root.fg
          brightness: 0.12
          shadowEnabled: true
          shadowColor: root.green(0.75)
          shadowBlur: 0.4
          shadowHorizontalOffset: 0
          shadowVerticalOffset: 0
          autoPaddingEnabled: true
        }
      }

      RectangularShadow {
        anchors.fill: field
        radius: field.radius
        blur: root.px(22)
        color: fieldWrap.glowColor
        Behavior on color { ColorAnimation { duration: 150 } }
      }

      Rectangle {
        id: field
        anchors.fill: parent
        radius: root.px(4)
        color: Qt.rgba(4 / 255, 18 / 255, 10 / 255, 0.72)

        // inset 0 0 26px rgba(0,0,0,0.7)
        Rectangle {
          anchors.fill: parent
          anchors.margins: root.px(3)
          radius: field.radius
          gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
            GradientStop { position: 0.35; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 0.65; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.35) }
          }
        }

        Shape {
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer

          ShapePath {
            strokeWidth: root.px(3)
            strokeColor: fieldWrap.borderColor
            strokeStyle: root.errorState ? ShapePath.DashLine : ShapePath.SolidLine
            dashPattern: [3, 2]
            fillColor: "transparent"
            joinStyle: ShapePath.MiterJoin

            PathRectangle {
              x: root.px(1.5)
              y: root.px(1.5)
              width: field.width - root.px(3)
              height: field.height - root.px(3)
              radius: field.radius
            }
          }
        }

        TextInput {
          id: passwordInput
          anchors.fill: parent
          // Typed blind: the dots below are the only echo.
          opacity: 0
          activeFocusOnPress: true
          enabled: root.inputEnabled && !root.authenticatingPassword
          readOnly: root.authenticatingPassword
          echoMode: TextInput.Password
          passwordMaskDelay: 0
          cursorVisible: false
          selectByMouse: false

          onTextChanged: {
            if (!root.syncingPasswordText) root.passwordTextEdited(text)
            if (text.length > 0) {
              root.wakeRequested()
            }
            if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
          }

          onAccepted: {
            var submitted = root.passwordText
            root.passwordTextEdited("")
            if (submitted.length > 0) root.submitPassword(submitted)
          }

          Keys.onPressed: function(event) {
            root.wakeRequested()
            if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
              root.passwordTextEdited("")
              event.accepted = true
            }
          }
        }

        // .dots: one glowing dot per character and the blinking block cursor.
        // Centred while they fit, then held to the right edge so the newest
        // keystroke stays in view.
        Item {
          id: dotsBox
          anchors.fill: parent
          anchors.leftMargin: root.px(18)
          anchors.rightMargin: root.px(18) + (root.fingerprintConfigured ? fingerprintIcon.width + root.px(10) : 0)
          clip: true

          readonly property real unit: Math.round(root.rem * 1.5 * 0.62)

          Row {
            id: dots
            anchors.verticalCenter: parent.verticalCenter
            x: width > dotsBox.width ? dotsBox.width - width : (dotsBox.width - width) / 2
            spacing: root.px(6)
            layer.enabled: true
            layer.effect: MultiEffect {
              shadowEnabled: true
              shadowColor: root.green(0.7)
              shadowBlur: 0.45
              shadowHorizontalOffset: 0
              shadowVerticalOffset: 0
              autoPaddingEnabled: true
            }

            Repeater {
              model: passwordInput.text.length
              delegate: Rectangle {
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                width: dotsBox.unit
                height: dotsBox.unit
                radius: width / 2
                color: root.fgBright
              }
            }

            Rectangle {
              id: block
              anchors.verticalCenter: parent.verticalCenter
              width: dotsBox.unit
              height: Math.round(root.rem * 1.5)
              color: root.fg
              opacity: root.cursorOn && passwordInput.activeFocus && blink.on ? 1 : 0

              Timer {
                id: blink
                property bool on: true
                interval: 500
                repeat: true
                running: root.cursorOn && root.visible
                onRunningChanged: on = true
                onTriggered: on = !on
              }
            }
          }
        }

        Text {
          id: fingerprintIcon
          anchors.right: parent.right
          anchors.rightMargin: root.px(18)
          anchors.verticalCenter: parent.verticalCenter
          visible: root.fingerprintConfigured
          text: "󰈷"
          color: root.fg
          opacity: 0.7
          font.family: Style.font.family
          font.pixelSize: Math.round(root.rem * 1.2)
        }
      }
    }
  }

  Column {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.px(18)
    anchors.horizontalCenter: parent.horizontalCenter

    Caption {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.systemLine.length > 0 ? root.systemLine : "OMARCHY UNIFIED OPERATING SYSTEM"
      tracking: 0.24
      lineHeight: 1.8
    }

    Caption {
      anchors.horizontalCenter: parent.horizontalCenter
      text: "COPYRIGHT 2025 - " + new Date().getFullYear() + " OMARCHY"
      tracking: 0.24
      lineHeight: 1.8
    }
  }

  // .granted: the PLEASE STAND BY test card with its own heavier CRT, faded in
  // over everything while the service holds the lock for the hand-off.
  Rectangle {
    id: granted
    anchors.fill: parent
    color: root.bgDeep
    opacity: root.granting ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }

    MouseArea { anchors.fill: parent }

    Image {
      anchors.fill: parent
      source: root.loadBackground && (root.authenticatingPassword || root.granting || granted.visible)
        ? Qt.resolvedUrl("assets/please-stand-by.jpg") : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      sourceSize.width: width
      sourceSize.height: height
    }

    // Edge vignette (not a flat darkening, which buries the card's black text)
    // and the faint green bloom.
    Canvas {
      anchors.fill: parent
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        backdrop.ellipse(ctx, width / 2, height / 2, width * 1.2, height * 1.0,
          [[0, "rgba(2,10,5,0.08)"], [0.28, "rgba(2,10,5,0.08)"], [0.7, "rgba(2,10,5,0.42)"], [1, "rgba(2,10,5,0.86)"]])
        backdrop.ellipse(ctx, width / 2, height * 0.44, width * 0.6, height * 0.55,
          [[0, "rgba(44,174,46,0.10)"], [0.62, "rgba(0,0,0,0)"], [1, "rgba(0,0,0,0)"]])
      }
    }

    // Scanlines: 2px clear, 2px at 0.32.
    Canvas {
      anchors.fill: parent
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.fillStyle = "rgba(0,0,0,0.32)"
        for (var y = 2; y < height; y += 4) ctx.fillRect(0, y, width, 2)
      }
    }

    // Rolling beam.
    Rectangle {
      id: beam
      width: parent.width
      height: parent.height * 0.2
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(214 / 255, 1, 227 / 255, 0) }
        GradientStop { position: 0.5; color: Qt.rgba(214 / 255, 1, 227 / 255, 0.10) }
        GradientStop { position: 1.0; color: Qt.rgba(214 / 255, 1, 227 / 255, 0) }
      }

      NumberAnimation on y {
        from: -beam.height
        to: granted.height
        duration: 2800
        loops: Animation.Infinite
        running: granted.visible
      }
    }
  }
}
