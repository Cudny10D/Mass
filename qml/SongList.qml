import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ListView {
    id: listView
    spacing: 4
    topMargin: 8
    bottomMargin: 8
    clip: true

    model: ListModel {}

    signal playListRequested(var songs, int index)
    signal requestDownload(string songCid, string label)

    property string currentSongCid: ""

    delegate: Item {
        width: listView.width
        height: 76

        property bool isCurrent: model.cid === listView.currentSongCid
        property bool isHover: hoverArea.containsMouse

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 16; anchors.rightMargin: 16
            anchors.topMargin: 2; anchors.bottomMargin: 2
            color: isCurrent ? Theme.accentGlow
                             : (isHover ? Theme.hover : "transparent")
            radius: Theme.radius
            Behavior on color { ColorAnimation { duration: 120 } }

            Rectangle {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                width: 3
                height: isCurrent ? 32 : 0
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
            anchors { fill: parent; leftMargin: 32; rightMargin: 32 }
            spacing: 18
            z: 2

            Item {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28

                Text {
                    anchors.centerIn: parent
                    text: (index + 1).toString().padStart(2, "0")
                    color: isCurrent ? Theme.accent
                                     : (isHover ? Theme.text : Theme.textDim)
                    font {
                        family: Theme.fontFamily
                        pixelSize: 13
                        bold: isCurrent || isHover
                    }
                    visible: !isCurrent
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    visible: isCurrent

                    Repeater {
                        model: 3
                        Rectangle {
                            width: 3
                            color: Theme.accent
                            radius: 1.5
                            height: 5 + (index * 3)
                            anchors.verticalCenter: parent.verticalCenter

                            SequentialAnimation on height {
                                running: isCurrent
                                loops: Animation.Infinite
                                NumberAnimation {
                                    to: 18; duration: 400 + index * 80
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    to: 5; duration: 400 + index * 80
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52
                radius: Theme.radius
                color: Theme.panelAlt
                clip: true
                scale: isHover ? 1.06 : 1.0
                Behavior on scale { NumberAnimation { duration: Theme.animFast } }

                Image {
                    anchors.fill: parent
                    source: model.cover || ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: 104
                    sourceSize.height: 104
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    text: "♪"
                    color: Theme.textMuted
                    font.pixelSize: 18
                    visible: !model.cover
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.color: Theme.accent
                    border.width: 1.5
                    visible: isCurrent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: model.name
                    color: isCurrent ? Theme.accent : Theme.text
                    font {
                        family: Theme.fontFamily
                        pixelSize: 15
                        weight: isCurrent ? Font.Bold : Font.Medium
                    }
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
                Text {
                    text: model.artist
                    color: Theme.textDim
                    font { family: Theme.fontFamily; pixelSize: 12 }
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Text {
                text: listView.formatDuration(model.duration)
                color: Theme.textDim
                font { family: Theme.fontFamily; pixelSize: 11 }
            }

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 17
                color: dlBtn.containsMouse ? Theme.accent : "transparent"
                border.color: Theme.border
                border.width: 1
                opacity: isHover ? 1 : 0
                scale: dlBtn.containsMouse ? 1.1 : 1.0
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                Behavior on scale { NumberAnimation { duration: Theme.animFast } }
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text: "↓"
                    color: dlBtn.containsMouse
                           ? (Theme.darkMode ? "#000000" : "#ffffff")
                           : Theme.text
                    font.pixelSize: 14
                }

                MouseArea {
                    id: dlBtn
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true
                    onClicked: {
                        mouse.accepted = true
                        listView.requestDownload(model.cid,
                            model.artist + " - " + model.name)
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: Theme.accent
                opacity: isHover && !isCurrent ? 1 : 0
                scale: isHover && !isCurrent ? 1.0 : 0.8
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "▶"
                    color: Theme.darkMode ? "#000000" : "#ffffff"
                    font { pixelSize: 12; bold: true }
                }

                MouseArea {
                    id: playBtn
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true
                    onClicked: {
                        mouse.accepted = true
                        listView.playCurrentIndex(index)
                    }
                }
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            z: -1
            onClicked: listView.playCurrentIndex(index)
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 32
            anchors.rightMargin: 32
            height: 1
            color: Theme.borderLight
            visible: !isHover && !isCurrent && index < listView.count - 1
            z: 1
        }
    }

    // 把整个列表打包出去
    function playCurrentIndex(idx) {
        let list = []
        for (let i = 0; i < listView.model.count; i++) {
            let item = listView.model.get(i)
            list.push({
                cid: item.cid,
                name: item.name,
                artist: item.artist,
                cover: item.cover
            })
        }
        listView.playListRequested(list, idx)
    }

    ScrollBar.vertical: ScrollBar {
        active: true
        policy: ScrollBar.AsNeeded
        width: 6
        contentItem: Rectangle {
            radius: 3; color: Theme.textMuted; opacity: 0.4
        }
    }

    function formatDuration(ms) {
        if (!ms) return ""
        let s = Math.floor(ms / 1000)
        let m = Math.floor(s / 60); s = s % 60
        return m + ":" + s.toString().padStart(2, "0")
    }
}