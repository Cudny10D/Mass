import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root

    signal playListRequested(var songs, int index)

    property bool heroActive: false
    property bool importing: false

    ListModel { id: localModel }

    function coverSource(path) {
        if (!path || path === "") return ""
        if (path.startsWith("http://") || path.startsWith("https://")
                || path.startsWith("file://") || path.startsWith("qrc:")) {
            return path
        }
        return "file:///" + path
    }

    function refresh() {
        localModel.clear()
        let songs = appSettings.getLocalSongs()
        for (let i = 0; i < songs.length; i++) {
            let s = songs[i]
            localModel.append({
                filePath: s.filePath || "",
                name: s.title || "",
                artist: s.artist || "",
                cover: s.coverPath || "",
                lyric: s.lyricPath || ""
            })
        }
    }

    Component.onCompleted: refresh()

    Connections {
        target: appSettings
        function onLocalSongsChanged() { root.refresh() }
    }

    function doImport() {
        let files = appSettings.pickOpenFiles(
            "选择音频文件",
            "音频 (*.mp3 *.flac *.wav *.m4a *.ogg *.aac *.opus);;所有文件 (*.*)")
        if (!files || files.length === 0) return

        importing = true
        for (let i = 0; i < files.length; i++) {
            let path = files[i]
            let title = appSettings.baseNameOf(path)
            let cover = appSettings.findSidecarFile(path,
                ["jpg", "jpeg", "png", "webp", "bmp"])
            let lyric = appSettings.findSidecarFile(path, ["lrc", "LRC"])
            appSettings.addLocalSong(path, title, "本地歌曲", cover, lyric)
        }
        importing = false
        root.refresh()
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ============================================================
            // 索引条
            // ============================================================
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                RowLayout {
                    anchors { fill: parent; leftMargin: Theme.contentSideMargin; rightMargin: Theme.contentSideMargin }
                    spacing: 12

                    Text {
                        text: "LOCAL LIBRARY / 本地曲库"
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
                        text: localModel.count + " 首"
                        color: Theme.textMuted
                        font {
                            family: Theme.fontFamily
                            pixelSize: Theme.labelSize
                            letterSpacing: 1.2
                        }
                    }

                    // 导入
                    Rectangle {
                        Layout.preferredWidth: importRow.implicitWidth + 28
                        Layout.preferredHeight: 28
                        color: importBtn.containsMouse ? Theme.accentHover : Theme.accent
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Row {
                            id: importRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "＋"
                                color: Theme.ink
                                font { family: Theme.monoFamily; pixelSize: Theme.fs(10) }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "导入音频"
                                color: Theme.ink
                                font {
                                    family: Theme.fontFamily
                                    pixelSize: Theme.fs(11.5)
                                    weight: Font.DemiBold
                                }
                            }
                        }

                        MouseArea {
                            id: importBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !root.importing
                            onClicked: root.doImport()
                        }
                    }

                    // 清空
                    Item {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 24
                        opacity: localModel.count > 0 ? 1 : 0.35
                        Text {
                            anchors.centerIn: parent
                            text: "清空"
                            color: clearBtn.containsMouse && localModel.count > 0
                                   ? Theme.danger : Theme.textDim
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(11.5) }
                        }
                        MouseArea {
                            id: clearBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: localModel.count > 0
                            onClicked: clearConfirmDialog.open()
                        }
                    }
                }
            }

            // ============================================================
            // 内容
            // ============================================================
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // 空状态
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: localModel.count === 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "NO LOCAL FILES"
                        color: Theme.textMuted
                        font {
                            family: Theme.monoFamily
                            pixelSize: Theme.fs(13)
                            letterSpacing: 3
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "点右上角「导入音频」把本地文件收进曲库"
                        color: Theme.textMuted
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(11.5) }
                    }
                }

                // 歌曲列表
                ListView {
                    id: localList
                    anchors.fill: parent
                    anchors.leftMargin: Theme.contentSideMargin
                    anchors.rightMargin: Theme.contentSideMargin
                    anchors.topMargin: 18
                    anchors.bottomMargin: 8
                    clip: true
                    spacing: 0
                    visible: localModel.count > 0
                    model: localModel

                    delegate: Item {
                        id: rowItem
                        width: localList.width
                        height: Theme.rowHeight

                        // ★ 整行点击区：先声明 → z 最低，按钮优先接收点击
                        MouseArea {
                            id: lArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                var list = []
                                for (var i = 0; i < localModel.count; i++) {
                                    var item = localModel.get(i)
                                    list.push({
                                        cid: item.filePath,
                                        name: item.name,
                                        artist: item.artist,
                                        cover: item.cover
                                    })
                                }
                                root.playListRequested(list, index)
                            }
                        }

                        property bool isHover: lArea.containsMouse

                        // 行背景（悬停高亮）
                        Rectangle {
                            anchors.fill: parent
                            color: rowItem.isHover ? Theme.hover : "transparent"
                            z: -1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Rectangle {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                width: 3
                                height: rowItem.isHover ? 28 : 0
                                radius: 1.5
                                color: Theme.accent
                                antialiasing: true
                                enabled: false
                                Behavior on height {
                                    NumberAnimation {
                                        duration: Theme.animNormal
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }

                        // 内容行（在 lArea 之上）
                        RowLayout {
                            anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                            spacing: 14
                            z: 1

                            Text {
                                Layout.preferredWidth: 28
                                text: rowItem.isHover ? "▶"
                                                       : (index + 1).toString().padStart(2, "0")
                                color: rowItem.isHover ? Theme.accentHover : Theme.textMuted
                                font {
                                    family: Theme.monoFamily
                                    pixelSize: Theme.fs(10)
                                    letterSpacing: 0.8
                                }
                                horizontalAlignment: Text.AlignHCenter
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Rectangle {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                color: Theme.panelAlt
                                border.width: 1
                                border.color: Theme.border
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: root.coverSource(model.cover)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize.width: 128
                                    sourceSize.height: 128
                                    smooth: true
                                    mipmap: true
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "♪"
                                    color: Theme.textMuted
                                    font.pixelSize: 20
                                    visible: !model.cover
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                Text {
                                    text: model.name || ""
                                    color: Theme.text
                                    font {
                                        family: Theme.fontFamily
                                        pixelSize: Theme.fs(13)
                                    }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: model.artist || ""
                                    color: Theme.textMuted
                                    font {
                                        family: Theme.fontFamily
                                        pixelSize: Theme.microSize
                                        letterSpacing: 0.4
                                    }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            // 编辑
                            Item {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 24
                                opacity: rowItem.isHover ? 1 : 0
                                z: 2
                                Behavior on opacity { NumberAnimation { duration: 110 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "编辑"
                                    color: editBtn.containsMouse ? Theme.accentHover : Theme.textDim
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                                }

                                MouseArea {
                                    id: editBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true
                                    onClicked: {
                                        mouse.accepted = true
                                        editDialog.openFor(index, model.filePath, model.name,
                                                           model.artist, model.cover, model.lyric)
                                    }
                                }
                            }

                            // 移除
                            Item {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 24
                                opacity: rowItem.isHover ? 1 : 0
                                z: 2
                                Behavior on opacity { NumberAnimation { duration: 110 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "移除"
                                    color: delBtn.containsMouse ? Theme.danger : Theme.textDim
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                                }

                                MouseArea {
                                    id: delBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true
                                    onClicked: {
                                        mouse.accepted = true
                                        appSettings.removeLocalSong(model.filePath)
                                    }
                                }
                            }

                            Text {
                                Layout.preferredWidth: 54
                                horizontalAlignment: Text.AlignRight
                                text: "PLAY ↗"
                                color: rowItem.isHover ? Theme.accentHover : "transparent"
                                font {
                                    family: Theme.monoFamily
                                    pixelSize: Theme.microSize
                                    letterSpacing: 0.8
                                }
                                z: 2
                            }
                        }

                        // 行分隔线
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 1
                            color: Theme.border
                            opacity: rowItem.isHover ? 0 : 0.45
                            enabled: false
                            z: 2
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded; width: 3
                        contentItem: Rectangle { radius: 0; color: Theme.textMuted; opacity: 0.45 }
                    }
                }
            }
        }
    }

    // ============================================================
    // 编辑弹窗
    // ============================================================
    Item {
        id: editDialog
        parent: Overlay.overlay
        anchors.fill: parent
        visible: opacity > 0.01
        opacity: 0
        z: 1000

        property int editIndex: -1
        property string editPath: ""
        property string editTitle: ""
        property string editArtist: ""
        property string editCover: ""
        property string editLyric: ""

        function openFor(idx, path, title, artist, cover, lyric) {
            editIndex = idx
            editPath = path
            editTitle = title
            editArtist = artist
            editCover = cover
            editLyric = lyric
            titleInput.text = title
            artistInput.text = artist
            opacity = 1
        }
        function close() { opacity = 0 }

        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.5
            MouseArea { anchors.fill: parent; onClicked: editDialog.close() }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 500
            height: 400
            radius: Theme.radiusLarge
            color: Theme.panel
            border.color: Theme.border
            border.width: 1
            antialiasing: true

            scale: editDialog.opacity > 0.5 ? 1.0 : 0.85
            Behavior on scale {
                NumberAnimation { duration: 260; easing.type: Easing.OutBack }
            }

            ColumnLayout {
                anchors { fill: parent; margins: 24 }
                spacing: 14

                Text {
                    text: "编辑本地歌曲信息"
                    color: Theme.text
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(16); bold: true }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderLight; opacity: 0.6 }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        text: "标题"
                        color: Theme.textDim
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                        Layout.preferredWidth: 56
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: Theme.radius
                        color: Theme.bgAlt
                        border.color: titleInput.activeFocus ? Theme.accent : Theme.border
                        border.width: 1
                        antialiasing: true

                        TextInput {
                            id: titleInput
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                            selectByMouse: true
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        text: "艺术家"
                        color: Theme.textDim
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                        Layout.preferredWidth: 56
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: Theme.radius
                        color: Theme.bgAlt
                        border.color: artistInput.activeFocus ? Theme.accent : Theme.border
                        border.width: 1
                        antialiasing: true

                        TextInput {
                            id: artistInput
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                            selectByMouse: true
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        text: "封面"
                        color: Theme.textDim
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                        Layout.preferredWidth: 56
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: Theme.radius
                        color: Theme.bgAlt
                        border.color: Theme.border
                        border.width: 1
                        antialiasing: true

                        Text {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            verticalAlignment: Text.AlignVCenter
                            text: editDialog.editCover !== "" ? editDialog.editCover : "未设置"
                            color: editDialog.editCover !== "" ? Theme.text : Theme.textMuted
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                            elide: Text.ElideMiddle
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 70
                        Layout.preferredHeight: 34
                        radius: Theme.radius
                        color: coverPick.containsMouse ? Theme.hover : "transparent"
                        border.color: Theme.border
                        border.width: 1
                        antialiasing: true

                        Text {
                            anchors.centerIn: parent
                            text: "选择..."
                            color: Theme.text
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                        }

                        MouseArea {
                            id: coverPick
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                let p = appSettings.pickOpenFile(
                                    "选择封面图片",
                                    "图片 (*.jpg *.jpeg *.png *.webp *.bmp)")
                                if (p !== "") editDialog.editCover = p
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        text: "歌词"
                        color: Theme.textDim
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                        Layout.preferredWidth: 56
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: Theme.radius
                        color: Theme.bgAlt
                        border.color: Theme.border
                        border.width: 1
                        antialiasing: true

                        Text {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            verticalAlignment: Text.AlignVCenter
                            text: editDialog.editLyric !== "" ? editDialog.editLyric : "未设置"
                            color: editDialog.editLyric !== "" ? Theme.text : Theme.textMuted
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                            elide: Text.ElideMiddle
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 70
                        Layout.preferredHeight: 34
                        radius: Theme.radius
                        color: lyricPick.containsMouse ? Theme.hover : "transparent"
                        border.color: Theme.border
                        border.width: 1
                        antialiasing: true

                        Text {
                            anchors.centerIn: parent
                            text: "选择..."
                            color: Theme.text
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                        }

                        MouseArea {
                            id: lyricPick
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                let p = appSettings.pickOpenFile(
                                    "选择歌词文件", "歌词 (*.lrc)")
                                if (p !== "") editDialog.editLyric = p
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 32
                        radius: 0
                        color: cancelBtn.containsMouse ? Theme.hover : "transparent"
                        border.color: Theme.border
                        border.width: 1
                        antialiasing: true

                        Text {
                            anchors.centerIn: parent
                            text: "取消"
                            color: Theme.text
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                        }

                        MouseArea {
                            id: cancelBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: editDialog.close()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 32
                        radius: 0
                        color: saveBtn.containsMouse ? Theme.accentHover : Theme.accent
                        antialiasing: true

                        Text {
                            anchors.centerIn: parent
                            text: "保存"
                            color: Theme.darkMode ? "#000000" : "#ffffff"
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                        }

                        MouseArea {
                            id: saveBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                appSettings.updateLocalSong(
                                    editDialog.editPath,
                                    titleInput.text.trim(),
                                    artistInput.text.trim(),
                                    editDialog.editCover,
                                    editDialog.editLyric)
                                editDialog.close()
                            }
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // 清空确认
    // ============================================================
    Item {
        id: clearConfirmDialog
        parent: Overlay.overlay
        anchors.fill: parent
        visible: opacity > 0.01
        opacity: 0
        z: 1000

        function open() { opacity = 1 }
        function close() { opacity = 0 }

        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.5
            MouseArea { anchors.fill: parent; onClicked: clearConfirmDialog.close() }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 340
            height: 150
            radius: Theme.radiusLarge
            color: Theme.panel
            border.color: Theme.border
            border.width: 1
            antialiasing: true

            ColumnLayout {
                anchors { fill: parent; margins: 24 }
                spacing: 14

                Text {
                    text: "清空本地库"
                    color: "#e81123"
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(15); bold: true }
                }

                Text {
                    text: "将移除所有本地歌曲记录（不会删除原文件）"
                    color: Theme.text
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 32
                        radius: 0
                        color: cCancel.containsMouse ? Theme.hover : "transparent"
                        border.color: Theme.border
                        border.width: 1
                        antialiasing: true

                        Text {
                            anchors.centerIn: parent
                            text: "取消"
                            color: Theme.text
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                        }

                        MouseArea {
                            id: cCancel
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: clearConfirmDialog.close()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 32
                        radius: 0
                        color: cConfirm.containsMouse ? "#cc0e1a" : "#e81123"
                        antialiasing: true

                        Text {
                            anchors.centerIn: parent
                            text: "清空"
                            color: "#ffffff"
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                        }

                        MouseArea {
                            id: cConfirm
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                appSettings.clearLocalSongs()
                                clearConfirmDialog.close()
                            }
                        }
                    }
                }
            }
        }
    }
}