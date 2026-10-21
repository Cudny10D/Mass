import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// ============================================================
// 播放历史：索引条 + 光盘盒网格（与曲目资料库同一套语言）
// ============================================================
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

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.contentSideMargin
        anchors.rightMargin: Theme.contentSideMargin
        spacing: 0

        // 索引条
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 40

            RowLayout {
                anchors.fill: parent
                spacing: 12

                Text {
                    text: "PLAY HISTORY / 播放记录"
                    color: Theme.textDim
                    font {
                        family: Theme.monoFamily
                        pixelSize: Theme.labelSize
                        letterSpacing: 1.8
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.border
                    opacity: 0.55
                }

                Text {
                    text: historyManager.count + " 首"
                    color: Theme.textMuted
                    font {
                        family: Theme.fontFamily
                        pixelSize: Theme.labelSize
                        letterSpacing: 1.2
                    }
                }

                Item {
                    width: 46; height: 24
                    Text {
                        anchors.centerIn: parent
                        text: "清空"
                        color: clearArea.containsMouse ? Theme.danger : Theme.textDim
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(11.5) }
                    }
                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: historyManager.clear()
                    }
                }
            }
        }

        // 内容
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 18
            clip: true

            // 空状态
            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: historyManager.count === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "NO RECORD"
                    color: Theme.textMuted
                    font {
                        family: Theme.monoFamily
                        pixelSize: Theme.fs(13)
                        letterSpacing: 3
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "播放过的曲目会记录在这里"
                    color: Theme.textMuted
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(11.5) }
                }
            }

            GridView {
                id: historyGrid
                anchors.fill: parent
                clip: true
                visible: historyManager.count > 0

                readonly property var metrics: Theme.gridMetrics
                property int columns: metrics.columns
                property int gap: Theme.gridGap

                cellWidth: metrics.cellWidth
                cellHeight: Math.max(1, metrics.cellWidth + 58)

                model: historyManager.history

                delegate: Item {
                    width: historyGrid.cellWidth
                    height: historyGrid.cellHeight
                    property bool isHover: hArea.containsMouse

                    Item {
                        id: coverBox
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            leftMargin: historyGrid.gap / 2
                            rightMargin: historyGrid.gap / 2
                        }
                        height: width

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.panelAlt
                        }

                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            source: root.coverSource(modelData.cover)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize.width: 400
                            sourceSize.height: 400
                            smooth: true
                            mipmap: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.darkMode ? "#26FFFFFF" : "#33000000"
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "#000000"
                            opacity: isHover ? 0.42 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }

                            Text {
                                anchors.centerIn: parent
                                text: "播放 ↗"
                                color: "#F2F0E9"
                                opacity: isHover ? 1 : 0
                                font {
                                    family: Theme.monoFamily
                                    pixelSize: Theme.fs(10)
                                    letterSpacing: 2
                                }
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                            }
                        }
                    }

                    Text {
                        id: numLabel
                        anchors { left: coverBox.left; top: coverBox.bottom; topMargin: 8 }
                        text: (index + 1).toString().padStart(2, "0")
                        color: Theme.textMuted
                        font {
                            family: Theme.monoFamily
                            pixelSize: Theme.microSize
                            letterSpacing: 1
                        }
                    }

                    Text {
                        anchors {
                            left: numLabel.right
                            leftMargin: 10
                            right: coverBox.right
                            top: coverBox.bottom
                            topMargin: 6
                        }
                        text: modelData.name || ""
                        color: Theme.text
                        font {
                            family: Theme.fontFamily
                            pixelSize: Theme.fs(12.5)
                            weight: Font.DemiBold
                        }
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors {
                            left: numLabel.right
                            leftMargin: 10
                            right: coverBox.right
                            top: coverBox.bottom
                            topMargin: 24
                        }
                        text: modelData.artist || ""
                        color: Theme.textMuted
                        font {
                            family: Theme.fontFamily
                            pixelSize: Theme.microSize
                        }
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: hArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
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
                    width: 4
                    contentItem: Rectangle { color: Theme.textMuted; opacity: 0.35 }
                }
            }
        }
    }
}
