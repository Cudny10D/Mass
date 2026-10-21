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

    // Hero 动画状态
    property bool heroActive: false

    // 轻量 toast
    property string toastMsg: ""
    function showToast(msg) {
        root.toastMsg = msg
        toast.opacity = 1
        toastTimer.restart()
    }

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

            // ============================================================
            // 顶部栏
            // ============================================================
            // ============================================================
            // 索引条 / 返回
            // ============================================================
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                clip: true

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.contentSideMargin
                    anchors.rightMargin: Theme.contentSideMargin
                    spacing: 12
                    opacity: root.showingGrid ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    Text {
                        text: "MY MUSIC / 我的歌单"
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
                        text: playlistManager.playlists.length + " 个歌单"
                        color: Theme.textMuted
                        font {
                            family: Theme.fontFamily
                            pixelSize: Theme.fs(11.5)
                            letterSpacing: 0.6
                        }
                    }

                    // 导入歌单
                    Item {
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 24

                        Text {
                            anchors.centerIn: parent
                            text: "导入歌单"
                            color: importPlBtn.containsMouse ? Theme.accentHover : Theme.textDim
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(11.5) }
                        }

                        MouseArea {
                            id: importPlBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let path = appSettings.pickOpenFile(
                                    "选择歌单 JSON", "Mass 歌单 (*.json)")
                                if (path === "") return
                                let n = playlistManager.importPlaylist(path)
                                if (n > 0) root.showToast("歌单已导入")
                                else root.showToast("导入失败：文件无效")
                            }
                        }
                    }

                    // 新建歌单
                    Rectangle {
                        Layout.preferredWidth: newRow.implicitWidth + 28
                        Layout.preferredHeight: 28
                        color: newBtn.containsMouse ? Theme.accentHover : Theme.accent
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Row {
                            id: newRow
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
                                text: "新建歌单"
                                color: Theme.ink
                                font {
                                    family: Theme.fontFamily
                                    pixelSize: Theme.fs(11.5)
                                    weight: Font.DemiBold
                                }
                            }
                        }

                        MouseArea {
                            id: newBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: newDialog.open()
                        }
                    }
                }

                // 详情态：返回
                Item {
                    id: backRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.contentSideMargin
                    width: backContent.width
                    height: backContent.height
                    opacity: root.showingDetail ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    Row {
                        id: backContent
                        spacing: 8

                        Text {
                            text: "←"
                            color: backArea.containsMouse ? Theme.accentHover : Theme.textDim
                            font { family: Theme.monoFamily; pixelSize: Theme.fs(13) }
                        }
                        Text {
                            text: "返回我的歌单"
                            color: backArea.containsMouse ? Theme.accentHover : Theme.textDim
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(11.5) }
                        }
                        Item { width: 4; height: 1 }

                        Text {
                            text: "ESC"
                            color: Theme.textMuted
                            font {
                                family: Theme.monoFamily
                                pixelSize: Theme.microSize
                                letterSpacing: 1.2
                            }
                        }
                    }

                    // 命中区放在 Row 外面：Row 的子项不能用 fill 锚点
                    MouseArea {
                        id: backArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.exitDetail()
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

                // Grid 视图
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
                            text: "NO PLAYLIST"
                            color: Theme.textMuted
                            font {
                                family: Theme.monoFamily
                                pixelSize: Theme.fs(13)
                                letterSpacing: 3
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "点右上角「新建歌单」开始，或「导入歌单」读取分享文件"
                            color: Theme.textMuted
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(11.5) }
                        }
                    }

                    GridView {
                        id: grid
                        anchors.fill: parent
                        // 留白由窗口宽度驱动（见 Theme.contentSideMargin）
                        anchors.leftMargin: Theme.contentSideMargin
                        anchors.rightMargin: Theme.contentSideMargin
                        anchors.topMargin: 8
                        anchors.bottomMargin: 28
                        clip: true
                        visible: playlistManager.playlists.length > 0

                        // 列数自适应窗口宽度（详见 Theme.gridMetrics）
                        readonly property var metrics: Theme.gridMetrics
                        property int columns: metrics.columns
                        property int gap: Theme.gridGap

                        cellWidth: metrics.cellWidth
                        cellHeight: Math.max(1, metrics.cellWidth + 64)

                        model: playlistManager.playlists

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

                                    property real cornerRadius: 0

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: coverItem.cornerRadius
                                        color: Theme.panelAlt
                                        antialiasing: true
                                    }

                                    Image {
                                        id: coverImg
                                        anchors.fill: parent
                                        source: root.coverSource(modelData.cover)
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        sourceSize.width: 512
                                        sourceSize.height: 512
                                        smooth: true
                                        mipmap: true
                                        visible: false
                                        layer.enabled: true
                                        layer.smooth: true
                                    }

                                    Item {
                                        id: coverMaskSource
                                        anchors.fill: parent
                                        visible: false
                                        layer.enabled: true
                                        layer.smooth: true

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
                                        smooth: true
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
                                        antialiasing: true
                                        Behavior on opacity { NumberAnimation { duration: 150 } }

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 36; height: 36; radius: 0
                                            color: Theme.accent
                                            antialiasing: true
                                            scale: isHover ? 1.0 : 0.7
                                            opacity: isHover ? 1 : 0
                                            Behavior on scale { NumberAnimation { duration: 220 } }
                                            Behavior on opacity { NumberAnimation { duration: 220 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "→"
                                                color: Theme.ink
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
                                    text: (modelData.songs ? modelData.songs.length : 0) + " TRACKS"
                                    color: Theme.textDim
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                                }
                            }

                            MouseArea {
                                id: itemArea
                                anchors.fill: parent
                                hoverEnabled: true

                                onClicked: {
                                    let src = coverItem
                                    let p = src.mapToItem(root, 0, 0)
                                    hero.fromRect = Qt.rect(p.x, p.y, src.width, src.height)
                                    hero.imageUrl = root.coverSource(modelData.cover)

                                    root.enterPlaylist(modelData.id,
                                                       modelData.name,
                                                       modelData.cover || "")

                                    Qt.callLater(function() {
                                        if (!bigCoverContainer) return
                                        let p2 = bigCoverContainer.mapToItem(root, 0, 0)
                                        hero.toRect = Qt.rect(p2.x, p2.y,
                                                              bigCoverContainer.width,
                                                              bigCoverContainer.height)
                                        root.heroActive = true
                                        hero.start(root.coverSource(modelData.cover),
                                                   hero.fromRect, hero.toRect,
                                                   coverItem.cornerRadius, 12)
                                    })
                                }
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded; width: 3
                            contentItem: Rectangle { radius: 0; color: Theme.textMuted; opacity: 0.45 }
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
                            Layout.leftMargin: Theme.contentSideMargin
                            Layout.rightMargin: Theme.contentSideMargin
                            Layout.topMargin: 26
                            spacing: 24

                            Item {
                                id: bigCoverContainer
                                Layout.preferredWidth: 140
                                Layout.preferredHeight: 140

                                property real cornerRadius: 0

                                opacity: root.heroActive ? 0 : 1
                                Behavior on opacity { NumberAnimation { duration: 140 } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.cornerRadius
                                    color: Theme.panelAlt
                                    antialiasing: true
                                }

                                Image {
                                    id: bigCoverImg
                                    anchors.fill: parent
                                    source: root.coverSource(root.currentCover)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize.width: 1024
                                    sourceSize.height: 1024
                                    smooth: true
                                    mipmap: true
                                    visible: false
                                    layer.enabled: true
                                    layer.smooth: true
                                }

                                Item {
                                    id: bigMaskSource
                                    anchors.fill: parent
                                    visible: false
                                    layer.enabled: true
                                    layer.smooth: true

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
                                    smooth: true
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

                                    // 播放全部
                                    Rectangle {
                                        Layout.preferredWidth: 110
                                        Layout.preferredHeight: 34
                                        radius: 0
                                        color: playAllBtn.containsMouse ? Theme.accentHover : Theme.accent
                                        visible: songsModel.count > 0
                                        antialiasing: true
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 6
                                            Text {
                                                text: "▶"
                                                color: Theme.ink
                                                font.pixelSize: Theme.fs(12)
                                            }
                                            Text {
                                                text: "播放全部"
                                                color: Theme.ink
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

                                    // ★ 分享歌单
                                    Rectangle {
                                        Layout.preferredWidth: 100
                                        Layout.preferredHeight: 34
                                        radius: 0
                                        color: shareBtn.containsMouse ? Theme.hover : "transparent"
                                        border.color: Theme.border
                                        border.width: 1
                                        antialiasing: true

                                        Text {
                                            anchors.centerIn: parent
                                            text: "分享歌单"
                                            color: shareBtn.containsMouse ? Theme.accentHover : Theme.text
                                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                                        }

                                        MouseArea {
                                            id: shareBtn
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                let safeName = (root.currentName || "playlist")
                                                    .replace(/[\\/:*?"<>|]/g, "_")
                                                let fname = "playlist-" + safeName + ".json"
                                                let path = appSettings.pickSaveFile(
                                                    "分享歌单", fname)
                                                if (path === "") return
                                                if (playlistManager.exportPlaylist(
                                                        root.currentId, path)) {
                                                    root.showToast("已导出到：" + path)
                                                } else {
                                                    root.showToast("导出失败")
                                                }
                                            }
                                        }
                                    }

                                    // 编辑封面
                                    Rectangle {
                                        Layout.preferredWidth: 100
                                        Layout.preferredHeight: 34
                                        radius: 0
                                        color: coverBtn.containsMouse ? Theme.hover : "transparent"
                                        border.color: Theme.border
                                        border.width: 1
                                        antialiasing: true

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

                                    // 删除
                                    Rectangle {
                                        Layout.preferredWidth: 100
                                        Layout.preferredHeight: 34
                                        radius: 0
                                        color: delBtn.containsMouse ? "#33e81123" : "transparent"
                                        border.color: delBtn.containsMouse ? "transparent" : Theme.border
                                        border.width: delBtn.containsMouse ? 0 : 1
                                        antialiasing: true
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "删除歌单"
                                            color: delBtn.containsMouse ? "#e81123" : Theme.textDim
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
                            Layout.leftMargin: Theme.contentSideMargin
                            Layout.rightMargin: Theme.contentSideMargin
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

                                delegate: Item {
                                    id: songRow
                                    width: songsList.width
                                    height: 64

                                    HoverHandler { id: rowHover }

                                    property bool isHover: rowHover.hovered

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.radius
                                        color: songRow.isHover ? Theme.hover : "transparent"
                                        antialiasing: true
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
                                            radius: 0
                                            color: Theme.panelAlt
                                            clip: true
                                            antialiasing: true

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
                                            radius: 0
                                            color: removeBtnArea.containsMouse ? "#e81123" : "transparent"
                                            border.color: removeBtnArea.containsMouse ? "transparent" : Theme.border
                                            border.width: removeBtnArea.containsMouse ? 0 : 1
                                            antialiasing: true
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
                                    policy: ScrollBar.AsNeeded; width: 3
                                    contentItem: Rectangle { radius: 0; color: Theme.textMuted; opacity: 0.45 }
                                }
                            }
                        }
                    }
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
        function close() { opacity = 0 }

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
            antialiasing: true

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
                    antialiasing: true

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
                            onClicked: newDialog.close()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 32
                        radius: 0
                        color: okBtn.containsMouse ? Theme.accentHover : Theme.accent
                        antialiasing: true

                        Text {
                            anchors.centerIn: parent
                            text: "创建"
                            color: Theme.ink
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
        function close() { opacity = 0 }

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
            antialiasing: true

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
                    antialiasing: true

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
                        radius: 0
                        color: cancelCoverBtn.containsMouse ? Theme.hover : "transparent"
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
                            id: cancelCoverBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: coverDialog.close()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 32
                        radius: 0
                        color: saveCoverBtn.containsMouse ? Theme.accentHover : Theme.accent
                        antialiasing: true

                        Text {
                            anchors.centerIn: parent
                            text: "保存"
                            color: Theme.ink
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
            antialiasing: true

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
                        radius: 0
                        color: cancelDelBtn.containsMouse ? Theme.hover : "transparent"
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
                            id: cancelDelBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: confirmDeleteDialog.close()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 32
                        radius: 0
                        color: confirmDelBtn.containsMouse ? "#cc0e1a" : "#e81123"
                        antialiasing: true

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
    // Hero 覆盖层
    // ============================================================
    HeroOverlay {
        id: hero
        onFinished: root.heroActive = false
    }

    // ============================================================
    // Toast
    // ============================================================
    Rectangle {
        id: toast
        parent: Overlay.overlay
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 80
        width: toastText.implicitWidth + 40
        height: 40
        radius: 0
        color: Theme.glassBgDeep
        opacity: 0
        visible: opacity > 0.01
        z: 3000
        antialiasing: true

        Behavior on opacity { NumberAnimation { duration: 200 } }

        Text {
            id: toastText
            anchors.centerIn: parent
            text: root.toastMsg
            color: Theme.textBright
            font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
        }

        Timer {
            id: toastTimer
            interval: 2500
            onTriggered: toast.opacity = 0
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