import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root

    signal playListRequested(var songs, int index)

    function coverSource(cover) {
        if (!cover || cover === "") return ""
        if (cover.startsWith("http://")
                || cover.startsWith("https://")
                || cover.startsWith("file://")
                || cover.startsWith("qrc:")) {
            return cover
        }
        return "file:///" + cover
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // 顶部栏
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 56

                RowLayout {
                    anchors { fill: parent; leftMargin: 96; rightMargin: 32 }
                    spacing: 12

                    Text {
                        text: "播放历史"
                        color: Theme.text
                        font {
                            family: Theme.fontFamily
                            pixelSize: Theme.fs(18)
                            bold: true
                        }
                        Layout.fillWidth: true
                    }

                    Text {
                        text: historyManager.count + " 首"
                        color: Theme.textDim
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                    }

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 32
                        radius: 16
                        color: clearBtn.containsMouse ? Theme.danger : "transparent"
                        border.color: clearBtn.containsMouse ? "transparent" : Theme.border
                        border.width: clearBtn.containsMouse ? 0 : 1
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            anchors.centerIn: parent
                            text: "清空"
                            color: clearBtn.containsMouse
                                   ? "#ffffff"
                                   : Theme.textDim
                            font {
                                family: Theme.fontFamily
                                pixelSize: Theme.fs(12)
                                bold: clearBtn.containsMouse
                            }
                        }

                        MouseArea {
                            id: clearBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: historyManager.clear()
                        }
                    }
                }
            }

            // 内容区
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // 空状态
                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    visible: historyManager.count === 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "⟲"
                        color: Theme.textMuted
                        font.pixelSize: 56
                        opacity: 0.4
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "还没有播放记录"
                        color: Theme.textDim
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(14) }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "播放任意歌曲后，会自动记录在这里"
                        color: Theme.textMuted
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                    }
                }

                // 历史网格
                GridView {
                    id: historyGrid
                    anchors.fill: parent
                    anchors.leftMargin: 96
                    anchors.rightMargin: 32
                    anchors.topMargin: 8
                    anchors.bottomMargin: 0
                    clip: true
                    visible: historyManager.count > 0

                    property int columns: 5
                    property int gap: 24

                    // cell 平分可视宽度，最后一列贴合右边界，保证可点击
                    cellWidth: width / columns
                    cellHeight: cellWidth + 64

                    model: historyManager.history

                    delegate: Item {
                        width: historyGrid.cellWidth
                        height: historyGrid.cellHeight
                        property bool isHover: hArea.containsMouse

                        Column {
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                leftMargin: historyGrid.gap / 2
                                rightMargin: historyGrid.gap / 2
                            }
                            spacing: 6

                            Item {
                                id: coverItem
                                width: parent.width
                                height: parent.width

                                property real cornerRadius: 10

                                Rectangle {
                                    anchors.fill: parent
                                    radius: coverItem.cornerRadius
                                    color: Theme.panelAlt
                                }

                                Image {
                                    id: coverImg
                                    anchors.fill: parent
                                    source: root.coverSource(modelData.cover)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize.width: 400
                                    sourceSize.height: 400
                                    visible: false
                                    layer.enabled: true
                                }

                                Item {
                                    id: coverMaskSource
                                    anchors.fill: parent
                                    visible: false
                                    layer.enabled: true

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: coverItem.cornerRadius
                                        color: "white"
                                    }
                                }

                                MultiEffect {
                                    anchors.fill: parent
                                    source: coverImg
                                    visible: coverImg.status === Image.Ready
                                    maskEnabled: true
                                    maskSource: coverMaskSource
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "♪"
                                    color: Theme.textMuted
                                    font.pixelSize: 28
                                    visible: coverImg.status !== Image.Ready
                                }

                                transform: Scale {
                                    origin.x: coverItem.width / 2
                                    origin.y: coverItem.height / 2
                                    xScale: isHover ? 1.03 : 1.0
                                    yScale: isHover ? 1.03 : 1.0
                                    Behavior on xScale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    Behavior on yScale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: coverItem.cornerRadius
                                    color: "#000000"
                                    opacity: isHover ? 0.35 : 0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 36; height: 36; radius: 18
                                        color: Theme.accent
                                        scale: isHover ? 1.0 : 0.7
                                        opacity: isHover ? 1 : 0
                                        Behavior on scale { NumberAnimation { duration: 220 } }
                                        Behavior on opacity { NumberAnimation { duration: 220 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "▶"
                                            color: Theme.darkMode ? "#000000" : "#ffffff"
                                            font.pixelSize: 14
                                            font.bold: true
                                        }
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                text: modelData.name || ""
                                color: isHover ? Theme.accent : Theme.text
                                font {
                                    family: Theme.fontFamily
                                    pixelSize: Theme.fs(12)
                                    weight: Font.Medium
                                }
                                elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Text {
                                width: parent.width
                                text: modelData.artist || ""
                                color: Theme.textDim
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: hArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                var list = []
                                for (var i = 0; i < historyManager.count; i++) {
                                    var item = historyManager.history[i]
                                    list.push({
                                        cid: item.cid,
                                        name: item.name,
                                        artist: item.artist,
                                        cover: item.cover
                                    })
                                }
                                root.playListRequested(list, index)
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

                // 顶部遮罩
                Rectangle {
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                    height: 80
                    topLeftRadius: Theme.windowFullscreen ? Theme.radiusWindow : 0
                    topRightRadius: Theme.windowFullscreen ? Theme.radiusWindow : 0
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.windowTop(1.0) }
                        GradientStop { position: 0.5; color: Theme.windowTop(0.65) }
                        GradientStop { position: 1.0; color: Theme.windowTop(0.0) }
                    }
                    z: 100
                    enabled: false
                }

                // 底部遮罩
                Rectangle {
                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                    }
                    height: 100
                    bottomLeftRadius: Theme.radiusWindow
                    bottomRightRadius: Theme.radiusWindow
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.windowBottom(0.0) }
                        GradientStop { position: 0.5; color: Theme.windowBottom(0.65) }
                        GradientStop { position: 1.0; color: Theme.windowBottom(1.0) }
                    }
                    z: 100
                    enabled: false
                }
            }
        }
    }
}