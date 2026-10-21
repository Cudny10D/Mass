import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

// ============================================================
// 音乐检索
//
// 搜索行：一条下划线输入，不做胶囊
// 结果：与曲目资料库同一套索引条 + 光盘盒网格
// 详情：左侧资料栏 + 右侧曲目表
// ============================================================
Item {
    id: root

    signal playListRequested(var songs, int index)

    property string detailMode: "results"
    property string currentTitle: ""
    property string currentArtist: ""
    property bool hasSearched: false
    property string currentAlbumCover: ""
    property bool historyOpen: false
    property var searchHistory: []
    property bool pendingSearch: false
    property bool searchActive: false
    property bool loadingDetail: false

    property bool showingResults: detailMode === "results"
    property bool showingDetail: detailMode !== "results"
    property bool showEmpty: searchActive && !hasSearched && showingResults
    property bool showResults: hasSearched && showingResults
    property bool resultIsEmpty: showResults && resultModel.count === 0

    ListModel { id: resultModel }
    ListModel { id: detailSongModel }

    function refreshSearchHistory() {
        searchHistory = appSettings.getSearchHistory()
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
            console.log("[Search] parseArtists error:", e)
            return fallback || ""
        }
    }

    function exitSearch() {
        root.pendingSearch = false
        root.hasSearched = false
        root.historyOpen = false
        resultModel.clear()
        detailSongModel.clear()
        root.detailMode = "results"
        root.currentTitle = ""
        root.currentArtist = ""
        root.currentAlbumCover = ""
        root.searchActive = false
        searchInput.focus = false
    }

    function doSearch() {
        let kw = searchInput.text.trim()
        if (kw === "") return

        appSettings.addSearchHistory(kw)
        root.historyOpen = false
        searchInput.focus = false

        root.pendingSearch = true
        networkManager.searchAlbums(kw)
    }

    // [dev] 截图核对用：直接跑一次搜索
    function devSearch(kw) {
        searchInput.text = kw
        doSearch()
    }

    function backToResults() {
        root.detailMode = "results"
    }

    Component.onCompleted: refreshSearchHistory()

    Connections {
        target: appSettings
        function onChanged() { root.refreshSearchHistory() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.contentSideMargin
        anchors.rightMargin: Theme.contentSideMargin
        spacing: 0

        // ══════════════════════════════════════════════════════
        // 搜索行
        // ══════════════════════════════════════════════════════
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 62
            Layout.topMargin: 6

            RowLayout {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 16

                Text {
                    text: "SEARCH / 检索"
                    color: Theme.textMuted
                    font {
                        family: Theme.monoFamily
                        pixelSize: Theme.microSize
                        letterSpacing: 1.8
                    }
                }

                Item {
                    Layout.fillWidth: true
                    height: 34

                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 1
                        color: searchInput.activeFocus ? Theme.accent : Theme.border
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }

                    TextInput {
                        id: searchInput
                        anchors { fill: parent; rightMargin: 30 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font {
                            family: Theme.fontFamily
                            pixelSize: Theme.fs(15)
                            letterSpacing: 0.3
                        }
                        selectByMouse: true
                        activeFocusOnPress: true
                        onAccepted: doSearch()
                        onTextChanged: {
                            if (text === "") root.exitSearch()
                        }
                        onActiveFocusChanged: {
                            if (activeFocus) {
                                root.searchActive = true
                                if (root.searchHistory.length > 0 && searchInput.text === "")
                                    root.historyOpen = true
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "输入专辑或艺人名称"
                            color: Theme.textMuted
                            visible: searchInput.text === ""
                            font {
                                family: Theme.fontFamily
                                pixelSize: Theme.fs(14)
                            }
                        }
                    }

                    // 清除
                    Item {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 22; height: 22
                        visible: searchInput.text !== ""

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: clearMouse.containsMouse ? Theme.danger : Theme.textMuted
                            font { family: Theme.monoFamily; pixelSize: Theme.fs(11) }
                        }
                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = ""
                                root.exitSearch()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 34
                    color: searchBtnMouse.containsMouse ? Theme.accentHover : Theme.accent
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: "搜索"
                        color: Theme.ink
                        font {
                            family: Theme.fontFamily
                            pixelSize: Theme.fs(12)
                            weight: Font.DemiBold
                            letterSpacing: 1
                        }
                    }

                    MouseArea {
                        id: searchBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: doSearch()
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.border
            opacity: 0.55
        }

        // ══════════════════════════════════════════════════════
        // 以下为内容区
        // ══════════════════════════════════════════════════════
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // ── 结果：索引条 + 网格 ─────────────────────────────
            Item {
                anchors.fill: parent
                opacity: root.showingResults ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 240 } }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.hasSearched ? 40 : 0
                        Layout.topMargin: root.hasSearched ? 10 : 0
                        visible: root.hasSearched

                        RowLayout {
                            anchors.fill: parent
                            spacing: 12

                            Text {
                                text: "RESULTS / 检索结果"
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
                                text: resultModel.count + " 张"
                                color: Theme.textMuted
                                font {
                                    family: Theme.fontFamily
                                    pixelSize: Theme.labelSize
                                    letterSpacing: 1.2
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.topMargin: 14
                        clip: true

                        // 空结果
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            visible: root.resultIsEmpty

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "NO RESULT"
                                color: Theme.textMuted
                                font {
                                    family: Theme.monoFamily
                                    pixelSize: Theme.fs(13)
                                    letterSpacing: 3
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "换个关键词再试一次"
                                color: Theme.textMuted
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(11.5) }
                            }
                        }

                        // 初始提示
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            visible: !root.hasSearched && !root.resultIsEmpty

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "TYPE TO SEARCH"
                                color: Theme.textMuted
                                font {
                                    family: Theme.monoFamily
                                    pixelSize: Theme.fs(13)
                                    letterSpacing: 3
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "输入关键词，回车开始检索塞壬唱片"
                                color: Theme.textMuted
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(11.5) }
                            }
                        }

                        GridView {
                            id: resultGrid
                            anchors.fill: parent
                            clip: true
                            visible: resultModel.count > 0

                            readonly property var metrics: Theme.gridMetrics
                            property int columns: metrics.columns
                            property int gap: Theme.gridGap

                            cellWidth: metrics.cellWidth
                            cellHeight: Math.max(1, metrics.cellWidth + 58)

                            model: resultModel

                            delegate: Item {
                                width: resultGrid.cellWidth
                                height: resultGrid.cellHeight
                                property bool isHover: rArea.containsMouse

                                Item {
                                    id: resultCoverItem
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        top: parent.top
                                        leftMargin: resultGrid.gap / 2
                                        rightMargin: resultGrid.gap / 2
                                    }
                                    height: width

                                    property real cornerRadius: 0

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
                                            text: "打开 ↗"
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
                                    id: resNum
                                    anchors { left: resultCoverItem.left; top: resultCoverItem.bottom; topMargin: 8 }
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
                                        left: resNum.right
                                        leftMargin: 10
                                        right: resultCoverItem.right
                                        top: resultCoverItem.bottom
                                        topMargin: 6
                                    }
                                    text: model.name || ""
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
                                        left: resNum.right
                                        leftMargin: 10
                                        right: resultCoverItem.right
                                        top: resultCoverItem.bottom
                                        topMargin: 24
                                    }
                                    text: model.artist || ""
                                    color: Theme.textMuted
                                    font {
                                        family: Theme.fontFamily
                                        pixelSize: Theme.microSize
                                    }
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: rArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.currentTitle = model.name
                                        root.currentArtist = model.artist
                                        root.currentAlbumCover = model.coverUrl
                                        root.detailMode = "album"
                                        root.loadingDetail = true
                                        detailSongModel.clear()
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

            // ── 详情 ───────────────────────────────────────────
            Item {
                anchors.fill: parent
                opacity: root.showingDetail ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 220 } }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // 返回
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        Layout.topMargin: 6

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Text {
                                text: "←"
                                color: backArea.containsMouse ? Theme.accentHover : Theme.textDim
                                font { family: Theme.monoFamily; pixelSize: Theme.fs(13) }
                            }
                            Text {
                                text: "返回检索结果"
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
                            onClicked: root.backToResults()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.border
                        opacity: 0.55
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.topMargin: 20
                        spacing: 40

                        // 左资料栏
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

                                Text {
                                    text: "ALBUM / 专辑"
                                    color: Theme.textMuted
                                    font {
                                        family: Theme.monoFamily
                                        pixelSize: Theme.microSize
                                        letterSpacing: 1.4
                                    }
                                }

                                Item { width: 1; height: 6 }

                                Text {
                                    width: parent.width
                                    text: root.currentTitle || "专辑"
                                    color: Theme.text
                                    font {
                                        family: Theme.displayFamily
                                        pixelSize: Theme.fs(19)
                                        bold: true
                                    }
                                    wrapMode: Text.Wrap
                                }

                                Item { width: 1; height: 6 }

                                Text {
                                    width: parent.width
                                    text: root.currentArtist || "MONSTER SIREN RECORDS"
                                    color: Theme.textDim
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(11.5) }
                                    wrapMode: Text.Wrap
                                }

                                Item { width: 1; height: 18 }

                                Text {
                                    text: "TRACKS / 曲目"
                                    color: Theme.textMuted
                                    font {
                                        family: Theme.monoFamily
                                        pixelSize: Theme.microSize
                                        letterSpacing: 1.2
                                    }
                                }
                                Item { width: 1; height: 3 }
                                Text {
                                    text: detailSongModel.count + " TRACKS"
                                    color: Theme.textDim
                                    font {
                                        family: Theme.monoFamily
                                        pixelSize: Theme.labelSize
                                        letterSpacing: 0.6
                                    }
                                }

                                Item { width: 1; height: 14 }

                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: Theme.border
                                    opacity: 0.55
                                }

                                Item { width: 1; height: 12 }

                                Text {
                                    width: parent.width
                                    text: "检索结果中的唱片资料，曲目可直接播放。"
                                    color: Theme.textMuted
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                                    wrapMode: Text.Wrap
                                    lineHeight: 1.5
                                }
                            }
                        }

                        // 右曲目表
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 0

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 20

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.currentTitle || "专辑"
                                        color: Theme.text
                                        font {
                                            family: Theme.displayFamily
                                            pixelSize: Theme.fs(30)
                                            bold: true
                                        }
                                        elide: Text.ElideRight
                                    }

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
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: playAllArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: detailSongModel.count > 0
                                            onClicked: {
                                                var list = []
                                                for (var i = 0; i < detailSongModel.count; i++) {
                                                    var item = detailSongModel.get(i)
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
                                }

                                Item { width: 1; height: 14 }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 26

                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 16

                                        Text {
                                            Layout.preferredWidth: 34
                                            text: "#"
                                            color: Theme.textMuted
                                            font {
                                                family: Theme.monoFamily
                                                pixelSize: Theme.microSize
                                                letterSpacing: 1.4
                                            }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: "TITLE / 曲目"
                                            color: Theme.textMuted
                                            font {
                                                family: Theme.monoFamily
                                                pixelSize: Theme.microSize
                                                letterSpacing: 1.4
                                            }
                                        }
                                        Text {
                                            Layout.preferredWidth: 240
                                            text: "ARTIST / 歌手"
                                            color: Theme.textMuted
                                            font {
                                                family: Theme.monoFamily
                                                pixelSize: Theme.microSize
                                                letterSpacing: 1.4
                                            }
                                            visible: parent.width > 600
                                        }
                                        Text {
                                            Layout.preferredWidth: 54
                                            horizontalAlignment: Text.AlignRight
                                            text: "PLAY"
                                            color: Theme.textMuted
                                            font {
                                                family: Theme.monoFamily
                                                pixelSize: Theme.microSize
                                                letterSpacing: 1.4
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Theme.border
                                    opacity: 0.55
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true

                                    Text {
                                        anchors.centerIn: parent
                                        visible: root.loadingDetail && detailSongModel.count === 0
                                        text: "读取曲目…"
                                        color: Theme.textMuted
                                        font {
                                            family: Theme.monoFamily
                                            pixelSize: Theme.labelSize
                                            letterSpacing: 1.6
                                        }
                                    }

                                    ListView {
                                        id: detailList
                                        anchors.fill: parent
                                        clip: true
                                        spacing: 0
                                        model: detailSongModel
                                        visible: detailSongModel.count > 0
                                        bottomMargin: 10

                                        delegate: Item {
                                            width: detailList.width
                                            height: Theme.rowHeight
                                            property bool isHover: dsArea.containsMouse

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
                                                    }
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    Layout.preferredWidth: 240
                                                    visible: parent.width > 600
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
                                                    horizontalAlignment: Text.AlignRight
                                                    text: "PLAY ↗"
                                                    color: isHover ? Theme.accentHover : "transparent"
                                                    font {
                                                        family: Theme.monoFamily
                                                        pixelSize: Theme.microSize
                                                        letterSpacing: 0.8
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                                height: 1
                                                color: Theme.border
                                                opacity: isHover ? 0 : 0.45
                                            }

                                            MouseArea {
                                                id: dsArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    var list = []
                                                    for (var i = 0; i < detailSongModel.count; i++) {
                                                        var item = detailSongModel.get(i)
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
        }
    }

    // ══════════════════════════════════════════════════════════
    // 搜索历史（悬在搜索行下方的平铺面板）
    // ══════════════════════════════════════════════════════════
    Item {
        id: historyPanel
        anchors {
            top: parent.top
            topMargin: 74
            left: parent.left
            leftMargin: Theme.contentSideMargin
        }
        width: Math.min(520, parent.width - Theme.contentSideMargin * 2)
        height: (root.historyOpen && root.searchActive && root.searchHistory.length > 0)
                ? historyCard.height : 0
        clip: true
        visible: height > 1
        z: 200
        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Rectangle {
            id: historyCard
            width: parent.width
            height: historyContent.implicitHeight + 26
            color: Theme.bg
            border.width: 1
            border.color: Theme.border

            Column {
                id: historyContent
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                spacing: 8

                Item {
                    width: parent.width
                    height: 20

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "RECENT / 最近检索"
                        color: Theme.textMuted
                        font {
                            family: Theme.monoFamily
                            pixelSize: Theme.microSize
                            letterSpacing: 1.6
                        }
                    }

                    Text {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: "清空"
                        color: clearHistoryBtn.containsMouse ? Theme.danger : Theme.textMuted
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(10.5) }

                        MouseArea {
                            id: clearHistoryBtn
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                appSettings.clearSearchHistory()
                                root.historyOpen = false
                            }
                        }
                    }
                }

                Repeater {
                    model: root.searchHistory

                    delegate: Item {
                        width: parent.width
                        height: 28

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "›  " + modelData
                            color: histMouse.containsMouse ? Theme.accentHover : Theme.textDim
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                        }

                        MouseArea {
                            id: histMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = modelData
                                root.historyOpen = false
                                doSearch()
                            }
                        }
                    }
                }
            }
        }
    }

    // 网络信号
    Connections {
        target: networkManager

        function onSearchAlbumsReady(albums, hasMore) {
            if (!root.pendingSearch) return
            root.pendingSearch = false
            root.hasSearched = true
            resultModel.clear()
            if (!albums) return
            for (let i = 0; i < albums.length; i++) {
                let a = albums[i]
                resultModel.append({
                    cid: a.cid || "",
                    name: a.name || "",
                    coverUrl: a.coverUrl || "",
                    artist: root.parseArtists(a)
                })
            }
        }

        function onAlbumsReady(albums) {
            if (!root.pendingSearch) return
            root.pendingSearch = false
            root.hasSearched = true
            resultModel.clear()
            if (!albums) return
            for (let i = 0; i < albums.length; i++) {
                let a = albums[i]
                resultModel.append({
                    cid: a.cid || "",
                    name: a.name || "",
                    coverUrl: a.coverUrl || "",
                    artist: root.parseArtists(a)
                })
            }
        }

        function onAlbumDetailReady(albumCid, songs) {
            root.loadingDetail = false
            detailSongModel.clear()
            if (!songs) return
            for (let i = 0; i < songs.length; i++) {
                let s = songs[i]
                let artist = root.parseArtists(s, root.currentArtist)
                detailSongModel.append({
                    cid: s.cid || "",
                    name: s.name || "",
                    artist: artist,
                    cover: root.currentAlbumCover || ""
                })
            }
        }
    }
}
