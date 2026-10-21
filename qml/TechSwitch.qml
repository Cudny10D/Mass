import QtQuick

// ============================================================
// 终端风开关
//
// 不用系统 Switch 的圆角胶囊 + 圆形滑块：这里是
//   等宽 ON/OFF 字样 + 1px 描边的直角轨道 + 直角滑块
// 开启时轨道整块填橄榄绿，滑块反白。
//
// 点击只发 clicked()，不直接改 checked，
// 由外部写回真实设置值 —— 这样 checked 的绑定不会被破坏，
// 「RESET」按钮改配置时开关也能跟着动。
// ============================================================
Item {
    id: root

    property bool checked: false
    signal clicked()

    implicitWidth: 64
    implicitHeight: 22

    opacity: enabled ? 1.0 : 0.35
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

    readonly property bool hovered: mouse.containsMouse

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        text: root.checked ? "ON" : "OFF"
        color: root.checked ? Theme.accentHover
                            : (root.hovered ? Theme.textDim : Theme.textMuted)
        font {
            family: Theme.monoFamily
            pixelSize: Theme.microSize
            letterSpacing: 1
        }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    Rectangle {
        id: track
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 16
        antialiasing: false
        color: root.checked ? Theme.accent : "transparent"
        border.width: 1
        border.color: root.checked
                      ? (root.hovered ? Theme.accentHover : Theme.accent)
                      : (root.hovered ? Theme.textDim : Theme.border)
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        // 直角滑块
        Rectangle {
            width: 8
            height: 8
            y: (parent.height - height) / 2
            x: root.checked ? parent.width - width - 3 : 3
            antialiasing: false
            color: root.checked
                   ? Theme.ink
                   : (root.hovered ? Theme.textDim : Theme.textMuted)
            Behavior on x {
                NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
            }
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
