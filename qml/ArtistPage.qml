import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var artists: []
    property var currentArtistSongs: []
    property string currentArtistName: ""

    signal songClicked(int songId, string name, string artist, string cover)

    Rectangle {
        anchors.fill: parent
        color: Theme.bg

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // 搜索栏
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                color: Theme.panel

                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 1
                    color: Theme.border
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                    spacing: 8

                    Text {
                        text: "🎤 歌手"
                        color: Theme.text
                        font { family: Theme.fontFamily; pixelSize: 13; bold: true }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        color: Theme.bg
                        radius: Theme.radius
                        border.color: artistInput.activeFocus ? Theme.accent : Theme.border
                        border.width: 1

                        TextInput {
                            id: artistInput
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            font { family: Theme.fontFamily; pixelSize: 12 }
                            selectByMouse: true
                            onAccepted: networkManager.searchArtist(text)
                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "输入歌手名..."
                                color: Theme.textMuted
                                font { family: Theme.fontFamily; pixelSize: 12 }
                                visible: !artistInput.text && !artistInput.activeFocus
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 64; Layout.preferredHeight: 32
                        radius: Theme.radius
                        color: Theme.accent
                        Text {
                            anchors.centerIn: parent; text: "搜索"
                            color: "#ffffff"
                            font { family: Theme.fontFamily; pixelSize: 12 }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: networkManager.searchArtist(artistInput.text)
                        }
                    }
                }
            }

            // 内容
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.currentArtistName === "" ? 0 : 1

                // 歌手列表
                ListView {
                    id: artistList
                    clip: true
                    model: root.artists
                    spacing: 4

                    delegate: Rectangle {
                        width: artistList.width - 24
                        x: 12
                        height: 60
                        radius: Theme.radius
                        color: aArea.containsMouse ? Theme.hover : "transparent"

                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 44
                                Layout.preferredHeight: 44
                                radius: 22
                                color: Theme.panelAlt
                                clip: true
                                Image {
                                    anchors.fill: parent
                                    source: modelData.picUrl || ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: modelData.name
                                    color: Theme.text
                                    font { family: Theme.fontFamily; pixelSize: 13; weight: Font.Medium }
                                }
                                Text {
                                    text: (modelData.alias && modelData.alias.length > 0)
                                          ? modelData.alias.join(" / ")
                                          : "歌手"
                                    color: Theme.textDim
                                    font { family: Theme.fontFamily; pixelSize: 11 }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Text {
                                text: "→"
                                color: Theme.textDim
                                font.pixelSize: 14
                            }
                        }

                        MouseArea {
                            id: aArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.currentArtistName = modelData.name
                                networkManager.getArtistHotSongs(modelData.id)
                            }
                        }
                    }
                }

                // 某歌手的热门歌曲
                ColumnLayout {
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        color: Theme.panelAlt
                        RowLayout {
                            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                            spacing: 8
                            Rectangle {
                                width: 28; height: 28; radius: 14
                                color: backArea.containsMouse ? Theme.hover : "transparent"
                                Text {
                                    anchors.centerIn: parent; text: "←"
                                    color: Theme.text; font.pixelSize: 14
                                }
                                MouseArea {
                                    id: backArea; anchors.fill: parent; hoverEnabled: true
                                    onClicked: root.currentArtistName = ""
                                }
                            }
                            Text {
                                text: root.currentArtistName + " · 热门 50"
                                color: Theme.text
                                font { family: Theme.fontFamily; pixelSize: 13; weight: Font.Medium }
                                Layout.fillWidth: true
                            }
                        }
                    }

                    SongList {
                        id: artistSongList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        onSongClicked: (id, name, artist, cover) =>
                            root.songClicked(id, name, artist, cover)
                    }
                }
            }
        }
    }

    Connections {
        target: networkManager
        function onArtistResultReady(artists) {
            root.artists = artists
            root.currentArtistName = ""
        }
        function onArtistHotSongsReady(artistId, songs) {
            artistSongList.model.clear()
            for (let i = 0; i < songs.length; i++) {
                let s = songs[i]
                artistSongList.model.append({
                    songId: s.id,
                    name: s.name,
                    artist: s.ar ? s.ar.map(a => a.name).join(" / ") : "未知",
                    album: s.al ? s.al.name : "",
                    cover: s.al ? s.al.picUrl : "",
                    duration: s.dt || 0
                })
            }
        }
    }
}