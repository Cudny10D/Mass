import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models
import QtQuick.Effects

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

    // ★ 搜索是否激活（搜索框在上方）
    property bool searchActive: false

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

    // ============================================================
    // ★ 退出搜索（点叉号）：清空 + 淡出结果 + 搜索框回中间
    // ============================================================
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
        console.log("[Search] doSearch called, kw =", kw)
        if (kw === "") return

        appSettings.addSearchHistory(kw)
        root.historyOpen = false
        searchInput.focus = false

        root.pendingSearch = true
        networkManager.searchAlbums(kw)
    }

    Component.onCompleted: refreshSearchHistory()

    Connections {
        target: appSettings
        function onChanged() {
            root.refreshSearchHistory()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        // ============================================================
        // 内容区（结果 + 详情）—— 避开搜索框和播放器
        // ============================================================
        Item {
            id: contentArea
            anchors.fill: parent
            anchors.topMargin: 72
            anchors.bottomMargin: 100
            clip: true
            opacity: (root.showResults || root.showingDetail) ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity {
                NumberAnimation { duration: 340; easing.type: Easing.OutCubic }
            }

            // 空结果状态
            Column {
                anchors.centerIn: parent
                spacing: 16
                opacity: root.resultIsEmpty ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "⌕"
                    color: Theme.textMuted
                    font.pixelSize: 56
                    opacity: 0.4
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "未找到相关专辑"
                    color: Theme.textDim
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(14) }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "换个关键词试试"
                    color: Theme.textMuted
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                }
            }

            // 结果网格
            Item {
                anchors.fill: parent
                opacity: root.showResults ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                GridView {
                    id: resultGrid
                    anchors.fill: parent
                    anchors.leftMargin: 96
                    anchors.rightMargin: 32
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8
                    clip: true

                    property int columns: 5
                    property int gap: 24

                    cellWidth: Math.max(1, width / columns)
                    cellHeight: Math.max(1, cellWidth + 64)

                    model: resultModel

                    delegate: Item {
                        width: resultGrid.cellWidth
                        height: resultGrid.cellHeight
                        property bool isHover: rArea.containsMouse

                        Column {
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                leftMargin: resultGrid.gap / 2
                                rightMargin: resultGrid.gap / 2
                            }
                            spacing: 6

                            Item {
                                id: resultCoverItem
                                width: parent.width
                                height: parent.width

                                property real cornerRadius: 10

                                Rectangle {
                                    anchors.fill: parent
                                    radius: resultCoverItem.cornerRadius
                                    color: Theme.panelAlt
                                }

                                Image {
                                    id: resultCoverImg
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
                                    id: resultMaskSource
                                    anchors.fill: parent
                                    visible: false
                                    layer.enabled: true
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: resultCoverItem.cornerRadius
                                        color: "white"
                                        antialiasing: true
                                        smooth: true
                                    }
                                }

                                MultiEffect {
                                    anchors.fill: parent
                                    source: resultCoverImg
                                    visible: resultCoverImg.status === Image.Ready
                                    maskEnabled: true
                                    maskSource: resultMaskSource
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "♪"
                                    color: Theme.textMuted
                                    font.pixelSize: 28
                                    visible: resultCoverImg.status !== Image.Ready
                                }

                                transform: Scale {
                                    origin.x: resultCoverItem.width / 2
                                    origin.y: resultCoverItem.height / 2
                                    xScale: isHover ? 1.03 : 1.0
                                    yScale: isHover ? 1.03 : 1.0
                                    Behavior on xScale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    Behavior on yScale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: resultCoverItem.cornerRadius
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
                                font {
                                    family: Theme.fontFamily
                                    pixelSize: Theme.fs(12)
                                    weight: Font.Medium
                                }
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
                            id: rArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.currentTitle = model.name
                                root.currentArtist = model.artist
                                root.currentAlbumCover = model.coverUrl
                                root.detailMode = "album"
                                detailSongModel.clear()
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

            // 专辑详情
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
                        bottomMargin: 20
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
                                id: searchBigCoverImg
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
                                id: searchBigCoverMask
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
                                source: searchBigCoverImg
                                visible: searchBigCoverImg.status === Image.Ready
                                maskEnabled: true
                                maskSource: searchBigCoverMask
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "♪"
                                color: Theme.textMuted
                                font.pixelSize: 56
                                visible: searchBigCoverImg.status !== Image.Ready
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
                                text: root.currentTitle || "专辑"
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
                                text: root.currentArtist || "Monster Siren Records"
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
                                    Layout.preferredWidth: searchCountText.implicitWidth + 20
                                    radius: 12
                                    color: Theme.darkMode ? "#1effffff" : "#0a000000"
                                    enabled: false

                                    Text {
                                        id: searchCountText
                                        anchors.centerIn: parent
                                        text: detailSongModel.count + " 首歌曲"
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
                        id: detailSongListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        model: detailSongModel

                        delegate: Item {
                            width: detailSongListView.width
                            height: 60
                            property bool isHover: dsArea.containsMouse

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
                                id: dsArea
                                anchors.fill: parent
                                hoverEnabled: true
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

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                height: 1
                                color: Theme.borderLight
                                visible: !isHover && index < detailSongModel.count - 1
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
        }

        // ============================================================
        // 搜索历史（激活后显示在搜索框下方）
        // ============================================================
        Item {
            id: historyPanel
            anchors.top: parent.top
            anchors.topMargin: 72
            anchors.left: parent.left
            anchors.right: parent.right
            height: (root.historyOpen && root.searchActive && root.searchHistory.length > 0)
                    ? Math.min(historyCard.height + 16, parent.height - 120)
                    : 0
            clip: true
            visible: opacity > 0.01
            opacity: height > 1 ? 1 : 0
            z: 200

            Behavior on height {
                NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
            }

            Rectangle {
                id: historyCard
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: 4
                    leftMargin: 96
                    rightMargin: 32
                }
                height: historyContent.implicitHeight + 32
                radius: Theme.radiusLarge
                color: Theme.panel
                border.color: Theme.border
                border.width: 1

                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    anchors.margins: 1
                    height: parent.height * 0.4
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.glassHighlight }
                        GradientStop { position: 1.0; color: "#00ffffff" }
                    }
                    opacity: 0.2
                    enabled: false
                }

                Column {
                    id: historyContent
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 16
                    }
                    spacing: 12

                    Item {
                        width: parent.width
                        height: 26

                        Text {
                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }
                            text: "搜索历史"
                            color: Theme.text
                            font {
                                family: Theme.fontFamily
                                pixelSize: Theme.fs(13)
                                bold: true
                            }
                        }

                        Rectangle {
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }
                            width: 100
                            height: 26
                            radius: 13
                            color: clearHistoryBtn.containsMouse ? Theme.hover : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "清空搜索历史"
                                color: clearHistoryBtn.containsMouse ? "#e81123" : Theme.textDim
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                            }

                            MouseArea {
                                id: clearHistoryBtn
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    appSettings.clearSearchHistory()
                                    root.historyOpen = false
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.borderLight
                        opacity: 0.6
                        enabled: false
                    }

                    Flow {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: root.searchHistory

                            delegate: Rectangle {
                                width: pillText.implicitWidth + 28
                                height: 32
                                radius: 16
                                color: pillMouse.containsMouse
                                       ? Theme.accent
                                       : (Theme.darkMode ? "#20ffffff" : "#e0e0e0")
                                border.color: pillMouse.containsMouse
                                              ? "transparent"
                                              : Theme.border
                                border.width: pillMouse.containsMouse ? 0 : 1

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Text {
                                    id: pillText
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: pillMouse.containsMouse
                                           ? (Theme.darkMode ? "#000000" : "#ffffff")
                                           : Theme.text
                                    font {
                                        family: Theme.fontFamily
                                        pixelSize: Theme.fs(12)
                                    }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                MouseArea {
                                    id: pillMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
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
        }

        // ============================================================
        // ★ 搜索框（浮在最上层）
        //   初始居中 → 激活后平移到上方
        // ============================================================
        Item {
            id: searchBoxContainer
            width: Math.min(parent.width - 80, 560)
            height: 44
            anchors.horizontalCenter: parent.horizontalCenter
            z: 300

            // 位置：激活后在上方（16），否则居中
            y: root.searchActive
               ? 16
               : (parent.height - height) / 2
            Behavior on y {
                NumberAnimation {
                    duration: 420
                    easing.type: Easing.OutCubic
                }
            }

            // 搜索框主体
            Rectangle {
                id: searchBox
                anchors.fill: parent
                radius: height / 2
                color: Theme.darkMode ? "#1effffff" : "#0a000000"
                border.color: searchInput.activeFocus ? Theme.accent : "transparent"
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    anchors.margins: 1
                    height: parent.height / 2
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#1affffff" }
                        GradientStop { position: 1.0; color: "#00ffffff" }
                    }
                    opacity: 0.6
                    enabled: false
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
                    spacing: 8

                    Text {
                        text: "⌕"
                        color: Theme.textDim
                        font.pixelSize: Theme.fs(16)
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                        selectByMouse: true
                        activeFocusOnPress: true
                        onAccepted: doSearch()
                        onActiveFocusChanged: {
                            if (activeFocus) {
                                // ★ 点击搜索框 → 激活 + 平移到上方
                                root.searchActive = true
                                if (root.searchHistory.length > 0
                                        && searchInput.text === "") {
                                    root.historyOpen = true
                                }
                            }
                        }
                    }

                    // 清除按钮（叉号）—— 清空 + 退出搜索状态
                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: 13
                        color: clearMouse.containsMouse ? Theme.hover : "transparent"
                        visible: searchInput.text !== ""

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: clearMouse.containsMouse ? Theme.danger : Theme.textDim
                            font.pixelSize: Theme.fs(12)
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                searchInput.text = ""
                                root.exitSearch()
                            }
                        }
                    }

                    // 搜索按钮（只在有文字时显示）
                    Rectangle {
                        Layout.preferredWidth: 66
                        Layout.preferredHeight: 30
                        radius: 15
                        color: searchBtnMouse.containsMouse ? Theme.accentHover : Theme.accent
                        visible: searchInput.text !== ""
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            anchors.centerIn: parent
                            text: "搜索"
                            color: Theme.darkMode ? "#000000" : "#ffffff"
                            font {
                                family: Theme.fontFamily
                                pixelSize: Theme.fs(12)
                                bold: true
                            }
                        }

                        MouseArea {
                            id: searchBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: doSearch()
                        }
                    }
                }
            }

            // 占位提示（未激活、无文字时显示）
            Text {
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 40
                    rightMargin: 40
                }
                text: "搜索塞壬唱片"
                color: Theme.textMuted
                font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                visible: searchInput.text === "" && !searchInput.activeFocus
                z: -1
                enabled: false
            }
        }
    }

    // ============================================================
    // 网络信号
    // ============================================================
    Connections {
        target: networkManager

        function onSearchAlbumsReady(albums, hasMore) {
            // 只有本次搜索请求发出的才响应
            if (!root.pendingSearch) return
            root.pendingSearch = false

            console.log("[Search] onSearchAlbumsReady, count =",
                        albums ? albums.length : -1,
                        "hasMore =", hasMore)

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

        // 本地搜索 fallback（也走 albumsReady）
        function onAlbumsReady(albums) {
            // ★ 只有本次搜索请求发出的才响应
            if (!root.pendingSearch) return
            root.pendingSearch = false

            console.log("[Search] onAlbumsReady (local), count =",
                        albums ? albums.length : -1)

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
            console.log("[Search] onAlbumDetailReady, count =", songs ? songs.length : -1)
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