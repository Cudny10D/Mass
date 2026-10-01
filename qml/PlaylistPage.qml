import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root

    signal playListRequested(var songs, int index)

    property string mode: "grid"
    property string currentId: ""
    property string currentName: ""
    property string currentCover: ""
    property bool showingGrid: mode === "grid"
    property bool showingDetail: mode === "detail"

    ListModel { id: songsModel }

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

    function refreshSongs() {
        songsModel.clear()
        if (currentId === "") return
        let songs = playlistManager.getPlaylistSongs(currentId)
        for (let i = 0; i < songs.length; i++) {
            let s = songs[i]
            songsModel.append({
                cid: s.cid || "",
                name: s.name || "",
                artist: s.artist || "",
                cover: s.cover || ""
            })
        }
    }

    function enterPlaylist(id, name, cover) {
        currentId = id
        currentName = name
        currentCover = cover
        mode = "detail"
        refreshSongs()
    }

    function exitDetail() {
        mode = "grid"
        currentId = ""
        currentName = ""
        currentCover = ""
        songsModel.clear()
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
                clip: true

                RowLayout {
                    anchors { fill: parent; leftMargin: 96; rightMargin: 32 }
                    spacing: 12
                    opacity: root.showingGrid ? 1 : 0
                    x: root.showingGrid ? 0 : -40
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                    Text {
                        text: "我的歌单"
                        color: Theme.text
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(18); bold: true }
                        Layout.fillWidth: true
                    }

                    Text {
                        text: playlistManager.playlists.length + " 个"
                        color: Theme.textDim
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                    }

                    Rectangle {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 32
                        radius: 16
                        color: newBtn.containsMouse ? Theme.accentHover : Theme.accent
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "+"
                                color: Theme.darkMode ? "#000000" : "#ffffff"
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(16); bold: true }
                            }
                            Text {
                                text: "新建歌单"
                                color: Theme.darkMode ? "#000000" : "#ffffff"
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                            }
                        }

                        MouseArea {
                            id: newBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: newDialog.open()
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    height: 32
                    width: Math.max(100, Math.min(parent.width - 80, backRow.implicitWidth + 32))
                    radius: 16
                    opacity: root.showingDetail ? 1 : 0
                    x: root.showingDetail ? 0 : 40
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                    color: backArea.containsMouse
                           ? Theme.accent
                           : (Theme.darkMode ? "#1effffff" : "#0a000000")
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        anchors.margins: 1
                        height: parent.height / 2
                        radius: parent.radius
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#30ffffff" }
                            GradientStop { position: 1.0; color: "#00ffffff" }
                        }
                        opacity: backArea.containsMouse
                                 ? (Theme.darkMode ? 0.5 : 0.15)
                                 : (Theme.darkMode ? 0.4 : 0.1)
                    }

                    RowLayout {
                        id: backRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "←"
                            color: backArea.containsMouse
                                   ? (Theme.darkMode ? "#000000" : "#ffffff")
                                   : Theme.text
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(14); bold: true }
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }

                        Text {
                            Layout.maximumWidth: 240
                            text: root.currentName || "返回"
                            color: backArea.containsMouse
                                   ? (Theme.darkMode ? "#000000" : "#ffffff")
                                   : Theme.text
                            font {
                                family: Theme.fontFamily
                                pixelSize: Theme.fs(12)
                                bold: backArea.containsMouse
                            }
                            elide: Text.ElideRight
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }
                    }

                    MouseArea {
                        id: backArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.exitDetail()
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // ============================================================
                // Grid 视图
                // ============================================================
                Item {
                    anchors.fill: parent
                    opacity: root.showingGrid ? 1 : 0
                    x: root.showingGrid ? 0 : -60
                    visible: opacity > 0.01

                    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 16
                        visible: playlistManager.playlists.length === 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "♫"; color: Theme.textMuted
                            font.pixelSize: 56; opacity: 0.4
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "还没有歌单"
                            color: Theme.textDim
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(14) }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "点击右上角「+ 新建歌单」开始"
                            color: Theme.textMuted
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                        }
                    }

                    GridView {
                        id: grid
                        anchors.fill: parent
                        anchors.leftMargin: 96
                        anchors.rightMargin: 32
                        anchors.topMargin: 8
                        anchors.bottomMargin: 0
                        clip: true
                        visible: playlistManager.playlists.length > 0

                        property int columns: 5
                        property int gap: 24

                        cellWidth: width / columns
                        cellHeight: cellWidth + 64

                        model: playlistManager.playlists

                        // ★ 歌单本身的增删可以保留动画（不是批量操作）
                        add: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0; to: 1
                                duration: 320
                                easing.type: Easing.OutCubic
                            }
                        }

                        remove: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 1; to: 0
                                duration: 260
                            }
                        }

                        displaced: Transition {
                            NumberAnimation {
                                properties: "x,y"
                                duration: 320
                                easing.type: Easing.OutCubic
                            }
                        }

                        delegate: Item {
                            width: grid.cellWidth
                            height: grid.cellHeight
                            property bool isHover: itemArea.containsMouse

                            Column {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    leftMargin: grid.gap / 2
                                    rightMargin: grid.gap / 2
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
                                            antialiasing: true
                                            smooth: true
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
                                        text: "♫"
                                        color: Theme.textMuted
                                        font.pixelSize: 28
                                        opacity: 0.5
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
                                                text: "→"
                                                color: Theme.darkMode ? "#000000" : "#ffffff"
                                                font.pixelSize: 16
                                                font.bold: true
                                            }
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.name || "未命名"
                                    color: isHover ? Theme.accent : Theme.text
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12); weight: Font.Medium }
                                    elide: Text.ElideRight
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                Text {
                                    width: parent.width
                                    text: (modelData.songs ? modelData.songs.length : 0) + " 首"
                                    color: Theme.textDim
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                                }
                            }

                            MouseArea {
                                id: itemArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.enterPlaylist(modelData.id,
                                                       modelData.name,
                                                       modelData.cover || "")
                                }
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            active: true; policy: ScrollBar.AsNeeded; width: 6
                            contentItem: Rectangle { radius: 3; color: Theme.textMuted; opacity: 0.4 }
                        }
                    }
                }

                // ============================================================
                // 歌单详情
                // ============================================================
                Item {
                    anchors.fill: parent
                    opacity: root.showingDetail ? 1 : 0
                    x: root.showingDetail ? 0 : 60
                    visible: opacity > 0.01

                    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 16

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 96
                            Layout.rightMargin: 32
                            Layout.topMargin: 8
                            spacing: 24

                            Item {
                                Layout.preferredWidth: 140
                                Layout.preferredHeight: 140

                                property real cornerRadius: 12

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.cornerRadius
                                    color: Theme.panelAlt
                                }

                                Image {
                                    id: bigCoverImg
                                    anchors.fill: parent
                                    source: root.coverSource(root.currentCover)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize.width: 280
                                    sourceSize.height: 280
                                    visible: false
                                    layer.enabled: true
                                }

                                Item {
                                    id: bigMaskSource
                                    anchors.fill: parent
                                    visible: false
                                    layer.enabled: true
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.parent.cornerRadius
                                        color: "white"
                                        antialiasing: true
                                        smooth: true
                                    }
                                }

                                MultiEffect {
                                    anchors.fill: parent
                                    source: bigCoverImg
                                    visible: bigCoverImg.status === Image.Ready
                                    maskEnabled: true
                                    maskSource: bigMaskSource
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "♫"
                                    color: Theme.textMuted
                                    font.pixelSize: 48
                                    opacity: 0.5
                                    visible: bigCoverImg.status !== Image.Ready
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: root.currentName || "歌单"
                                    color: Theme.text
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(24); bold: true }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: songsModel.count + " 首歌曲"
                                    color: Theme.textDim
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                }

                                RowLayout {
                                    spacing: 10

                                    Rectangle {
                                        Layout.preferredWidth: 110
                                        Layout.preferredHeight: 34
                                        radius: 17
                                        color: playAllBtn.containsMouse ? Theme.accentHover : Theme.accent
                                        visible: songsModel.count > 0
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 6
                                            Text {
                                                text: "▶"
                                                color: Theme.darkMode ? "#000000" : "#ffffff"
                                                font.pixelSize: Theme.fs(12)
                                            }
                                            Text {
                                                text: "播放全部"
                                                color: Theme.darkMode ? "#000000" : "#ffffff"
                                                font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                                            }
                                        }

                                        MouseArea {
                                            id: playAllBtn
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                var list = []
                                                for (var i = 0; i < songsModel.count; i++) {
                                                    var it = songsModel.get(i)
                                                    list.push({
                                                        cid: it.cid, name: it.name,
                                                        artist: it.artist, cover: it.cover
                                                    })
                                                }
                                                root.playListRequested(list, 0)
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 100
                                        Layout.preferredHeight: 34
                                        radius: 17
                                        color: coverBtn.containsMouse ? Theme.hover : "transparent"
                                        border.color: Theme.border
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: "编辑封面"
                                            color: Theme.text
                                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                                        }

                                        MouseArea {
                                            id: coverBtn
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                coverDialog.coverText = root.currentCover
                                                coverDialog.open()
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 100
                                        Layout.preferredHeight: 34
                                        radius: 17
                                        color: delBtn.containsMouse ? "#33e81123" : "transparent"
                                        border.color: delBtn.containsMouse ? "transparent" : Theme.border
                                        border.width: delBtn.containsMouse ? 0 : 1
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "删除歌单"
                                            color: "#e81123"
                                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: delBtn.containsMouse }
                                        }

                                        MouseArea {
                                            id: delBtn
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: confirmDeleteDialog.open()
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.leftMargin: 96
                            Layout.rightMargin: 32
                            Layout.bottomMargin: 0
                            clip: true

                            Column {
                                anchors.centerIn: parent
                                spacing: 12
                                visible: songsModel.count === 0
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "♫"; color: Theme.textMuted
                                    font.pixelSize: 48; opacity: 0.4
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "歌单是空的"
                                    color: Theme.textDim
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "播放列表里点 + 添加歌曲"
                                    color: Theme.textMuted
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                                }
                            }

                            ListView {
                                id: songsList
                                anchors.fill: parent
                                clip: true
                                spacing: 4
                                visible: songsModel.count > 0
                                model: songsModel

                                // ★ 没有 add / remove / displaced Transition
                                //   模型变化时瞬时切换，不会重合

                                delegate: Item {
                                    id: songRow
                                    width: songsList.width
                                    height: 64

                                    HoverHandler {
                                        id: rowHover
                                    }

                                    property bool isHover: rowHover.hovered

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.radius
                                        color: songRow.isHover ? Theme.hover : "transparent"
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        z: -1
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        z: -1
                                        onClicked: {
                                            var list = []
                                            for (var i = 0; i < songsModel.count; i++) {
                                                var it = songsModel.get(i)
                                                list.push({
                                                    cid: it.cid, name: it.name,
                                                    artist: it.artist, cover: it.cover
                                                })
                                            }
                                            root.playListRequested(list, index)
                                        }
                                    }

                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                                        spacing: 14
                                        z: 1

                                        Text {
                                            Layout.preferredWidth: 24
                                            text: (index + 1).toString().padStart(2, "0")
                                            color: songRow.isHover ? Theme.accent : Theme.textDim
                                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                                            horizontalAlignment: Text.AlignHCenter
                                            Behavior on color { ColorAnimation { duration: 120 } }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 44
                                            Layout.preferredHeight: 44
                                            radius: 8
                                            color: Theme.panelAlt
                                            clip: true

                                            Image {
                                                anchors.fill: parent
                                                source: root.coverSource(model.cover)
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                cache: true
                                                visible: status === Image.Ready
                                            }
                                            Text {
                                                anchors.centerIn: parent
                                                text: "♪"
                                                color: Theme.textMuted
                                                font.pixelSize: 16
                                                visible: !model.cover
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text {
                                                text: model.name || ""
                                                color: Theme.text
                                                font { family: Theme.fontFamily; pixelSize: Theme.fs(13); weight: Font.Medium }
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            Text {
                                                text: model.artist || ""
                                                color: Theme.textDim
                                                font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        Rectangle {
                                            id: removeButton
                                            Layout.preferredWidth: 30
                                            Layout.preferredHeight: 30
                                            radius: 15
                                            color: removeBtnArea.containsMouse ? "#e81123" : "transparent"
                                            border.color: removeBtnArea.containsMouse ? "transparent" : Theme.border
                                            border.width: removeBtnArea.containsMouse ? 0 : 1
                                            opacity: songRow.isHover ? 1 : 0
                                            Behavior on opacity { NumberAnimation { duration: 120 } }
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on border.color { ColorAnimation { duration: 150 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "✕"
                                                color: removeBtnArea.containsMouse ? "#ffffff" : Theme.textDim
                                                font {
                                                    family: Theme.fontFamily
                                                    pixelSize: Theme.fs(13)
                                                    bold: removeBtnArea.containsMouse
                                                }
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }

                                            MouseArea {
                                                id: removeBtnArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                preventStealing: true
                                                onClicked: {
                                                    mouse.accepted = true
                                                    playlistManager.removeSong(root.currentId, model.cid)
                                                    refreshSongs()
                                                }
                                            }
                                        }
                                    }
                                }

                                ScrollBar.vertical: ScrollBar {
                                    active: true; policy: ScrollBar.AsNeeded; width: 6
                                    contentItem: Rectangle { radius: 3; color: Theme.textMuted; opacity: 0.4 }
                                }
                            }
                        }
                    }
                }

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

    // ============================================================
    // 新建歌单弹窗
    // ============================================================
    Item {
        id: newDialog
        parent: Overlay.overlay
        anchors.fill: parent
        visible: opacity > 0.01
        opacity: 0
        z: 1000

        function open() {
            newInput.text = ""
            opacity = 1
            newInput.forceActiveFocus()
        }
        function close() {
            opacity = 0
        }

        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.5
            MouseArea {
                anchors.fill: parent
                onClicked: newDialog.close()
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 360
            height: 180
            radius: Theme.radiusLarge
            color: Theme.panel
            border.color: Theme.border
            border.width: 1

            scale: newDialog.opacity > 0.5 ? 1.0 : 0.85
            Behavior on scale {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutBack
                }
            }

            ColumnLayout {
                anchors { fill: parent; margins: 24 }
                spacing: 16

                Text {
                    text: "新建歌单"
                    color: Theme.text
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(16); bold: true }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: Theme.bg
                    radius: Theme.radius
                    border.color: newInput.activeFocus ? Theme.accent : Theme.border
                    border.width: 1

                    TextInput {
                        id: newInput
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                        selectByMouse: true
                        onAccepted: {
                            if (text.trim() !== "") {
                                playlistManager.createPlaylist(text.trim())
                                newDialog.close()
                            }
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "歌单名称"
                            color: Theme.textMuted
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                            visible: !newInput.text && !newInput.activeFocus
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 32
                        radius: 16
                        color: cancelBtn.containsMouse ? Theme.hover : "transparent"
                        border.color: Theme.border
                        border.width: 1

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
                            onClicked: newDialog.close()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 32
                        radius: 16
                        color: okBtn.containsMouse ? Theme.accentHover : Theme.accent

                        Text {
                            anchors.centerIn: parent
                            text: "创建"
                            color: Theme.darkMode ? "#000000" : "#ffffff"
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                        }

                        MouseArea {
                            id: okBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (newInput.text.trim() !== "") {
                                    playlistManager.createPlaylist(newInput.text.trim())
                                    newDialog.close()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // 编辑封面弹窗
    // ============================================================
    Item {
        id: coverDialog
        parent: Overlay.overlay
        anchors.fill: parent
        visible: opacity > 0.01
        opacity: 0
        z: 1000

        property string coverText: ""

        function open() {
            coverText = root.currentCover
            opacity = 1
        }
        function close() {
            opacity = 0
        }

        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.5
            MouseArea {
                anchors.fill: parent
                onClicked: coverDialog.close()
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 520
            height: 240
            radius: Theme.radiusLarge
            color: Theme.panel
            border.color: Theme.border
            border.width: 1
            clip: true

            scale: coverDialog.opacity > 0.5 ? 1.0 : 0.85
            Behavior on scale {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutBack
                }
            }

            ColumnLayout {
                anchors { fill: parent; margins: 24 }
                spacing: 16

                Text {
                    text: "编辑歌单封面"
                    color: Theme.text
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(16); bold: true }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: Theme.bg
                    radius: Theme.radius
                    border.color: coverInput.activeFocus ? Theme.accent : Theme.border
                    border.width: 1
                    clip: true

                    Text {
                        anchors {
                            fill: parent
                            leftMargin: 12
                            rightMargin: 12
                        }
                        verticalAlignment: Text.AlignVCenter
                        text: coverDialog.coverText !== ""
                              ? coverDialog.coverText
                              : "点击输入图片路径或 URL"
                        color: coverDialog.coverText !== ""
                               ? Theme.text
                               : Theme.textMuted
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                        elide: Text.ElideMiddle
                        visible: !coverInput.activeFocus

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                coverInput.text = coverDialog.coverText
                                coverInput.forceActiveFocus()
                                coverInput.cursorPosition = coverInput.text.length
                            }
                        }
                    }

                    TextInput {
                        id: coverInput
                        anchors {
                            fill: parent
                            leftMargin: 12
                            rightMargin: 12
                        }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                        selectByMouse: true
                        clip: true
                        visible: activeFocus
                        onTextChanged: coverDialog.coverText = text
                        onAccepted: focus = false
                        Keys.onEscapePressed: focus = false
                    }
                }

                Text {
                    text: "支持 jpg / png / bmp / http URL，留空则自动跟随歌曲封面"
                    color: Theme.textMuted
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 32
                        radius: 16
                        color: cancelCoverBtn.containsMouse ? Theme.hover : "transparent"
                        border.color: Theme.border
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "取消"
                            color: Theme.text
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                        }

                        MouseArea {
                            id: cancelCoverBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: coverDialog.close()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 32
                        radius: 16
                        color: saveCoverBtn.containsMouse ? Theme.accentHover : Theme.accent

                        Text {
                            anchors.centerIn: parent
                            text: "保存"
                            color: Theme.darkMode ? "#000000" : "#ffffff"
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                        }

                        MouseArea {
                            id: saveCoverBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                playlistManager.setPlaylistCover(root.currentId,
                                                                  coverDialog.coverText.trim())
                                root.currentCover = coverDialog.coverText.trim()
                                coverDialog.close()
                            }
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // 删除确认弹窗
    // ============================================================
    Item {
        id: confirmDeleteDialog
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
            MouseArea {
                anchors.fill: parent
                onClicked: confirmDeleteDialog.close()
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 340
            height: 160
            radius: Theme.radiusLarge
            color: Theme.panel
            border.color: Theme.border
            border.width: 1

            scale: confirmDeleteDialog.opacity > 0.5 ? 1.0 : 0.85
            Behavior on scale {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutBack
                }
            }

            ColumnLayout {
                anchors { fill: parent; margins: 24 }
                spacing: 16

                Text {
                    text: "删除歌单"
                    color: "#e81123"
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(16); bold: true }
                }

                Text {
                    text: "确定要删除「" + root.currentName + "」吗？"
                    color: Theme.text
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 32
                        radius: 16
                        color: cancelDelBtn.containsMouse ? Theme.hover : "transparent"
                        border.color: Theme.border
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "取消"
                            color: Theme.text
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                        }

                        MouseArea {
                            id: cancelDelBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: confirmDeleteDialog.close()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 32
                        radius: 16
                        color: confirmDelBtn.containsMouse ? "#cc0e1a" : "#e81123"

                        Text {
                            anchors.centerIn: parent
                            text: "删除"
                            color: "#ffffff"
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                        }

                        MouseArea {
                            id: confirmDelBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                playlistManager.deletePlaylist(root.currentId)
                                confirmDeleteDialog.close()
                                root.exitDetail()
                            }
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // 数据同步
    // ============================================================
    Connections {
        target: playlistManager
        function onPlaylistsChanged() {
            if (root.mode === "detail" && root.currentId !== "") {
                refreshSongs()

                let pls = playlistManager.playlists
                for (let i = 0; i < pls.length; i++) {
                    if (pls[i].id === root.currentId) {
                        root.currentName = pls[i].name
                        root.currentCover = pls[i].cover || ""
                        break
                    }
                }
            }
        }
    }
}