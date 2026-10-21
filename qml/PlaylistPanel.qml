import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root

    property bool open: false
    property var queue: []
    property string currentCid: ""

    signal requestClose()
    signal songSelected(int index)

    // ★ 供 Main.qml 使用 —— picker 是否可见
    readonly property bool pickerVisible: pickerDialog.visible

    function closePicker() {
        pickerDialog.close()
    }

    // 遮罩
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.open ? 0.35 : 0
        visible: opacity > 0.01
        enabled: root.open
        Behavior on opacity { NumberAnimation { duration: 260 } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.requestClose()
        }
    }

    // 面板开关时切换进出场动画。窗口尺寸变化不会走到这里，
    // 所以最大化不会把面板误当成一次「打开」。
    onOpenChanged: {
        if (open) {
            panelShift.x = panel.width
            panelOpenAnim.start()
        } else {
            panelCloseAnim.start()
        }
    }

    // 右侧面板
    Item {
        id: panel
        y: 0
        height: parent.height
        width: 380

        // 关键：面板必须锚在窗口右边缘，进出场靠 transform 平移，
        // 而不是去绑 x = parent.width - width。
        // 原来写法的问题是：关闭时面板停在 x = parent.width（窗口外右侧），
        // 这个 x 绑定挂在 parent.width 上，于是**窗口一最大化**，目标值就从
        // 1239 跳到 2560，再加上 Behavior on x 的 360ms 动画 —— 面板就会从
        // 窗口中间一路滑到右边「错位再消失」。锚右边缘后，窗口尺寸变化只是
        // 让面板跟着右边缘走，offset 不受任何影响，也就不会被误触发。
        anchors.right: parent.right
        enabled: root.open

        transform: Translate { id: panelShift; x: root.open ? 0 : panel.width }

        // 只在「开关面板」时做动画；窗口尺寸变化不碰 offset
        NumberAnimation {
            id: panelOpenAnim
            target: panelShift
            property: "x"
            to: 0
            duration: 360
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: panelCloseAnim
            target: panelShift
            property: "x"
            to: panel.width
            duration: 360
            easing.type: Easing.InCubic
        }

        // 阴影
        Rectangle {
            anchors {
                fill: bgRect
                topMargin: 8
                bottomMargin: -8
                leftMargin: -8
                rightMargin: 4
            }
            radius: 0
            color: Theme.shadowDeep
            opacity: 0.22
        }

        // 面板主体
        Rectangle {
            id: bgRect
            anchors {
                fill: parent
                topMargin: 12
                bottomMargin: 12
                leftMargin: 0
                rightMargin: 12
            }
            radius: 0
            color: Theme.bg
            border.width: 1
            border.color: Theme.border

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.panel
                opacity: Theme.darkMode ? 0.85 : 0.92
                z: -1
            }

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                anchors.margins: 1
                height: parent.height * 0.4
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
            anchors.fill: bgRect
            spacing: 0

            // 头部
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 20
                Layout.leftMargin: 24
                Layout.rightMargin: 16
                Layout.bottomMargin: 12
                spacing: 8

                Text {
                    text: "播放列表"
                    color: Theme.text
                    font {
                        family: Theme.fontFamily
                        pixelSize: Theme.fs(18)
                        bold: true
                    }
                    Layout.fillWidth: true
                }

                Text {
                    text: root.queue.length + " 首"
                    color: Theme.textDim
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                }

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 0
                    color: closeBtn.containsMouse ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: Theme.textDim
                        font.pixelSize: Theme.fs(13)
                    }

                    MouseArea {
                        id: closeBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.requestClose()
                    }
                }
            }

            // 空状态
            Column {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignCenter
                spacing: 12
                visible: root.queue.length === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "♫"
                    color: Theme.textMuted
                    font.pixelSize: 48
                    opacity: 0.5
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "播放列表为空"
                    color: Theme.textDim
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                }
            }

            // 队列
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.bottomMargin: 12
                clip: true
                visible: root.queue.length > 0

                ListView {
                    id: queueList
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    clip: true
                    spacing: 2
                    model: root.queue

                    delegate: Item {
                        width: queueList.width
                        height: 56

                        property bool isCurrent: modelData.cid === root.currentCid
                        property bool isHover: rowArea.containsMouse

                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            z: -1
                            onClicked: root.songSelected(index)
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radius
                            color: isCurrent ? Theme.accentGlow
                                             : (isHover ? Theme.hover : "transparent")
                            Behavior on color { ColorAnimation { duration: 120 } }
                            z: -1

                            Rectangle {
                                anchors {
                                    left: parent.left
                                    verticalCenter: parent.verticalCenter
                                }
                                width: 3
                                height: isCurrent ? 24 : 0
                                radius: 1.5
                                color: Theme.accent
                                Behavior on height {
                                    NumberAnimation {
                                        duration: Theme.animNormal
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                            spacing: 12
                            z: 1

                            Text {
                                Layout.preferredWidth: 22
                                text: (index + 1).toString().padStart(2, "0")
                                color: isCurrent
                                       ? Theme.accent
                                       : (isHover ? Theme.text : Theme.textDim)
                                font {
                                    family: Theme.fontFamily
                                    pixelSize: Theme.fs(12)
                                    bold: isCurrent
                                }
                                horizontalAlignment: Text.AlignHCenter
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Rectangle {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                radius: 0
                                color: Theme.panelAlt
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: modelData.cover || ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize.width: 72
                                    sourceSize.height: 72
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "♪"
                                    color: Theme.textMuted
                                    font.pixelSize: 14
                                    visible: !modelData.cover
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: modelData.name || ""
                                    color: isCurrent ? Theme.accent : Theme.text
                                    font {
                                        family: Theme.fontFamily
                                        pixelSize: Theme.fs(13)
                                        weight: isCurrent ? Font.Bold : Font.Medium
                                    }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                Text {
                                    text: modelData.artist || ""
                                    color: Theme.textDim
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                }
                            }

                            // 添加到歌单按钮
                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: 0
                                color: addBtnArea.containsMouse ? Theme.accent : "transparent"
                                border.color: Theme.border
                                border.width: addBtnArea.containsMouse ? 0 : 1
                                opacity: isHover ? 1 : 0.4
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    color: addBtnArea.containsMouse
                                           ? (Theme.ink)
                                           : Theme.textDim
                                    font {
                                        family: Theme.fontFamily
                                        pixelSize: Theme.fs(15)
                                        bold: true
                                    }
                                }

                                MouseArea {
                                    id: addBtnArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    onClicked: {
                                        mouse.accepted = true
                                        pickerDialog.openFor(
                                            modelData.cid,
                                            modelData.name,
                                            modelData.artist,
                                            modelData.cover
                                        )
                                    }
                                }
                            }

                            // 播放指示
                            Text {
                                Layout.preferredWidth: 18
                                text: isCurrent ? "▶" : ""
                                color: Theme.accent
                                font.pixelSize: Theme.fs(12)
                                horizontalAlignment: Text.AlignHCenter
                                visible: isCurrent
                            }
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        active: true
                        policy: ScrollBar.AsNeeded
                        width: 6
                        contentItem: Rectangle {
                            radius: 3
                            color: Theme.textMuted
                            opacity: 0.4
                        }
                    }
                }
            }
        }
    }

    PlaylistPickerDialog {
        id: pickerDialog
    }
}