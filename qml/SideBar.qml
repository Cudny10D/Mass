import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root

    property bool hovered: false
    property int collapsedWidth: 52
    property int expandedWidth: 68

    width: hovered ? expandedWidth : collapsedWidth
    height: 5 * 52 + 24
    clip: false

    Behavior on width {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    signal pageChanged(string page)
    property string currentPage: "siren"

    Rectangle {
        id: glowSource
        anchors.centerIn: pill
        width: pill.width + 48
        height: pill.height + 48
        radius: width / 2
        color: Theme.darkMode ? "#60ffffff" : "#40000000"
        visible: false
        layer.enabled: true
        enabled: false
    }

    MultiEffect {
        source: glowSource
        anchors.fill: glowSource
        blurEnabled: true
        blur: 1.5
        blurMax: 96
        opacity: root.hovered ? 0.85 : 0.6
        enabled: false
        Behavior on opacity { NumberAnimation { duration: 220 } }
    }

    HoverHandler {
        id: dockHoverHandler
        onHoveredChanged: {
            if (hovered) {
                root.hovered = true
                collapseTimer.stop()
            } else {
                collapseTimer.restart()
            }
        }
    }

    Timer {
        id: collapseTimer
        interval: 220
        onTriggered: root.hovered = false
    }

    Rectangle {
        anchors.fill: pill
        anchors.topMargin: 8
        anchors.bottomMargin: -8
        anchors.leftMargin: 2
        anchors.rightMargin: -2
        radius: pill.radius
        color: Theme.shadowDeep
        opacity: root.hovered ? 0.5 : 0.35
        enabled: false
        Behavior on opacity { NumberAnimation { duration: 220 } }
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        radius: width / 2
        clip: false

        // ★ 亮色模式：未 hover 0.65，hover 0.85
        opacity: root.hovered
                 ? (Theme.darkMode ? 1.0 : 0.85)
                 : (Theme.darkMode ? 0.78 : 0.65)
        Behavior on opacity { NumberAnimation { duration: 220 } }

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.gradientGlass[0] }
            GradientStop { position: 1.0; color: Theme.gradientGlass[1] }
        }

        // ★ 亮色模式 0.9 → 0.6，让面板更通透
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.sideBar
            opacity: Theme.darkMode ? 0.78 : 0.6
            z: -1
            enabled: false
        }

        Rectangle {
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            anchors.margins: 1
            width: parent.width * 0.55
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.glassHighlight }
                GradientStop { position: 1.0; color: "#00ffffff" }
            }
            opacity: 0.3
            enabled: false
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: [
                { id: "siren",    icon: "◈" },
                { id: "search",   icon: "⌕" },
                { id: "history",  icon: "⟲" },
                { id: "playlist", icon: "♫" },
                { id: "settings", icon: "⚙" }
            ]

            delegate: Item {
                id: iconItem
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48

                property bool isActive: root.currentPage === modelData.id
                property bool isHover: itemArea.containsMouse
                property bool isEmphasized: isActive || isHover

                Rectangle {
                    anchors.centerIn: parent
                    width: 46
                    height: 46
                    radius: width / 2
                    color: isActive ? Theme.accent
                                    : (isHover ? Theme.hover : "transparent")

                    scale: isEmphasized ? 1.18 : 0.8
                    Behavior on scale {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        anchors.margins: 1
                        height: parent.height / 2
                        radius: parent.radius
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#30ffffff" }
                            GradientStop { position: 1.0; color: "#00ffffff" }
                        }
                        visible: isActive
                        opacity: Theme.darkMode ? 0.5 : 0.15
                        enabled: false
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: modelData.icon
                    color: isActive
                           ? (Theme.darkMode ? "#000000" : "#ffffff")
                           : (isHover ? Theme.text : Theme.textDim)
                    font {
                        family: Theme.fontFamily
                        pixelSize: Theme.fs(20)
                        bold: isActive
                    }
                    scale: isEmphasized ? 1.2 : 0.95
                    Behavior on scale {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: itemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        // 只发信号，由 Main.qml 修改 viewMode，
                        // 再通过 currentPage: root.viewMode 的绑定同步回来。
                        // 不要在这里直接给 currentPage 赋值，否则会打断绑定。
                        root.pageChanged(modelData.id)
                    }
                }
            }
        }
    }
}