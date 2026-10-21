import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Window {
    id: lyricWin

    property var lyricLines: []
    property int currentLyricIndex: -1
    property bool showTranslation: true
    property string songTitle: ""
    property string songArtist: ""

    property bool locked: false
    property bool hovered: false
    property real fontSize: 30

    // 压在暗底上的文字色：主行用纸白，副行用提亮后的主题色，
    // 保证换成深色主题色时也能看清。
    readonly property color accentLight: {
        var h = Theme.accent.hslHue
        if (h < 0) h = 0
        return Qt.hsla(h, Math.min(0.85, Theme.accent.hslSaturation), 0.70, 1)
    }

    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
    color: "transparent"
    width: 900
    height: 130

    readonly property var currentLine: {
        if (currentLyricIndex < 0 || currentLyricIndex >= lyricLines.length) return null
        return lyricLines[currentLyricIndex]
    }

    readonly property string mainText: currentLine ? currentLine.text : ""
    readonly property string transText: (currentLine && showTranslation)
                                        ? (currentLine.translated || "")
                                        : ""

    Component.onCompleted: {
        x = (Screen.width - width) / 2
        y = Screen.height - height - 150
    }

    // ★ 退出应用时立即关闭
    Component.onDestruction: {
        if (lyricWin.visible) lyricWin.close()
    }

    // ★ hover 检测用 HoverHandler，不受子级 MouseArea 干扰
    HoverHandler {
        id: hoverHandler
        onHoveredChanged: lyricWin.hovered = hovered
    }

    // ============================================================
    // 底板：直角终端条 + 左侧信号条
    // ============================================================
    Rectangle {
        anchors.fill: parent
        radius: 0
        color: "#0C0D0B"
        opacity: lyricWin.hovered ? 0.95 : 0.88
        border.width: 1
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g,
                              Theme.accent.b, 0.62)
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: 2
            radius: 0
            color: Theme.accent
        }
    }

    // 拖拽 / 右键
    MouseArea {
        id: dragArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: lyricWin.locked ? Qt.ArrowCursor : Qt.SizeAllCursor

        property real dragStartX: 0
        property real dragStartY: 0
        property bool dragging: false

        onPressed: (mouse) => {
            if (mouse.button === Qt.LeftButton && !lyricWin.locked) {
                dragStartX = mouse.x
                dragStartY = mouse.y
                dragging = true
            }
        }

        onPositionChanged: (mouse) => {
            if (dragging && (mouse.buttons & Qt.LeftButton)) {
                lyricWin.x += mouse.x - dragStartX
                lyricWin.y += mouse.y - dragStartY
            }
        }

        onReleased: dragging = false

        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton)
                lyricWin.locked = !lyricWin.locked
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton)
                contextMenu.popup()
        }
    }

    // ============================================================
    // 角标：左上 LYRIC / 左下 LOCK 状态
    // ============================================================
    Text {
        anchors {
            left: parent.left
            top: parent.top
            leftMargin: 16
            topMargin: 8
        }
        text: "LYRIC"
        color: lyricWin.accentLight
        opacity: 0.8
        font {
            family: Theme.monoFamily
            pixelSize: Theme.microSize
            letterSpacing: 2.4
        }
    }

    Text {
        anchors {
            left: parent.left
            bottom: parent.bottom
            leftMargin: 16
            bottomMargin: 7
        }
        text: lyricWin.locked ? "LOCK" : "FREE"
        color: lyricWin.locked ? lyricWin.accentLight : "#7E8076"
        opacity: 0.8
        font {
            family: Theme.monoFamily
            pixelSize: Theme.microSize
            letterSpacing: 1.6
        }
    }

    // ============================================================
    // 歌词内容
    // ============================================================
    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 18
        anchors.bottomMargin: 18
        anchors.leftMargin: 64
        anchors.rightMargin: 64
        spacing: 6

        Item { Layout.fillHeight: true }

        Text {
            Layout.fillWidth: true
            text: lyricWin.mainText
            color: "#F6F4EE"
            font {
                family: Theme.fontFamily
                pixelSize: Theme.fs(lyricWin.fontSize)
                bold: true
            }
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            style: Text.Outline
            styleColor: "#000000"
            visible: text !== ""
        }

        Text {
            Layout.fillWidth: true
            text: lyricWin.transText
            color: lyricWin.accentLight
            font {
                family: Theme.fontFamily
                pixelSize: Theme.fs(Math.round(lyricWin.fontSize * 0.6))
            }
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            style: Text.Outline
            styleColor: "#000000"
            visible: text !== ""
        }

        Item { Layout.fillHeight: true }
    }

    // 无歌词提示
    Text {
        anchors.centerIn: parent
        text: lyricWin.songTitle !== ""
              ? "♪ " + lyricWin.songTitle
              : "♪ 暂无歌词"
        color: "#F6F4EE"
        font {
            family: Theme.fontFamily
            pixelSize: Theme.fs(Math.round(lyricWin.fontSize * 0.7))
        }
        style: Text.Outline
        styleColor: "#000000"
        opacity: 0.75
        visible: lyricWin.mainText === ""
        elide: Text.ElideRight
        width: parent.width - 120
        horizontalAlignment: Text.AlignHCenter
    }

    // ============================================================
    // 内联组件：直角小按钮
    // ============================================================
    component LyricButton: Rectangle {
        id: lb

        property string label: ""
        property bool on: false
        property bool dangerOnHover: false

        signal clicked()

        width: 24
        height: 24
        radius: 0
        color: lbArea.containsMouse
               ? (lb.dangerOnHover ? "#24A3413A" : "#1AFFFFFF")
               : "transparent"
        border.width: 1
        border.color: lb.on
                      ? lyricWin.accentLight
                      : (lbArea.containsMouse
                         ? (lb.dangerOnHover ? "#C9736A" : "#66FFFFFF")
                         : "#38FFFFFF")
        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on border.color { ColorAnimation { duration: 100 } }

        Text {
            anchors.centerIn: parent
            text: lb.label
            color: lb.on ? lyricWin.accentLight
                         : (lb.dangerOnHover && lbArea.containsMouse
                            ? "#F0B4AC" : "#E7E5DC")
            font {
                family: Theme.fontFamily
                pixelSize: 11
                bold: lb.on
            }
        }

        MouseArea {
            id: lbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: lb.clicked()
        }
    }

    // ============================================================
    // 右上角悬浮按钮：翻译 / 锁定 / 关闭
    // ============================================================
    Row {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 4
        opacity: lyricWin.hovered ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 160 } }

        LyricButton {
            label: "译"
            on: lyricWin.showTranslation
            onClicked: lyricWin.showTranslation = !lyricWin.showTranslation
        }

        LyricButton {
            label: lyricWin.locked ? "解" : "锁"
            on: lyricWin.locked
            onClicked: lyricWin.locked = !lyricWin.locked
        }

        LyricButton {
            label: "✕"
            dangerOnHover: true
            onClicked: appSettings.desktopLyricEnabled = false
        }
    }

    // ============================================================
    // 右键菜单
    // ============================================================
    Menu {
        id: contextMenu
        width: 210
        padding: 4

        background: Rectangle {
            implicitWidth: 210
            radius: 0
            color: Theme.panel
            border.color: Theme.border
            border.width: 1
        }

        component FlatMenuItem: MenuItem {
            id: fmi
            implicitHeight: 30

            background: Rectangle {
                anchors.fill: parent
                radius: 0
                color: fmi.highlighted ? Theme.hover : "transparent"

                Rectangle {
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }
                    width: 2
                    radius: 0
                    color: Theme.accent
                    opacity: fmi.highlighted ? 1 : 0
                }
            }

            contentItem: Text {
                text: fmi.text
                color: fmi.enabled ? Theme.text : Theme.textMuted
                font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                verticalAlignment: Text.AlignVCenter
                leftPadding: 12
                rightPadding: 12
                elide: Text.ElideRight
            }
        }

        component FlatSeparator: MenuSeparator {
            padding: 5
            contentItem: Rectangle {
                implicitWidth: 180
                implicitHeight: 1
                color: Theme.borderLight
            }
        }

        FlatMenuItem {
            text: lyricWin.locked ? "解锁位置" : "锁定位置"
            onTriggered: lyricWin.locked = !lyricWin.locked
        }

        FlatSeparator {}

        FlatMenuItem {
            text: "增大字号"
            onTriggered: lyricWin.fontSize = Math.min(80, lyricWin.fontSize + 4)
        }

        FlatMenuItem {
            text: "减小字号"
            onTriggered: lyricWin.fontSize = Math.max(16, lyricWin.fontSize - 4)
        }

        FlatMenuItem {
            text: "重置字号"
            onTriggered: lyricWin.fontSize = 30
        }

        FlatSeparator {}

        FlatMenuItem {
            text: lyricWin.showTranslation ? "隐藏翻译" : "显示翻译"
            onTriggered: lyricWin.showTranslation = !lyricWin.showTranslation
        }

        FlatSeparator {}

        FlatMenuItem {
            text: "隐藏桌面歌词"
            onTriggered: appSettings.desktopLyricEnabled = false
        }
    }
}
