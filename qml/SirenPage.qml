import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models
import QtQuick.Effects

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

    ListModel { id: albumModel }
    ListModel { id: songModel }

    Component.onCompleted: {
        if (albumModel.count === 0) {
            networkManager.getAllAlbums()
        }
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

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                clip: true

                RowLayout {
                    anchors { fill: parent; leftMargin: 96; rightMargin: 32 }
                    spacing: 12
                    opacity: root.showingAlbums ? 1 : 0
                    x: root.showingAlbums ? 0 : -40
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                    Text {
                        text: "Monster Siren Records"
                        color: Theme.text
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(18); bold: true }
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 32
                        radius: 16
                        color: refreshBtn.containsMouse ? Theme.accentHover : Theme.accent
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
                            opacity: Theme.darkMode ? 0.5 : 0.15
                            enabled: false
                        }

                        Text {
                            anchors.centerIn: parent; text: "刷新"
                            color: Theme.darkMode ? "#000000" : "#ffffff"
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                        }

                        MouseArea {
                            id: refreshBtn; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                albumModel.clear()
                                networkManager.getAllAlbums()
                            }
                        }
                    }

                    Text {
                        text: albumModel.count + " 张专辑"
                        color: Theme.textDim
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                    }
                }

                Rectangle {
                    id: backPill
                    anchors.centerIn: parent
                    height: 32
                    width: Math.max(100,
                                    Math.min(parent.width - 80,
                                             backRow.implicitWidth + 32))
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
                        enabled: false
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
                            text: root.currentAlbumName || "返回"
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
                        onClicked: {
                            root.mode = "albums"
                            root.currentAlbumName = ""
                            root.currentAlbumCid = ""
                            root.currentAlbumCover = ""
                            root.currentAlbumArtist = ""
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // ============================================================
                // 专辑网格
                // ============================================================
                Item {
                    anchors.fill: parent
                    opacity: root.showingAlbums ? 1 : 0
                    x: root.showingAlbums ? 0 : -60
                    visible: opacity > 0.01

                    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 12
                        visible: albumModel.count === 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "◈"; color: Theme.accent
                            font.pixelSize: 48; opacity: 0.6
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "正在加载塞壬唱片..."
                            color: Theme.textDim
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                        }
                    }

                    GridView {
                        id: albumsGrid
                        anchors.fill: parent
                        anchors.leftMargin: 96
                        anchors.rightMargin: 32
                        // ★ 恢复：让内容能滚进遮罩区（模糊效果可见）
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        clip: true

                        property int columns: 5
                        property int gap: 24

                        cellWidth: Math.max(1, width / columns)
                        cellHeight: Math.max(1, cellWidth + 64)

                        model: albumModel

                        delegate: Item {
                            width: albumsGrid.cellWidth
                            height: albumsGrid.cellHeight

                            property bool isHover: aArea.containsMouse

                            Column {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    leftMargin: albumsGrid.gap / 2
                                    rightMargin: albumsGrid.gap / 2
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
                                        source: model.coverUrl || ""
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
                                        enabled: false
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
                                        enabled: false
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
                                    text: model.name || ""
                                    color: isHover ? Theme.accent : Theme.text
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12); weight: Font.Medium }
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                Text {
                                    width: parent.width
                                    text: model.artist || ""
                                    color: Theme.textDim
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: aArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.currentAlbumName = model.name
                                    root.currentAlbumCid = model.cid
                                    root.currentAlbumCover = model.coverUrl
                                    root.currentAlbumArtist = model.artist || ""
                                    root.mode = "detail"
                                    songModel.clear()
                                    networkManager.getAlbumDetail(model.cid)
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
                // 专辑详情（避开遮罩）
                // ============================================================
                Item {
                    anchors.fill: parent
                    opacity: root.showingDetail ? 1 : 0
                    x: root.showingDetail ? 0 : 60
                    visible: opacity > 0.01

                    Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        anchors {
                            fill: parent
                            leftMargin: 96
                            rightMargin: 32
                            topMargin: 60
                            bottomMargin: 130
                        }
                        spacing: 18

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 180
                            spacing: 24

                            Item {
                                Layout.preferredWidth: 180
                                Layout.preferredHeight: 180

                                property real cornerRadius: 12

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.cornerRadius
                                    color: Theme.panelAlt
                                }

                                Image {
                                    id: bigCoverImg
                                    anchors.fill: parent
                                    source: root.currentAlbumCover || ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize.width: 360
                                    sourceSize.height: 360
                                    visible: false
                                    layer.enabled: true
                                }

                                Item {
                                    id: bigCoverMask
                                    anchors.fill: parent
                                    visible: false
                                    layer.enabled: true

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.parent.cornerRadius
                                        color: "white"
                                    }
                                }

                                MultiEffect {
                                    anchors.fill: parent
                                    source: bigCoverImg
                                    visible: bigCoverImg.status === Image.Ready
                                    maskEnabled: true
                                    maskSource: bigCoverMask
                                    enabled: false
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "♪"
                                    color: Theme.textMuted
                                    font.pixelSize: 56
                                    visible: bigCoverImg.status !== Image.Ready
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.topMargin: 8
                                    anchors.leftMargin: 4
                                    radius: parent.cornerRadius
                                    color: Theme.shadowDeep
                                    opacity: 0.35
                                    z: -1
                                    enabled: false
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 10

                                Text {
                                    text: root.currentAlbumName || "专辑"
                                    color: Theme.text
                                    font {
                                        family: Theme.fontFamily
                                        pixelSize: Theme.fs(28)
                                        bold: true
                                        letterSpacing: 0.3
                                    }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: root.currentAlbumArtist || "Monster Siren Records"
                                    color: Theme.textDim
                                    font {
                                        family: Theme.fontFamily
                                        pixelSize: Theme.fs(14)
                                        letterSpacing: 0.2
                                    }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    spacing: 12

                                    Rectangle {
                                        Layout.preferredHeight: 24
                                        Layout.preferredWidth: countText.implicitWidth + 20
                                        radius: 12
                                        color: Theme.darkMode ? "#1effffff" : "#0a000000"
                                        enabled: false

                                        Text {
                                            id: countText
                                            anchors.centerIn: parent
                                            text: songModel.count + " 首歌曲"
                                            color: Theme.textDim
                                            font {
                                                family: Theme.fontFamily
                                                pixelSize: Theme.fs(11)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.borderLight
                            opacity: 0.6
                            enabled: false
                        }

                        ListView {
                            id: songListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 4
                            model: songModel

                            delegate: Item {
                                width: songListView.width
                                height: 60
                                property bool isHover: sArea.containsMouse

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.topMargin: 2; anchors.bottomMargin: 2
                                    radius: Theme.radius
                                    color: isHover ? Theme.hover : "transparent"
                                    enabled: false
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Rectangle {
                                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                        width: 3
                                        height: isHover ? 28 : 0
                                        radius: 1.5
                                        color: Theme.accent
                                        enabled: false
                                        Behavior on height {
                                            NumberAnimation {
                                                duration: Theme.animNormal
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                                    spacing: 16

                                    Text {
                                        Layout.preferredWidth: 28
                                        text: (index + 1).toString().padStart(2, "0")
                                        color: isHover ? Theme.accent : Theme.textDim
                                        font {
                                            family: Theme.fontFamily
                                            pixelSize: Theme.fs(13)
                                            bold: isHover
                                        }
                                        horizontalAlignment: Text.AlignHCenter
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: model.name || ""
                                            color: Theme.text
                                            font {
                                                family: Theme.fontFamily
                                                pixelSize: Theme.fs(14)
                                                weight: Font.Medium
                                            }
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: model.artist || ""
                                            color: Theme.textDim
                                            font {
                                                family: Theme.fontFamily
                                                pixelSize: Theme.fs(12)
                                            }
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                            visible: text !== ""
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 34
                                        Layout.preferredHeight: 34
                                        radius: 17
                                        color: Theme.accent
                                        opacity: isHover ? 1 : 0
                                        scale: isHover ? 1.0 : 0.8
                                        enabled: false
                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                        Behavior on scale { NumberAnimation { duration: 150 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "▶"
                                            color: Theme.darkMode ? "#000000" : "#ffffff"
                                            font { pixelSize: 12; bold: true }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: sArea; anchors.fill: parent; hoverEnabled: true
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

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    height: 1
                                    color: Theme.borderLight
                                    visible: !isHover && index < songModel.count - 1
                                    enabled: false
                                }
                            }

                            ScrollBar.vertical: ScrollBar {
                                active: true; policy: ScrollBar.AsNeeded; width: 6
                                contentItem: Rectangle { radius: 3; color: Theme.textMuted; opacity: 0.4 }
                            }
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