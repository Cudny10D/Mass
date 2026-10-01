import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    parent: Overlay.overlay
    anchors.fill: parent
    visible: opacity > 0.01
    opacity: 0
    z: 2000

    property string songCid: ""
    property string songName: ""
    property string songArtist: ""
    property string songCover: ""

    function openFor(cid, name, artist, cover) {
        songCid = cid
        songName = name
        songArtist = artist
        songCover = cover
        opacity = 1
    }

    function close() {
        opacity = 0
    }

    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    // 遮罩
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.5
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    // 弹窗本体
    Rectangle {
        anchors.centerIn: parent
        width: 400
        height: 480
        radius: Theme.radiusLarge
        color: Theme.panel
        border.color: Theme.border
        border.width: 1

        scale: root.opacity > 0.5 ? 1.0 : 0.85
        Behavior on scale {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutBack
            }
        }

        ColumnLayout {
            anchors { fill: parent; margins: 24 }
            spacing: 14

            // 标题
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "添加到歌单"
                    color: Theme.text
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(16); bold: true }
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 14
                    color: topCloseBtn.containsMouse ? Theme.hover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: Theme.textDim
                        font.pixelSize: Theme.fs(12)
                    }

                    MouseArea {
                        id: topCloseBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.close()
                    }
                }
            }

            // 歌曲信息
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: 8
                    color: Theme.panelAlt
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.songCover || ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "♪"
                        color: Theme.textMuted
                        font.pixelSize: 14
                        visible: !root.songCover
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: root.songName
                        color: Theme.text
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(13); weight: Font.Medium }
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: root.songArtist
                        color: Theme.textDim
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            // 分隔线
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.borderLight
                opacity: 0.5
            }

            // 新建歌单按钮
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: Theme.radius
                color: newBtn.containsMouse ? Theme.accentHover : Theme.accent
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: "+"
                        color: Theme.darkMode ? "#000000" : "#ffffff"
                        font.pixelSize: Theme.fs(18); font.bold: true
                    }
                    Text {
                        text: "新建歌单并添加"
                        color: Theme.darkMode ? "#000000" : "#ffffff"
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                    }
                }

                MouseArea {
                    id: newBtn
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        let newId = playlistManager.createPlaylist("新歌单")
                        playlistManager.addSong(newId, root.songCid,
                                                 root.songName, root.songArtist,
                                                 root.songCover)
                        root.close()
                    }
                }
            }

            // 歌单列表
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    visible: playlistManager.playlists.length === 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "♫"
                        color: Theme.textMuted
                        font.pixelSize: 40
                        opacity: 0.4
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "还没有歌单"
                        color: Theme.textDim
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                    }
                }

                ListView {
                    id: plList
                    anchors.fill: parent
                    clip: true
                    spacing: 4
                    visible: playlistManager.playlists.length > 0
                    model: playlistManager.playlists

                    delegate: Rectangle {
                        width: plList.width
                        height: 52
                        radius: Theme.radius
                        color: plArea.containsMouse ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                            spacing: 10

                            Text {
                                text: "♫"
                                color: Theme.accent
                                font.pixelSize: Theme.fs(15)
                            }

                            Text {
                                text: modelData.name || "未命名"
                                color: Theme.text
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: (modelData.songs ? modelData.songs.length : 0) + " 首"
                                color: Theme.textDim
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                            }
                        }

                        MouseArea {
                            id: plArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                console.log("[Picker] adding to playlist:", modelData.name)
                                let ok = playlistManager.addSong(
                                    modelData.id, root.songCid,
                                    root.songName, root.songArtist,
                                    root.songCover)
                                console.log("[Picker] addSong result:", ok)
                                root.close()
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
}