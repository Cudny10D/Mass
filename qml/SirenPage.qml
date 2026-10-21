import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

// ============================================================
// 发现音乐 / 曲目资料库
//
// 列表态：细线索引条 + 光盘盒网格
// 详情态：左侧资料栏（封面 + 编号 + 简介）｜ 右侧曲目表
//
// 视觉规则：不用卡片、不用阴影、不用玻璃；分隔靠 1px 线，
// 可点击的东西才是橄榄色，其余一律墨黑或灰。
// ============================================================
Item {
    id: root

    signal playListRequested(var songs, int index)

    property string mode: "albums"
    property string currentAlbumName: ""
    property string currentAlbumCid: ""
    property string currentAlbumCover: ""
    property string currentAlbumArtist: ""

    property bool showingAlbums: mode === "albums"
    property bool showingDetail: mode === "detail"
    property bool loadingDetail: false

    ListModel { id: albumModel }
    ListModel { id: songModel }

    Component.onCompleted: {
        if (albumModel.count === 0) networkManager.getAllAlbums()
    }

    function parseArtists(s, fallback) {
        try {
            if (!s) return fallback || ""

            function extractOne(a) {
                if (!a) return ""
                if (typeof a === "string") return a
                if (a.name) return a.name
                if (a.nickname) return a.nickname
                return ""
            }

            function extract(val) {
                if (!val) return ""
                if (typeof val === "string") return val
                if (Array.isArray(val)) {
                    let out = []
                    for (let i = 0; i < val.length; i++) {
                        let r = extractOne(val[i])
                        if (r) out.push(r)
                    }
                    return out.join(" / ")
                }
                return extractOne(val)
            }

            let fields = ["artistes", "artists", "ar", "artist",
                          "singers", "author", "authors"]
            for (let k = 0; k < fields.length; k++) {
                let v = s[fields[k]]
                if (v) {
                    let r = extract(v)
                    if (r) return r
                }
            }

            return fallback || ""
        } catch (e) {
            console.log("[Siren] parseArtists error:", e)
            return fallback || ""
        }
    }

    // [dev] 打开第一张专辑，便于截图核对（正式版可删）
    function devOpenFirstAlbum() {
        if (albumModel.count === 0) return
        var a = albumModel.get(0)
        root.currentAlbumName = a.name
        root.currentAlbumCid = a.cid
        root.currentAlbumCover = a.coverUrl
        root.currentAlbumArtist = a.artist
        songModel.clear()
        root.loadingDetail = true
        root.mode = "detail"
        networkManager.getAlbumDetail(a.cid)
    }

    function backToAlbums() {        root.mode = "albums"
        root.currentAlbumName = ""
        root.currentAlbumCid = ""
        root.currentAlbumCover = ""
        root.currentAlbumArtist = ""
    }

    // 小号等宽标签（全大写英文 + 中文）
    component MicroLabel: Text {
        color: Theme.textMuted
        font {
            family: Theme.monoFamily
            pixelSize: Theme.microSize
            letterSpacing: 1.4
        }
    }

    // 1px 细线
    component Hairline: Rectangle {
        height: 1
        color: Theme.border
        opacity: 0.55
    }

    // ══════════════════════════════════════════════════════════
    // 列表态
    // ══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        opacity: root.showingAlbums ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

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
                        text: "ALBUM INDEX / 唱片索引"
                        color: Theme.textDim
                        font {
                            family: Theme.monoFamily
                            pixelSize: Theme.labelSize
                            letterSpacing: 1.8
                        }
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Hairline {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        text: albumModel.count + " 张"
                        color: Theme.textMuted
                        font {
                            family: Theme.fontFamily
                            pixelSize: Theme.labelSize
                            letterSpacing: 1.2
                        }
                    }

                    // 刷新
                    Item {
                        width: 46; height: 24
                        Text {
                            anchors.centerIn: parent
                            text: "刷新"
                            color: refreshArea.containsMouse ? Theme.accentHover : Theme.textDim
                            font {
                                family: Theme.fontFamily
                                pixelSize: Theme.fs(11.5)
                            }
                        }
                        MouseArea {
                            id: refreshArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                albumModel.clear()
                                networkManager.getAllAlbums()
                            }
                        }
                    }
                }
            }

            // 网格
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 18
                clip: true

                Text {
                    anchors.centerIn: parent
                    visible: albumModel.count === 0
                    text: "正在读取唱片数据…"
                    color: Theme.textMuted
                    font {
                        family: Theme.monoFamily
                        pixelSize: Theme.labelSize
                        letterSpacing: 1.6
                    }
                }

                GridView {
                    id: albumsGrid
                    anchors.fill: parent
                    clip: true
                    bottomMargin: 28

                    readonly property var metrics: Theme.gridMetrics
                    property int columns: metrics.columns
                    property int gap: Theme.gridGap

                    cellWidth: metrics.cellWidth
                    cellHeight: Math.max(1, metrics.cellWidth + 62)

                    model: albumModel

                    delegate: Item {
                        width: albumsGrid.cellWidth
                        height: albumsGrid.cellHeight

                        property bool isHover: aArea.containsMouse

                        Item {
                            id: coverBox
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                leftMargin: albumsGrid.gap / 2
                                rightMargin: albumsGrid.gap / 2
                            }
                            height: width

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.panelAlt
                            }

                            Image {
                                anchors.fill: parent
                                anchors.margins: 1
                                source: model.coverUrl || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                sourceSize.width: 512
                                sourceSize.height: 512
                                smooth: true
                                mipmap: true
                            }

                            // 细描边：光盘盒的塑料边
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.width: 1
                                border.color: Theme.darkMode ? "#26FFFFFF" : "#33000000"
                            }

                            // 悬停：压暗 + 打开提示
                            Rectangle {
                                anchors.fill: parent
                                color: "#000000"
                                opacity: isHover ? 0.42 : 0
                                Behavior on opacity { NumberAnimation { duration: 140 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "打开 ↗"
                                    color: "#F2F0E9"
                                    opacity: isHover ? 1 : 0
                                    font {
                                        family: Theme.fontFamily
                                        pixelSize: Theme.fs(10)
                                        letterSpacing: 2
                                    }
                                    Behavior on opacity { NumberAnimation { duration: 140 } }
                                }
                            }
                        }

                        // 序号：像资料库里的条目号
                        Text {
                            id: numLabel
                            anchors {
                                left: coverBox.left
                                top: coverBox.bottom
                                topMargin: 8
                            }
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
                            text: model.name || ""
                            color: isHover ? Theme.textBright : Theme.text
                            font {
                                family: Theme.fontFamily
                                pixelSize: Theme.fs(12.5)
                                weight: Font.DemiBold
                            }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Behavior on color { ColorAnimation { duration: 110 } }
                        }

                        Text {
                            anchors {
                                left: numLabel.right
                                leftMargin: 10
                                right: coverBox.right
                                top: coverBox.bottom
                                topMargin: 24
                            }
                            text: model.artist || ""
                            color: Theme.textMuted
                            font {
                                family: Theme.fontFamily
                                pixelSize: Theme.microSize
                                letterSpacing: 0.3
                            }
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: aArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.currentAlbumName = model.name
                                root.currentAlbumCid = model.cid
                                root.currentAlbumCover = model.coverUrl
                                root.currentAlbumArtist = model.artist || ""
                                songModel.clear()
                                root.loadingDetail = true
                                root.mode = "detail"
                                networkManager.getAlbumDetail(model.cid)
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

    // ══════════════════════════════════════════════════════════
    // 详情态
    // ══════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        opacity: root.showingDetail ? 1 : 0
        visible: opacity > 0.01
        x: root.showingDetail ? 0 : 40
        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.contentSideMargin
            anchors.rightMargin: Theme.contentSideMargin
            spacing: 0

            // 返回
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        text: "←"
                        color: backArea.containsMouse ? Theme.accentHover : Theme.textDim
                        font { family: Theme.monoFamily; pixelSize: Theme.fs(13) }
                    }

                    Text {
                        text: "返回曲目资料库"
                        color: backArea.containsMouse ? Theme.accentHover : Theme.textDim
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(11.5) }
                    }

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

                MouseArea {
                    id: backArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backToAlbums()
                }
            }

            Hairline { Layout.fillWidth: true }

            // 主体：左资料栏 + 右曲目表
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 22
                spacing: 40

                // ── 左资料栏 ─────────────────────────────────
                Item {
                    Layout.preferredWidth: 244
                    Layout.fillHeight: true

                    Column {
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        spacing: 0

                        Rectangle {
                            width: parent.width
                            height: parent.width
                            color: Theme.panelAlt

                            Image {
                                anchors.fill: parent
                                anchors.margins: 1
                                source: root.currentAlbumCover || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                sourceSize.width: 768
                                sourceSize.height: 768
                                smooth: true
                                mipmap: true
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.width: 1
                                border.color: Theme.darkMode ? "#26FFFFFF" : "#33000000"
                            }
                        }

                        Item { width: 1; height: 18 }

                        MicroLabel {
                            text: "ALBUM / 专辑"
                        }

                        Item { width: 1; height: 6 }

                        Text {
                            width: parent.width
                            text: root.currentAlbumName || "专辑"
                            color: Theme.text
                            font {
                                family: Theme.displayFamily
                                pixelSize: Theme.fs(19)
                                bold: true
                                letterSpacing: 0.3
                            }
                            wrapMode: Text.Wrap
                        }

                        Item { width: 1; height: 6 }

                        Text {
                            width: parent.width
                            text: root.currentAlbumArtist || "MONSTER SIREN RECORDS"
                            color: Theme.textDim
                            font {
                                family: Theme.fontFamily
                                pixelSize: Theme.fs(11.5)
                            }
                            wrapMode: Text.Wrap
                        }

                        Item { width: 1; height: 18 }

                        // 技术信息：两列小字
                        Repeater {
                            model: [
                                { k: "SOURCE / 来源", v: "MONSTER SIREN" },
                                { k: "CATALOG / 编号", v: root.currentAlbumCid || "—" },
                                { k: "TRACKS / 曲目", v: songModel.count + " TRACKS" }
                            ]

                            delegate: Column {
                                width: parent.width
                                spacing: 3

                                Text {
                                    text: modelData.k
                                    color: Theme.textMuted
                                    font {
                                        family: Theme.monoFamily
                                        pixelSize: Theme.microSize
                                        letterSpacing: 1.2
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.v
                                    color: Theme.textDim
                                    font {
                                        family: Theme.monoFamily
                                        pixelSize: Theme.labelSize
                                        letterSpacing: 0.6
                                    }
                                    elide: Text.ElideRight
                                }

                                Item { width: 1; height: 10 }
                            }
                        }

                        Hairline { width: parent.width }

                        Item { width: 1; height: 12 }

                        Text {
                            width: parent.width
                            text: "该唱片收录于塞壬唱片资料库，曲目可直接播放。"
                            color: Theme.textMuted
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                            wrapMode: Text.Wrap
                            lineHeight: 1.5
                        }
                    }
                }

                // ── 右曲目表 ─────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        // 标题 + 播放全部
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                Layout.fillWidth: true
                                text: root.currentAlbumName || "专辑"
                                color: Theme.text
                                font {
                                    family: Theme.displayFamily
                                    pixelSize: Theme.fs(30)
                                    bold: true
                                    letterSpacing: 0.2
                                }
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                spacing: 16

                                // 播放全部
                                Rectangle {
                                    Layout.preferredWidth: playAllRow.implicitWidth + 36
                                    Layout.preferredHeight: 34
                                    color: playAllArea.containsMouse ? Theme.accentHover : Theme.accent
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    Row {
                                        id: playAllRow
                                        anchors.centerIn: parent
                                        spacing: 9

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "▶"
                                            color: Theme.ink
                                            font { family: Theme.monoFamily; pixelSize: Theme.fs(9) }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "播放全部"
                                            color: Theme.ink
                                            font {
                                                family: Theme.fontFamily
                                                pixelSize: Theme.fs(12)
                                                weight: Font.DemiBold
                                                letterSpacing: 0.4
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: playAllArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: songModel.count > 0
                                        onClicked: {
                                            var list = []
                                            for (var i = 0; i < songModel.count; i++) {
                                                var item = songModel.get(i)
                                                list.push({
                                                    cid: item.cid,
                                                    name: item.name,
                                                    artist: item.artist,
                                                    cover: root.currentAlbumCover
                                                })
                                            }
                                            root.playListRequested(list, 0)
                                        }
                                    }
                                }

                                Text {
                                    text: songModel.count + " TRACKS"
                                    color: Theme.textMuted
                                    font {
                                        family: Theme.monoFamily
                                        pixelSize: Theme.labelSize
                                        letterSpacing: 1.4
                                    }
                                }
                            }
                        }

                        Item { width: 1; height: 14 }

                        // 表头
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 26

                            RowLayout {
                                anchors.fill: parent
                                spacing: 16

                                MicroLabel {
                                    Layout.preferredWidth: 34
                                    text: "#"
                                }
                                MicroLabel {
                                    Layout.fillWidth: true
                                    text: "TITLE / 曲目"
                                }
                                MicroLabel {
                                    Layout.preferredWidth: 260
                                    text: "ARTIST / 歌手"
                                    visible: parent.width > 620
                                }
                                MicroLabel {
                                    Layout.preferredWidth: 54
                                    text: "PLAY"
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }

                        Hairline { Layout.fillWidth: true }

                        // 曲目列表
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            Text {
                                anchors.centerIn: parent
                                visible: root.loadingDetail && songModel.count === 0
                                text: "读取曲目…"
                                color: Theme.textMuted
                                font {
                                    family: Theme.monoFamily
                                    pixelSize: Theme.labelSize
                                    letterSpacing: 1.6
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !root.loadingDetail && songModel.count === 0
                                text: "此专辑暂无曲目"
                                color: Theme.textMuted
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                            }

                            ListView {
                                id: songListView
                                anchors.fill: parent
                                clip: true
                                spacing: 0
                                model: songModel
                                visible: songModel.count > 0
                                bottomMargin: 10

                                delegate: Item {
                                    width: songListView.width
                                    height: Theme.rowHeight

                                    property bool isHover: sArea.containsMouse

                                    Rectangle {
                                        anchors.fill: parent
                                        color: isHover ? Theme.hover : "transparent"
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }

                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 2; rightMargin: 6 }
                                        spacing: 16

                                        Text {
                                            Layout.preferredWidth: 34
                                            text: isHover ? "▶"
                                                       : (index + 1).toString().padStart(2, "0")
                                            color: isHover ? Theme.accentHover : Theme.textMuted
                                            font {
                                                family: Theme.monoFamily
                                                pixelSize: Theme.fs(10)
                                                letterSpacing: 0.8
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: model.name || ""
                                            color: Theme.text
                                            font {
                                                family: Theme.fontFamily
                                                pixelSize: Theme.fs(13)
                                                weight: Font.Normal
                                            }
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.preferredWidth: 260
                                            visible: parent.width > 620
                                            text: model.artist || ""
                                            color: Theme.textDim
                                            font {
                                                family: Theme.fontFamily
                                                pixelSize: Theme.fs(11.5)
                                            }
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.preferredWidth: 54
                                            text: "PLAY ↗"
                                            horizontalAlignment: Text.AlignRight
                                            color: isHover ? Theme.accentHover : "transparent"
                                            font {
                                                family: Theme.monoFamily
                                                pixelSize: Theme.microSize
                                                letterSpacing: 0.8
                                            }
                                        }
                                    }

                                    Hairline {
                                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                        opacity: isHover ? 0 : 0.45
                                    }

                                    MouseArea {
                                        id: sArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var list = []
                                            for (var i = 0; i < songModel.count; i++) {
                                                var item = songModel.get(i)
                                                list.push({
                                                    cid: item.cid,
                                                    name: item.name,
                                                    artist: item.artist,
                                                    cover: root.currentAlbumCover
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
            }
        }
    }

    Connections {
        target: networkManager

        function onAlbumsReady(albums) {
            console.log("[QML] albums:", albums.length)
            albumModel.clear()
            for (let i = 0; i < albums.length; i++) {
                let a = albums[i]
                albumModel.append({
                    cid: a.cid || "",
                    name: a.name || "",
                    coverUrl: a.coverUrl || "",
                    artist: root.parseArtists(a)
                })
            }
        }

        function onAlbumDetailReady(albumCid, songs) {
            console.log("[QML] album", albumCid, "songs:", songs.length)
            if (albumCid !== root.currentAlbumCid) return
            root.loadingDetail = false
            songModel.clear()
            for (let i = 0; i < songs.length; i++) {
                let s = songs[i]
                let artist = root.parseArtists(s, root.currentAlbumArtist)
                songModel.append({
                    cid: s.cid || "",
                    name: s.name || "",
                    artist: artist,
                    cover: root.currentAlbumCover || ""
                })
            }
        }
    }
}
