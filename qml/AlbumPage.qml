import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var albums: []
    property string currentAlbumName: ""
    signal songClicked(int songId, string name, string artist, string cover)

    Rectangle {
        anchors.fill: parent
        color: Theme.bg

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                color: Theme.panel

                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 1; color: Theme.border
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                    spacing: 8
                    Text {
                        text: "💿 专辑"
                        color: Theme.text
                        font { family: Theme.fontFamily; pixelSize: 13; bold: true }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        color: Theme.bg
                        radius: Theme.radius
                        border.color: albumInput.activeFocus ? Theme.accent : Theme.border
                        border.width: 1
                        TextInput {
                            id: albumInput
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            font { family: Theme.fontFamily; pixelSize: 12 }
                            selectByMouse: true
                            onAccepted: networkManager.searchAlbum(text)
                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "输入专辑名..."
                                color: Theme.textMuted
                                font { family: Theme.fontFamily; pixelSize: 12 }
                                visible: !albumInput.text && !albumInput.activeFocus
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
                            onClicked: networkManager.searchAlbum(albumInput.text)
                        }
                    }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.currentAlbumName === "" ? 0 : 1

                GridView {
                    id: albumGrid
                    clip: true
                    cellWidth: 180; cellHeight: 220
                    topMargin: 16; leftMargin: 16
                    model: root.albums

                    delegate: Item {
                        width: albumGrid.cellWidth
                        height: albumGrid.cellHeight

                        Rectangle {
                            anchors { fill: parent; margins: 8 }
                            radius: Theme.radius
                            color: albArea.containsMouse ? Theme.hover : "transparent"

                            ColumnLayout {
                                anchors { fill: parent; margins: 8 }
                                spacing: 8

                                Rectangle {
                                    Layout.preferredWidth: 140
                                    Layout.preferredHeight: 140
                                    Layout.alignment: Qt.AlignHCenter
                                    radius: Theme.radius
                                    color: Theme.panelAlt
                                    clip: true
                                    Image {
                                        anchors.fill: parent
                                        source: modelData.picUrl || ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                }
                                Text {
                                    text: modelData.name
                                    color: Theme.text
                                    font { family: Theme.fontFamily; pixelSize: 12; weight: Font.Medium }
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: modelData.artist ? modelData.artist.name : ""
                                    color: Theme.textDim
                                    font { family: Theme.fontFamily; pixelSize: 11 }
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: albArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.currentAlbumName = modelData.name
                                    networkManager.getAlbumSongs(modelData.id)
                                }
                            }
                        }
                    }
                }

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
                                color: backAlbum.containsMouse ? Theme.hover : "transparent"
                                Text { anchors.centerIn: parent; text: "←"; color: Theme.text; font.pixelSize: 14 }
                                MouseArea {
                                    id: backAlbum; anchors.fill: parent; hoverEnabled: true
                                    onClicked: root.currentAlbumName = ""
                                }
                            }
                            Text {
                                text: root.currentAlbumName
                                color: Theme.text
                                font { family: Theme.fontFamily; pixelSize: 13; weight: Font.Medium }
                                Layout.fillWidth: true
                            }
                        }
                    }

                    SongList {
                        id: albumSongList
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
        function onAlbumResultReady(albums) {
            root.albums = albums
            root.currentAlbumName = ""
        }
        function onAlbumSongsReady(albumId, songs) {
            albumSongList.model.clear()
            for (let i = 0; i < songs.length; i++) {
                let s = songs[i]
                albumSongList.model.append({
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