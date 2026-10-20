import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons
import qs.Ui

PanelWindow {
  id: pip

  required property var menu

  property alias list: rowList
  property alias keys: keyCatcher
  property alias frame: frame

  readonly property color fg: "#2cae2e"
  readonly property color fgBright: "#d6ffe3"
  readonly property color fgDim: "#2aa52c"
  readonly property color ink: "#04160b"
  readonly property color line: Qt.rgba(44 / 255, 174 / 255, 46 / 255, 0.28)
  readonly property color lineStrong: Qt.rgba(44 / 255, 174 / 255, 46 / 255, 0.6)
  readonly property color glow: Qt.rgba(44 / 255, 174 / 255, 46 / 255, 0.55)
  readonly property color gifInk: "#e1fdf8"

  readonly property string textFamily: shareTech.status === FontLoader.Ready ? shareTech.name : menu.fontFamily
  readonly property string glyphFamily: menu.fontFamily

  function px(n) { return Style.space(n) }
  function em(size, amount) { return size * amount }

  readonly property var sections: menu.sections
  readonly property string currentSection: menu.topLevelOf(menu.activeMenu)

  // Search lists every section's matches, so the art follows the highlighted
  // result's section rather than the tab the search started from.
  readonly property string artSection: {
    var row = pip.current
    var found = menu.filterText && row && row.itemId ? menu.topLevelOf(row.itemId) : ""
    return found || pip.currentSection
  }

  readonly property var current: {
    menu.layoutSerial
    menu.selectedIndex
    menu.cursorActive
    return menu.currentRow()
  }

  function gifFor(section) {
    var known = ["apps", "learn", "trigger", "style", "setup", "install", "remove", "update", "about", "system"]
    return known.indexOf(section) >= 0 ? Qt.resolvedUrl("assets/gifs/" + section + ".gif") : ""
  }

  function roll() {
    rollWipe.run()
    rowList.positionViewAtBeginning()
  }

  visible: menu.opened && menu.rowsLoaded && !menu.dmenuActive
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  WlrLayershell.namespace: "omarchy-menu"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  // Full screen: ignore the bar's reserved zone so the overlay covers it too.
  exclusionMode: ExclusionMode.Ignore

  onVisibleChanged: if (visible) {
    pip.roll()
    Qt.callLater(function() { if (pip.visible) menu.revealCursor() })
  }

  FontLoader {
    id: shareTech
    source: Qt.resolvedUrl("assets/fonts/ShareTechMono-Regular.ttf")
  }

  Rectangle {
    id: frame
    anchors.fill: parent
    border.width: 1
    border.color: pip.lineStrong
    gradient: Gradient {
      GradientStop { position: 0.0; color: "#081f11" }
      GradientStop { position: 0.55; color: "#020a05" }
      GradientStop { position: 1.0; color: "#020a05" }
    }

    MouseArea { anchors.fill: parent; onClicked: {} }

    Repeater {
      model: [
        { edge: "top" }, { edge: "bottom" }, { edge: "left" }, { edge: "right" }
      ]
      delegate: Rectangle {
        required property var modelData
        readonly property bool vertical: modelData.edge === "top" || modelData.edge === "bottom"
        readonly property int depth: pip.px(90)
        x: modelData.edge === "right" ? frame.width - depth : 0
        y: modelData.edge === "bottom" ? frame.height - depth : 0
        width: vertical ? frame.width : depth
        height: vertical ? depth : frame.height
        gradient: Gradient {
          orientation: parent.vertical ? Gradient.Vertical : Gradient.Horizontal
          GradientStop {
            position: 0.0
            color: (modelData.edge === "top" || modelData.edge === "left") ? Qt.rgba(0, 0, 0, 0.55) : "transparent"
          }
          GradientStop {
            position: 1.0
            color: (modelData.edge === "bottom" || modelData.edge === "right") ? Qt.rgba(0, 0, 0, 0.55) : "transparent"
          }
        }
      }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      z: menu.deleteConfirmOpen ? 20 : 0

      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (menu.deleteConfirmOpen) {
          if (deleteConfirm.handleKey(event)) event.accepted = true
          return
        }
        if (menu.handleKey(event)) event.accepted = true
      }

      ConfirmDialog {
        id: deleteConfirm
        anchors.fill: parent
        opened: menu.deleteConfirmOpen
        z: 10
        message: "Do you want to uninstall " + ((menu.deleteTarget && menu.deleteTarget.label) || "") + "?"
        confirmText: "Uninstall"
        background: menu.background
        foreground: menu.foreground
        scrim: menu.scrim
        selectedBackground: menu.selectedBackground
        selectedText: menu.selectedText
        fontFamily: pip.textFamily
        cornerRadius: menu.cornerRadius
        onCanceled: menu.cancelDelete()
        onConfirmed: menu.confirmDelete()
      }
    }

    Column {
      anchors.fill: parent
      anchors.margins: 1

      Rectangle {
        id: header
        width: parent.width
        height: headerText.implicitHeight + pip.px(24)
        gradient: Gradient {
          GradientStop { position: 0.0; color: Qt.rgba(44 / 255, 174 / 255, 46 / 255, 0.08) }
          GradientStop { position: 1.0; color: "transparent" }
        }

        Column {
          id: headerText
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: pip.px(11)
          spacing: pip.px(4)

          GlowText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "OMARCHY MENU"
            color: pip.fgBright
            family: pip.textFamily
            size: pip.px(16.8)
            spacing: pip.em(size, 0.26)
            glowColor: pip.glow
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "OMARCHY (TM) TERMINAL"
            color: pip.fgDim
            font.family: pip.textFamily
            font.pixelSize: pip.px(11.2)
            font.letterSpacing: pip.em(pip.px(11.2), 0.14)
          }
        }

        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width
          height: 1
          color: pip.line
        }
      }

      Item {
        id: body
        width: parent.width
        height: parent.height - header.height - tabs.height

        Item {
          id: listColumn
          width: Math.max(pip.px(300), Math.min(pip.px(520), body.width * 0.5))
          height: parent.height

          Rectangle {
            anchors.right: parent.right
            width: 1
            height: parent.height
            color: pip.line
          }

          Item {
            id: search
            width: parent.width - 1
            height: queryRow.implicitHeight + pip.px(30)

            Row {
              id: queryRow
              anchors.left: parent.left
              anchors.leftMargin: pip.px(18)
              anchors.verticalCenter: parent.verticalCenter
              spacing: pip.px(10)

              readonly property real size: pip.px(15)
              readonly property real tracking: pip.em(size, 0.16)

              Text {
                text: ">  ›"
                color: pip.fgDim
                font.family: pip.textFamily
                font.pixelSize: queryRow.size
                font.letterSpacing: queryRow.tracking
              }

              Row {
                spacing: pip.px(3)

                Text {
                  text: menu.filterText ? menu.filterText : "GO ..."
                  color: menu.filterText ? pip.fgBright : pip.fgDim
                  font.family: pip.textFamily
                  font.pixelSize: queryRow.size
                  font.letterSpacing: queryRow.tracking
                }

                Text {
                  id: caret
                  text: "\u2588"
                  color: pip.fg
                  font.family: pip.textFamily
                  font.pixelSize: queryRow.size

                  SequentialAnimation on opacity {
                    running: pip.visible
                    loops: Animation.Infinite
                    PropertyAction { value: 1 }
                    PauseAnimation { duration: 500 }
                    PropertyAction { value: 0 }
                    PauseAnimation { duration: 500 }
                  }
                }
              }
            }

            Shape {
              anchors.bottom: parent.bottom
              width: parent.width
              height: 1
              ShapePath {
                strokeColor: pip.line
                strokeWidth: 1
                strokeStyle: ShapePath.DashLine
                dashPattern: [3, 3]
                startX: 0; startY: 0.5
                PathLine { x: search.width; y: 0.5 }
              }
            }
          }

          ListView {
            id: rowList
            anchors.top: search.bottom
            anchors.topMargin: pip.px(8)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: pip.px(12)
            anchors.left: parent.left
            anchors.leftMargin: pip.px(8)
            anchors.right: scrollTrack.visible ? scrollTrack.left : parent.right
            anchors.rightMargin: scrollTrack.visible ? pip.px(4) : pip.px(9)
            model: menu.rowsModel
            clip: true
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds

            section.property: "section"
            section.criteria: ViewSection.FullString
            section.delegate: Item {
              required property string section
              width: ListView.view.width
              height: section === "drilldown" ? pip.px(17) : 0
              visible: section === "drilldown"
              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 1
                color: pip.line
              }
            }

            delegate: Item {
              id: row
              required property int index
              required property string itemId
              required property string kind
              required property string icon
              required property string iconFont
              required property string appIcon
              required property string appId
              required property string label
              required property string detail
              required property int childCount

              readonly property bool hasCursor: menu.cursorActive && row.index === menu.selectedIndex
              readonly property bool isApp: row.kind === "app"
              readonly property bool isMenu: row.kind === "menu" || row.kind === "link"

              width: ListView.view.width
              height: Math.max(pip.px(40), labels.implicitHeight + pip.px(14))

              RectangularShadow {
                anchors.fill: rowFill
                visible: row.hasCursor
                radius: rowFill.radius
                blur: pip.px(18)
                spread: 0
                color: Qt.rgba(44 / 255, 174 / 255, 46 / 255, 0.45)
              }

              Rectangle {
                id: rowFill
                anchors.fill: parent
                radius: pip.px(2)
                color: row.hasCursor ? pip.fg : "transparent"
              }

              Item {
                id: iconBox
                width: pip.px(26)
                height: pip.px(26)
                anchors.left: parent.left
                anchors.leftMargin: pip.px(12)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  anchors.centerIn: parent
                  visible: !row.isApp
                  text: row.icon || "•"
                  color: row.hasCursor ? pip.ink : pip.fgDim
                  font.family: row.iconFont.length > 0 ? row.iconFont : pip.glyphFamily
                  font.pixelSize: pip.px(16)
                }

                TintedIcon {
                  anchors.centerIn: parent
                  visible: row.isApp
                  size: pip.px(22)
                  source: row.isApp && menu.appLibrary ? menu.appLibrary.iconSource(row.appIcon) : ""
                  tint: pip.fg
                  inverted: row.hasCursor
                }
              }

              Column {
                id: labels
                anchors.left: iconBox.right
                anchors.leftMargin: pip.px(12)
                anchors.right: trail.left
                anchors.rightMargin: pip.px(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: pip.px(1)

                Text {
                  width: parent.width
                  text: row.label
                  color: row.hasCursor ? pip.ink : pip.fg
                  font.family: pip.textFamily
                  font.pixelSize: pip.px(16.3)
                  font.letterSpacing: pip.em(pip.px(16.3), 0.09)
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  visible: row.detail.length > 0
                  text: row.detail
                  color: row.hasCursor ? pip.ink : pip.fgDim
                  font.family: pip.textFamily
                  font.pixelSize: pip.px(11.5)
                  font.letterSpacing: pip.em(pip.px(11.5), 0.04)
                  elide: Text.ElideRight
                }
              }

              Text {
                id: trail
                anchors.right: parent.right
                anchors.rightMargin: pip.px(12)
                anchors.verticalCenter: parent.verticalCenter
                text: row.isMenu ? "›" : ""
                color: row.hasCursor ? pip.ink : pip.fgDim
                font.family: pip.textFamily
                font.pixelSize: pip.px(16)
              }

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: menu.selectFromPointer(row.index, row, { x: rowMouse.mouseX, y: rowMouse.mouseY })
                onPositionChanged: function(mouse) { menu.selectFromPointer(row.index, row, mouse) }
                onClicked: {
                  menu.cursorActive = true
                  menu.selectedIndex = row.index
                  menu.activateIndex(row.index, true)
                }
              }
            }

            Column {
              anchors.centerIn: parent
              visible: menu.rowsModel.count === 0
              spacing: pip.px(4)

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: menu.filterText ? "NO ITEMS FOUND" : "NO DATA"
                color: pip.fg
                font.family: pip.textFamily
                font.pixelSize: pip.px(16.3)
                font.letterSpacing: pip.em(pip.px(16.3), 0.09)
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: menu.filterText.length > 0
                text: "Adjust your search"
                color: pip.fgDim
                font.family: pip.textFamily
                font.pixelSize: pip.px(11.5)
              }
            }
          }

          Rectangle {
            id: scrollTrack
            visible: rowList.contentHeight > rowList.height
            anchors.top: rowList.top
            anchors.bottom: rowList.bottom
            anchors.right: parent.right
            anchors.rightMargin: 1
            width: pip.px(12)
            color: Qt.rgba(44 / 255, 174 / 255, 46 / 255, 0.07)

            Rectangle {
              width: 1
              height: parent.height
              color: pip.line
            }

            Rectangle {
              x: pip.px(3)
              width: parent.width - pip.px(6)
              readonly property real span: Math.max(rowList.contentHeight, rowList.height, 1)
              y: Math.min(parent.height - height, Math.max(0, (rowList.contentY - rowList.originY) / span * parent.height))
              height: Math.max(pip.px(20), rowList.height / span * parent.height)
              color: thumbMouse.containsMouse || thumbMouse.pressed ? pip.fg : pip.fgDim
            }

            MouseArea {
              id: thumbMouse
              anchors.fill: parent
              hoverEnabled: true
              function scrollTo(y) {
                var ratio = Math.max(0, Math.min(1, y / height))
                rowList.contentY = rowList.originY + ratio * Math.max(0, rowList.contentHeight - rowList.height)
              }
              onPressed: function(mouse) { scrollTo(mouse.y) }
              onPositionChanged: function(mouse) { if (pressed) scrollTo(mouse.y) }
            }
          }
        }

        Item {
          id: detailPane
          anchors.left: listColumn.right
          anchors.right: parent.right
          height: parent.height

          Column {
            id: detailStack
            anchors.centerIn: parent
            width: parent.width - pip.px(44)
            spacing: 0

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              visible: !pip.current
              text: "NO DATA"
              color: pip.fgDim
              font.family: pip.textFamily
              font.pixelSize: pip.px(16)
              font.letterSpacing: pip.em(pip.px(16), 0.24)
              bottomPadding: pip.px(16)
            }

            Item {
              anchors.horizontalCenter: parent.horizontalCenter
              visible: !!pip.current
              width: pip.px(64)
              height: pip.current && pip.current.kind === "app" ? pip.px(64) + pip.px(16) : glyph.implicitHeight + pip.px(14)

              TintedIcon {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !!pip.current && pip.current.kind === "app"
                size: pip.px(64)
                source: pip.current && pip.current.kind === "app" && menu.appLibrary ? menu.appLibrary.iconSource(pip.current.appIcon) : ""
                tint: pip.fg
                glowColor: Qt.rgba(44 / 255, 174 / 255, 46 / 255, 0.35)
              }

              GlowText {
                id: glyph
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !!pip.current && pip.current.kind !== "app"
                text: pip.current ? (pip.current.icon || "•") : ""
                color: pip.fg
                opacity: 0.85
                family: pip.current && pip.current.iconFont ? pip.current.iconFont : pip.glyphFamily
                size: pip.px(38.4)
                glowColor: pip.glow
              }
            }

            GlowText {
              anchors.horizontalCenter: parent.horizontalCenter
              visible: !!pip.current
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: pip.current ? pip.current.label : ""
              color: pip.fgBright
              family: pip.textFamily
              size: pip.px(24.8)
              spacing: pip.em(size, 0.1)
              glowColor: pip.glow
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              visible: !!pip.current
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              topPadding: pip.px(12)
              bottomPadding: pip.px(20)
              lineHeight: 1.65
              text: pip.current && pip.current.detail ? pip.current.detail : ""
              color: pip.fg
              font.family: pip.textFamily
              font.pixelSize: pip.px(14.7)
            }

            Grid {
              anchors.horizontalCenter: parent.horizontalCenter
              columns: 2
              columnSpacing: pip.px(18)
              rowSpacing: pip.px(7)
              bottomPadding: visible ? pip.px(4) : 0
              visible: !!pip.current && (pip.current.kind === "menu" || pip.current.kind === "link" || pip.current.label.indexOf("✓") >= 0)

              Text {
                visible: !!pip.current && (pip.current.kind === "menu" || pip.current.kind === "link")
                text: "ENTRIES"
                color: pip.fgDim
                font.family: pip.textFamily
                font.pixelSize: pip.px(12.8)
                font.letterSpacing: pip.em(pip.px(12.8), 0.16)
              }
              Text {
                visible: !!pip.current && (pip.current.kind === "menu" || pip.current.kind === "link")
                text: pip.current ? String(pip.current.childCount) : ""
                color: pip.fgBright
                font.family: pip.textFamily
                font.pixelSize: pip.px(12.8)
                font.letterSpacing: pip.em(pip.px(12.8), 0.06)
              }
              Text {
                visible: !!pip.current && pip.current.label.indexOf("✓") >= 0
                text: "STATUS"
                color: pip.fgDim
                font.family: pip.textFamily
                font.pixelSize: pip.px(12.8)
                font.letterSpacing: pip.em(pip.px(12.8), 0.16)
              }
              Text {
                visible: !!pip.current && pip.current.label.indexOf("✓") >= 0
                text: "ACTIVE"
                color: pip.fgBright
                font.family: pip.textFamily
                font.pixelSize: pip.px(12.8)
                font.letterSpacing: pip.em(pip.px(12.8), 0.06)
              }
            }

            Item {
              id: gifBox
              anchors.horizontalCenter: parent.horizontalCenter
              readonly property string src: pip.gifFor(pip.artSection)
              visible: src.length > 0
              width: Math.min(parent.width, pip.px(600))
              height: gif.sourceSize.width > 0 ? width * gif.sourceSize.height / gif.sourceSize.width : 0

              AnimatedImage {
                id: gif
                anchors.fill: parent
                source: gifBox.src
                playing: pip.visible
                fillMode: Image.PreserveAspectFit
                visible: false
                cache: false
              }

              MultiEffect {
                anchors.fill: gif
                source: gif
                colorization: 1.0
                colorizationColor: pip.gifInk
                shadowEnabled: true
                shadowColor: Qt.rgba(44 / 255, 174 / 255, 46 / 255, 0.6)
                shadowBlur: 0.5
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
                autoPaddingEnabled: true
              }
            }
          }
        }
      }

      Rectangle {
        id: tabs
        width: parent.width
        height: pip.px(40)
        color: Qt.rgba(44 / 255, 174 / 255, 46 / 255, 0.04)

        Rectangle {
          width: parent.width
          height: 1
          color: pip.lineStrong
          z: 2
        }

        Row {
          anchors.fill: parent
          anchors.topMargin: 1

          Repeater {
            model: pip.sections
            delegate: Item {
              id: tab
              required property var modelData
              required property int index
              readonly property bool current: modelData.id === pip.currentSection
              width: tabs.width / Math.max(1, pip.sections.length)
              height: parent.height

              Rectangle {
                anchors.fill: parent
                visible: tab.current
                gradient: Gradient {
                  GradientStop { position: 0.0; color: Qt.rgba(44 / 255, 174 / 255, 46 / 255, 0.2) }
                  GradientStop { position: 1.0; color: Qt.rgba(44 / 255, 174 / 255, 46 / 255, 0.04) }
                }
              }

              Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: pip.px(3)
                visible: tab.current
                color: pip.fg
              }

              Rectangle {
                anchors.right: parent.right
                width: 1
                height: parent.height
                visible: tab.index < pip.sections.length - 1
                color: pip.line
              }

              GlowText {
                anchors.centerIn: parent
                text: String(tab.modelData.label || tab.modelData.id).toUpperCase()
                color: tab.current || tabMouse.containsMouse ? pip.fgBright : pip.fgDim
                family: pip.textFamily
                size: pip.px(12.5)
                spacing: pip.em(size, 0.12)
                glowColor: tab.current ? pip.glow : "transparent"
              }

              MouseArea {
                id: tabMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: menu.openSection(tab.modelData.id)
              }
            }
          }
        }
      }
    }

    RollWipe {
      id: rollWipe
      anchors.fill: parent
      z: 60
    }
  }
}
