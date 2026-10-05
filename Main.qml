import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    width: 1240
    height: 820
    minimumWidth: 960
    minimumHeight: 640
    visible: true
    title: "Mass"
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint

    property bool bootLoading: true
    property bool bootAlbumsReceived: false

    property string viewMode: "siren"
    property string preFullscreenView: "siren"
    property var lyricLines: []
    property int currentLyricIndex: -1
    property string currentCover: ""
    property string currentTitle: ""
    property string currentArtist: ""
    property string currentSongCid: ""

    property var playQueue: []
    property int queueIndex: -1

    property var urlCache: ({})
    property var downloadingSet: ({})
    property var probeCache: ({})
    property bool playingLocalFile: false
    property string justPlayedByUrlHit: ""

    property bool fullscreenMode: viewMode === "player"
    property bool dockAutoHide: false
    property bool playerBarAutoHide: false
    property bool playlistOpen: false

    property real windowScale: 1.0
    property real windowOpacity: 1.0

    property bool textInputFocused: false

    readonly property int dockTriggerWidth: 180
    readonly property int playerTriggerHeight: 160
    readonly property int sideBarLeftMargin: 16
    readonly property int sideBarWidth: 56
    readonly property bool listLoop: audioEngine.loopMode === 2

    readonly property bool anyPickerOpen: playerBar.pickerVisible
                                            || playlistPanel.pickerVisible

    function updateUiScale() {
        let windowScale = width / 1240.0
        windowScale = Math.max(1.0, Math.min(1.35, windowScale))
        let userScale = appSettings.fontScale
        Theme.uiScale = Math.min(2.0, windowScale * userScale)
    }

    function updateTextInputFocus() {
        var item = root.activeFocusItem
        if (!item) { textInputFocused = false; return }
        textInputFocused = (typeof item.text !== "undefined") &&
                            (typeof item.cursorPosition !== "undefined")
    }

    onActiveFocusItemChanged: updateTextInputFocus()

    function toggleFullscreen() {
        if (root.viewMode === "player") root.viewMode = root.preFullscreenView
        else {
            root.preFullscreenView = root.viewMode
            root.viewMode = "player"
        }
    }

    function adjustVolume(delta) {
        let v = Math.max(0.0, Math.min(1.0, audioEngine.volume + delta))
        audioEngine.setVolume(v)
        root.showToast("音量 " + Math.round(v * 100) + "%")
    }

    function seekRelative(deltaMs) {
        let dur = audioEngine.duration
        if (dur <= 0) return
        let target = audioEngine.position + deltaMs
        if (target < 0) target = 0
        if (target > dur) target = dur
        audioEngine.seek(target)
        if (deltaMs > 0)
            root.showToast("快进 " + (deltaMs / 1000) + "s")
        else
            root.showToast("快退 " + (-deltaMs / 1000) + "s")
    }

    function handleEsc() {
        if (playerBar.pickerVisible) {
            playerBar.closePicker()
            return
        }
        if (playlistPanel.pickerVisible) {
            playlistPanel.closePicker()
            return
        }
        if (root.viewMode === "player") {
            root.viewMode = root.preFullscreenView
            return
        }
        if (root.playlistOpen) {
            root.playlistOpen = false
            return
        }
        if (root.viewMode === "siren" && sirenPage.mode === "detail") {
            sirenPage.mode = "albums"
            sirenPage.currentAlbumName = ""
            sirenPage.currentAlbumCid = ""
            sirenPage.currentAlbumCover = ""
            sirenPage.currentAlbumArtist = ""
            return
        }
        if (root.viewMode === "search" && searchPage.detailMode !== "results") {
            searchPage.detailMode = "results"
            searchPage.currentTitle = ""
            searchPage.currentArtist = ""
            searchPage.currentAlbumCover = ""
            return
        }
        if (root.viewMode === "playlist" && playlistPage.mode === "detail") {
            playlistPage.exitDetail()
            return
        }
    }

    function triggerDownload() {
        if (root.currentSongCid === "") return
        audioCache.downloadToLibrary(
            root.currentSongCid,
            root.currentTitle,
            root.currentArtist,
            "",
            root.currentCover,
            root.urlCache[root.currentSongCid] || ""
        )
    }

    function triggerAddToPlaylist() {
        if (root.currentSongCid === "") return
        playerBar.openPickerDialog()
    }

    // ============================================================
    // 全局快捷键
    // ============================================================
    Shortcut {
        sequence: "Space"
        onActivated: {
            if (root.textInputFocused || root.anyPickerOpen) return
            if (audioEngine.isPlaying()) audioEngine.pause()
            else audioEngine.resume()
        }
    }

    Shortcut {
        sequence: "F"
        onActivated: {
            if (root.textInputFocused || root.anyPickerOpen) return
            root.toggleFullscreen()
        }
    }

    Shortcut {
        sequence: "A"
        onActivated: {
            if (root.textInputFocused || root.anyPickerOpen) return
            root.playPrev()
        }
    }

    Shortcut {
        sequence: "D"
        onActivated: {
            if (root.textInputFocused || root.anyPickerOpen) return
            root.playNext()
        }
    }

    Shortcut {
        sequence: "Left"
        onActivated: {
            if (root.textInputFocused || root.anyPickerOpen) return
            root.seekRelative(-5000)
        }
    }

    Shortcut {
        sequence: "Right"
        onActivated: {
            if (root.textInputFocused || root.anyPickerOpen) return
            root.seekRelative(5000)
        }
    }

    Shortcut {
        sequence: "G"
        onActivated: {
            if (root.textInputFocused || root.anyPickerOpen) return
            root.playlistOpen = !root.playlistOpen
        }
    }

    Shortcut {
        sequence: "Up"
        onActivated: {
            if (root.textInputFocused || root.anyPickerOpen) return
            root.adjustVolume(0.05)
        }
    }

    Shortcut {
        sequence: "Down"
        onActivated: {
            if (root.textInputFocused || root.anyPickerOpen) return
            root.adjustVolume(-0.05)
        }
    }

    Shortcut {
        sequence: "Q"
        onActivated: {
            if (root.textInputFocused || root.anyPickerOpen) return
            root.triggerAddToPlaylist()
        }
    }

    Shortcut {
        sequence: "E"
        onActivated: {
            if (root.textInputFocused || root.anyPickerOpen) return
            root.triggerDownload()
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (root.anyPickerOpen) {
                root.handleEsc()
                return
            }
            if (root.textInputFocused) return
            root.handleEsc()
        }
    }

    Shortcut {
        sequence: "L"
        onActivated: {
            if (root.textInputFocused || root.anyPickerOpen) return
            if (root.viewMode !== "player") return
            fullPlayer.showLyrics = !fullPlayer.showLyrics
        }
    }

    Shortcut {
        sequence: "T"
        onActivated: {
            if (root.textInputFocused || root.anyPickerOpen) return
            if (root.viewMode !== "player") return
            fullPlayer.showTranslation = !fullPlayer.showTranslation
        }
    }

    Shortcut {
        sequence: "Ctrl+L"
        onActivated: {
            appSettings.desktopLyricEnabled = !appSettings.desktopLyricEnabled
            root.showToast(appSettings.desktopLyricEnabled
                           ? "桌面歌词已开启" : "桌面歌词已关闭")
        }
    }

    Component.onCompleted: {
        Theme.darkMode = appSettings.darkMode
        Theme.windowFullscreen = root.fullscreenMode
        updateUiScale()
        updateTextInputFocus()

        // 更新托盘歌曲信息
        systemTray.setCurrentSong(root.currentTitle, root.currentArtist)
        systemTray.setPlayingState(audioEngine.isPlaying())

        // 若上次状态为开启，立即显示桌面歌词
        if (appSettings.desktopLyricEnabled) {
            desktopLyric.show()
        }
    }

    onWidthChanged: updateUiScale()
    onHeightChanged: updateUiScale()

    onFullscreenModeChanged: {
        Theme.windowFullscreen = root.fullscreenMode
        if (!fullscreenMode) {
            dockAutoHide = false
            playerBarAutoHide = false
        } else {
            dockAutoHide = true
            playerBarAutoHide = true
        }
    }

    Connections {
        target: appSettings
        function onFontScaleChanged() { root.updateUiScale() }

        // ★ 桌面歌词开关
        function onDesktopLyricEnabledChanged() {
            if (appSettings.desktopLyricEnabled) {
                desktopLyric.show()
            } else {
                desktopLyric.hide()
            }
        }
    }

    // ★ 托盘菜单请求
    Connections {
        target: systemTray

        function onRequestTogglePlay() {
            if (audioEngine.isPlaying()) audioEngine.pause()
            else audioEngine.resume()
        }

        function onRequestPlayPrev() {
            root.playPrev()
        }

        function onRequestPlayNext() {
            root.playNext()
        }
    }

    Timer {
        id: bootFinishTimer
        interval: 800
        onTriggered: root.bootLoading = false
    }
    Timer {
        id: bootTimeoutTimer
        interval: 8000
        running: root.bootLoading
        onTriggered: root.bootLoading = false
    }

    function pauseForExit() {
        if (audioEngine.isPlaying()) audioEngine.pause()
    }

    Timer {
        id: minimizeAnimTimer
        interval: 200
        onTriggered: {
            root.showMinimized()
            root.windowScale = 1.0
            root.windowOpacity = 1.0
        }
    }
    Timer {
        id: hideToTrayAnimTimer
        interval: 200
        onTriggered: {
            systemTray.hideToTray()
            root.windowScale = 1.0
            root.windowOpacity = 1.0
        }
    }
    Timer {
        id: quitAnimTimer
        interval: 200
        onTriggered: {
            // ★ 退出应用前关闭桌面歌词
            desktopLyric.close()
            systemTray.quitApp()
        }
    }
    Timer {
        id: restartAnimTimer
        interval: 200
        onTriggered: {
            desktopLyric.close()
            appSettings.restartApp()
        }
    }

    function animateMinimize() {
        if (windowScale !== 1.0 || windowOpacity !== 1.0) return
        windowScale = 0.9
        windowOpacity = 0
        minimizeAnimTimer.start()
    }
    function animateHideToTray() {
        if (windowScale !== 1.0 || windowOpacity !== 1.0) return
        windowScale = 0.9
        windowOpacity = 0
        hideToTrayAnimTimer.start()
    }
    function animateQuit() {
        if (windowScale !== 1.0 || windowOpacity !== 1.0) return
        pauseForExit()
        windowScale = 0.9
        windowOpacity = 0
        quitAnimTimer.start()
    }
    function animateRestart() {
        if (windowScale !== 1.0 || windowOpacity !== 1.0) return
        pauseForExit()
        windowScale = 0.9
        windowOpacity = 0
        restartAnimTimer.start()
    }
    function animateClose() {
        if (windowScale !== 1.0 || windowOpacity !== 1.0) return
        if (appSettings.closeBehavior === "quit") {
            pauseForExit()
            windowScale = 0.9
            windowOpacity = 0
            quitAnimTimer.start()
        } else {
            windowScale = 0.9
            windowOpacity = 0
            hideToTrayAnimTimer.start()
        }
    }

    onClosing: (close) => {
        close.accepted = false
        animateClose()
    }

    Rectangle {
        anchors.fill: windowCard
        anchors.margins: -8
        radius: windowCard.radius + 4
        color: Theme.shadowDeep
        opacity: 0.35
        z: -1
    }

    Rectangle {
        id: windowCard
        anchors.fill: parent
        anchors.margins: 6
        radius: Theme.radiusWindow
        clip: true

        scale: root.windowScale
        opacity: root.windowOpacity

        transformOrigin: Item.Center
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Theme.gradientWindow[0]
                Behavior on color { ColorAnimation { duration: Theme.themeAnim } }
            }
            GradientStop {
                position: 1.0
                color: Theme.gradientWindow[1]
                Behavior on color { ColorAnimation { duration: Theme.themeAnim } }
            }
        }

        HoverHandler {
            id: globalHover
            onPointChanged: root.checkMousePosition(point.position.x, point.position.y)
            onHoveredChanged: {
                if (!hovered && root.fullscreenMode) {
                    root.dockAutoHide = true
                    root.playerBarAutoHide = true
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Item {
                id: titleBarWrapper
                Layout.fillWidth: true
                Layout.preferredHeight: titleBarWrapper.barHeight
                clip: true
                property real barHeight: root.fullscreenMode ? 0 : 44
                Behavior on barHeight {
                    NumberAnimation { duration: 340; easing.type: Easing.OutCubic }
                }
                TitleBar {
                    id: titleBar
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 44
                    onMinimizeRequested: root.animateMinimize()
                    onCloseRequested: root.animateClose()
                }
            }

            Item {
                id: contentArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                SirenPage {
                    id: sirenPage
                    anchors.fill: parent
                    visible: root.viewMode === "siren"
                    opacity: visible ? 1 : 0
                    x: visible ? 0 : -30
                    Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                    Behavior on x { NumberAnimation { duration: Theme.animNormal } }
                    onPlayListRequested: (songs, index) => root.playList(songs, index)
                }

                SearchPage {
                    id: searchPage
                    anchors.fill: parent
                    visible: root.viewMode === "search"
                    opacity: visible ? 1 : 0
                    x: visible ? 0 : -30
                    Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                    Behavior on x { NumberAnimation { duration: Theme.animNormal } }
                    onPlayListRequested: (songs, index) => root.playList(songs, index)
                }

                HistoryPage {
                    anchors.fill: parent
                    visible: root.viewMode === "history"
                    opacity: visible ? 1 : 0
                    x: visible ? 0 : -30
                    Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                    Behavior on x { NumberAnimation { duration: Theme.animNormal } }
                    onPlayListRequested: (songs, index) => root.playList(songs, index)
                }

                PlaylistPage {
                    id: playlistPage
                    anchors.fill: parent
                    visible: root.viewMode === "playlist"
                    opacity: visible ? 1 : 0
                    x: visible ? 0 : -30
                    Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                    Behavior on x { NumberAnimation { duration: Theme.animNormal } }
                    onPlayListRequested: (songs, index) => root.playList(songs, index)
                }

                SettingsPage {
                    id: settingsPage
                    anchors.fill: parent
                    visible: root.viewMode === "settings"
                    opacity: visible ? 1 : 0
                    x: visible ? 0 : 30
                    Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                    Behavior on x { NumberAnimation { duration: Theme.animNormal } }
                    onRequestHideToTray: root.animateHideToTray()
                    onRequestRestart: root.animateRestart()
                    onRequestQuit: root.animateQuit()
                }

                FullPlayer {
                    id: fullPlayer
                    anchors.fill: parent
                    visible: root.viewMode === "player"
                    opacity: visible ? 1 : 0
                    x: visible ? 0 : 30
                    Behavior on opacity { NumberAnimation { duration: Theme.animSlow } }
                    Behavior on x { NumberAnimation { duration: Theme.animSlow } }

                    coverUrl: root.currentCover
                    title: root.currentTitle
                    artist: root.currentArtist
                    lyricLines: root.lyricLines
                    currentLyricIndex: root.currentLyricIndex

                    onExitFullscreen: root.viewMode = root.preFullscreenView
                }
            }
        }

        SideBar {
            id: sideBar
            y: (parent.height - height) / 2
            x: root.dockAutoHide ? -(width + 40) : root.sideBarLeftMargin
            enabled: !root.dockAutoHide && !root.bootLoading
            Behavior on x { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
            currentPage: root.viewMode
            onPageChanged: (p) => { root.viewMode = p }
        }

        PlayerBar {
            id: playerBar
            x: 0
            width: parent.width
            y: root.playerBarAutoHide ? parent.height : parent.height - height
            enabled: !root.playerBarAutoHide && !root.bootLoading
            Behavior on y { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }

            coverUrl: root.currentCover
            title: root.currentTitle
            artist: root.currentArtist
            songCid: root.currentSongCid
            songUrl: root.urlCache[root.currentSongCid] || ""

            hasPrev: {
                if (root.playQueue.length === 0) return false
                if (root.queueIndex > 0) return true
                return root.listLoop && root.playQueue.length > 1
            }
            hasNext: {
                if (root.playQueue.length === 0) return false
                if (root.queueIndex < 0) return false
                if (root.queueIndex + 1 < root.playQueue.length) return true
                return root.listLoop && root.playQueue.length > 1
            }

            onPrevClicked: root.playPrev()
            onNextClicked: root.playNext()
            onFullscreenClicked: root.toggleFullscreen()
            onPlaylistClicked: root.playlistOpen = !root.playlistOpen
        }

        PlaylistPanel {
            id: playlistPanel
            anchors.fill: parent
            open: root.playlistOpen
            queue: root.playQueue
            currentCid: root.currentSongCid
            onRequestClose: root.playlistOpen = false
            onSongSelected: (index) => {
                if (index < 0 || index >= root.playQueue.length) return
                root.queueIndex = index
                let s = root.playQueue[index]
                root.playSong(s.cid, s.name, s.artist, s.cover)
            }
        }

        Rectangle {
            id: toast
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.playerBarAutoHide
                                 ? 24
                                 : (Theme.playerBarHeight + 30)
            width: toastText.implicitWidth + 40
            height: 40
            radius: 20
            color: Theme.glassBgDeep
            opacity: 0
            visible: opacity > 0
            z: 2000
            Behavior on anchors.bottomMargin {
                NumberAnimation { duration: 340; easing.type: Easing.OutCubic }
            }
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 4
                anchors.bottomMargin: -4
                radius: parent.radius
                color: Theme.shadowMedium
                opacity: 0.6
                z: -1
            }
            Text {
                id: toastText
                anchors.centerIn: parent
                color: Theme.textBright
                font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
            }
            Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
            Timer {
                id: toastTimer
                interval: 2500
                onTriggered: toast.opacity = 0
            }
        }

        Rectangle {
            id: bootOverlay
            anchors.fill: parent
            color: Theme.bg
            opacity: root.bootLoading ? 1 : 0
            visible: opacity > 0.01
            z: 99999
            enabled: root.bootLoading

            Behavior on opacity {
                NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
            }

            Column {
                anchors.centerIn: parent
                spacing: 22

                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: "qrc:/resources/app.ico"
                    sourceSize.width: 96
                    sourceSize.height: 96
                    width: 96
                    height: 96
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true

                    SequentialAnimation on opacity {
                        running: root.bootLoading
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "MASS"
                    color: Theme.text
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(20); bold: true; letterSpacing: 3 }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 80; height: 1; color: Theme.border; opacity: 0.5
                }
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 36; height: 36

                    Rectangle {
                        anchors.fill: parent
                        radius: 18
                        color: "transparent"
                        border.color: Theme.borderLight
                        border.width: 2
                        enabled: false
                    }
                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: Theme.accent
                        x: parent.width / 2 - width / 2
                        y: 0
                        transformOrigin: Item.Bottom
                        transform: Rotation {
                            origin.x: 3; origin.y: 15; angle: 0
                            NumberAnimation on angle {
                                running: root.bootLoading
                                from: 0; to: 360; duration: 1100
                                loops: Animation.Infinite
                            }
                        }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.bootAlbumsReceived ? "正在准备界面..." : "正在加载唱片数据..."
                    color: Theme.textDim
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12); letterSpacing: 1.5 }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Music Player"
                    color: Theme.textMuted
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(10); letterSpacing: 2 }
                    opacity: 0.6
                }
            }
        }
    }

    // ============================================================
    // 桌面歌词（不使用 visible 绑定，避免破坏 show/hide）
    // ============================================================
    DesktopLyric {
        id: desktopLyric
        lyricLines: root.lyricLines
        currentLyricIndex: root.currentLyricIndex
        songTitle: root.currentTitle
        songArtist: root.currentArtist
        showTranslation: appSettings.translateLyric
    }

    Connections {
        target: networkManager

        function onAlbumsReady(albums) {
            if (root.bootLoading && !root.bootAlbumsReceived) {
                root.bootAlbumsReceived = true
                if (albums && albums.length > 0) {
                    var urls = []
                    for (var i = 0; i < albums.length; i++) {
                        if (albums[i].coverUrl) urls.push(albums[i].coverUrl)
                    }
                    if (urls.length > 0) coverCache.prefetchAll(urls)
                }
                bootFinishTimer.restart()
            }
        }

        function onSongUrlReady(url, songCid) {
            if (songCid !== root.currentSongCid) return
            if (url && url !== "") audioMetadataProbe.probe(songCid, url)

            if (root.justPlayedByUrlHit === songCid) {
                root.justPlayedByUrlHit = ""
                if (url && url !== "") {
                    root.cacheUrl(songCid, url)
                    root.ensureLocalDownload(songCid, url)
                }
                return
            }

            if (url === "") {
                if (!root.playingLocalFile) {
                    root.showToast("无法播放：" + root.currentTitle)
                    playerBar.playing = false
                }
                return
            }
            root.cacheUrl(songCid, url)
            root.ensureLocalDownload(songCid, url)
            if (root.playingLocalFile) return
            audioEngine.play(url)
            playerBar.playing = true
        }

        // ★ 修改：本地缓存包优先，无条件使用歌词包翻译
        function onLyricReady(lyric, translated) {
            root.lyricLines = root.parseLrc(lyric, translated)
            root.currentLyricIndex = -1

            if (!lyric || lyric === "") return

            // 有本地歌词包时，无条件覆盖（不信任 API 返回的翻译）
            let hasCache = translationService.hasCached(root.currentSongCid)
            if (!hasCache && translated && translated !== "") {
                return
            }

            // 提取所有原文行
            let lines = []
            let re = /\[(\d+):(\d+)(?:[.:](\d+))?\](.*)/
            let rawLines = lyric.split("\n")
            for (let i = 0; i < rawLines.length; i++) {
                let m = re.exec(rawLines[i])
                if (m && m[4].trim() !== "") lines.push(m[4].trim())
            }
            if (lines.length === 0) return

            translationService.translateLyrics(root.currentSongCid, lines, "zh-CN")
        }

        function onSongUrlPrefetched(songCid, url) {
            if (!url || url === "") return
            root.cacheUrl(songCid, url)
            audioMetadataProbe.probe(songCid, url)
        }
    }

    Connections {
        target: audioEngine
        function onPositionChanged(pos) {
            if (!root.lyricLines || root.lyricLines.length === 0) return
            let idx = -1
            for (let i = 0; i < root.lyricLines.length; i++) {
                if (root.lyricLines[i].time <= pos) idx = i
                else break
            }
            root.currentLyricIndex = idx
        }
        function onPlaybackStateChanged(playing) {
            playerBar.playing = playing
            systemTray.setPlayingState(playing)
        }
        function onTrackFinished() { root.onTrackFinished() }
    }

    Connections {
        target: audioCache
        function onDownloadFinished(cid, localPath) {}
        function onDownloadFailed(cid) {}
        function onTranscodeFinished(cid, mp3Path) {}
        function onLibraryDownloadFinished(cid, savedPath) {
            root.showToast("已下载：" + savedPath)
        }
        function onLibraryDownloadFailed(cid, error) {
            root.showToast("下载失败：" + error)
        }
    }

    Connections {
        target: audioMetadataProbe
        function onProbeFinished(cid, durationMs, sampleRate, channels) {
            var cache = Object.assign({}, root.probeCache)
            cache[cid] = { durationMs: durationMs, sampleRate: sampleRate, channels: channels }
            root.probeCache = cache
        }
        function onProbeFailed(cid, error) {}
    }

    Connections {
        target: coverCache
        function onProgressChanged(done, total) {}
    }

    // ★ 修改：按“源文本”匹配翻译，避免行数不一致 / 重复行导致的错位
    Connections {
        target: translationService
        function onLyricsTranslated(cid, translated) {
            if (cid !== root.currentSongCid) return

            let cachedSource = translationService.getCachedSource(cid)
            let newLines = []

            if (cachedSource && cachedSource.length === translated.length
                    && cachedSource.length > 0) {
                // 按源文本匹配（重复行按出现次数依次对应）
                let mapping = {}
                for (let i = 0; i < cachedSource.length; i++) {
                    let key = cachedSource[i]
                    if (!mapping[key]) mapping[key] = []
                    mapping[key].push(translated[i])
                }

                let usedCount = {}
                for (let i = 0; i < root.lyricLines.length; i++) {
                    let line = root.lyricLines[i]
                    let key = line.text
                    let pool = mapping[key] || []
                    let used = usedCount[key] || 0
                    let tr = (used < pool.length) ? pool[used] : ""
                    usedCount[key] = used + 1

                    newLines.push({
                        time: line.time,
                        text: line.text,
                        translated: tr
                    })
                }
            } else {
                // 兜底：按索引
                for (let i = 0; i < root.lyricLines.length; i++) {
                    let line = root.lyricLines[i]
                    newLines.push({
                        time: line.time,
                        text: line.text,
                        translated: (i < translated.length) ? translated[i] : ""
                    })
                }
            }

            root.lyricLines = newLines
        }
        function onTranslateFailed(cid, error) {}
    }

    function cacheUrl(cid, url) {
        if (!cid || !url || url === "") return
        if (root.urlCache[cid] === url) return
        let c = Object.assign({}, root.urlCache)
        c[cid] = url
        root.urlCache = c
    }

    function ensureLocalDownload(cid, url) {
        if (!cid || !url || url === "") return
        if (root.downloadingSet[cid]) return
        if (audioCache.hasCache(cid)) return
        let d = Object.assign({}, root.downloadingSet)
        d[cid] = true
        root.downloadingSet = d
        audioCache.download(cid, url)
    }

    function prefetchNeighbors() {
        if (root.playQueue.length === 0) return
        let n = root.playQueue.length
        let idx = root.queueIndex
        let nextIdx = idx + 1
        if (nextIdx >= n && root.listLoop && n > 1) nextIdx = 0
        if (nextIdx < 0 || nextIdx >= n) return
        let s = root.playQueue[nextIdx]
        if (!s || !s.cid) return
        if (root.urlCache[s.cid]) {
            audioMetadataProbe.probe(s.cid, root.urlCache[s.cid])
            return
        }
        networkManager.prefetchSongInfo(s.cid)
    }

    function checkMousePosition(x, y) {
        if (!root.fullscreenMode) {
            if (root.dockAutoHide) root.dockAutoHide = false
            if (root.playerBarAutoHide) root.playerBarAutoHide = false
            return
        }

        root.dockAutoHide = !(x < root.dockTriggerWidth)
        root.playerBarAutoHide = !(y > windowCard.height - root.playerTriggerHeight)
    }

    function playList(songs, index) {
        if (!songs || songs.length === 0) return
        if (index < 0 || index >= songs.length) return
        root.playQueue = songs
        root.queueIndex = index
        let s = songs[index]
        root.playSong(s.cid, s.name, s.artist, s.cover)
    }

    function playNext() {
        if (root.playQueue.length === 0) {
            root.showToast("播放列表为空")
            return
        }
        if (root.queueIndex + 1 < root.playQueue.length) {
            root.queueIndex++
        } else if (root.listLoop && root.playQueue.length > 1) {
            root.queueIndex = 0
        } else {
            root.showToast("已经是最后一首了")
            return
        }
        let s = root.playQueue[root.queueIndex]
        root.playSong(s.cid, s.name, s.artist, s.cover)
    }

    function playPrev() {
        if (root.playQueue.length === 0) {
            root.showToast("播放列表为空")
            return
        }
        if (root.queueIndex > 0) {
            root.queueIndex--
        } else if (root.listLoop && root.playQueue.length > 1) {
            root.queueIndex = root.playQueue.length - 1
        } else {
            root.showToast("已经是第一首了")
            return
        }
        let s = root.playQueue[root.queueIndex]
        root.playSong(s.cid, s.name, s.artist, s.cover)
    }

    function onTrackFinished() {
        if (root.playQueue.length === 0) return
        if (root.queueIndex + 1 < root.playQueue.length) {
            root.queueIndex++
            let s = root.playQueue[root.queueIndex]
            root.playSong(s.cid, s.name, s.artist, s.cover)
        } else if (root.listLoop && root.playQueue.length > 1) {
            root.queueIndex = 0
            let s = root.playQueue[0]
            root.playSong(s.cid, s.name, s.artist, s.cover)
        } else {
            root.showToast("播放队列已结束")
        }
    }

    function playSong(cid, name, artist, cover) {
        root.currentSongCid = cid
        root.currentTitle = name
        root.currentArtist = artist
        root.currentCover = cover
        root.currentLyricIndex = -1
        root.lyricLines = []
        root.justPlayedByUrlHit = ""

        // ★ 更新托盘
        systemTray.setCurrentSong(name, artist)

        historyManager.addSong(cid, name, artist, cover)

        let localPath = audioCache.getLocalPath(cid)
        if (localPath !== "") {
            root.playingLocalFile = true
            audioEngine.play("file:///" + localPath)
            playerBar.playing = true
            if (root.urlCache[cid]) {
                audioMetadataProbe.probe(cid, root.urlCache[cid])
                networkManager.getSongInfo(cid)
            } else {
                networkManager.getSongInfo(cid)
            }
            root.prefetchNeighbors()
            return
        }

        let cached = root.urlCache[cid]
        if (cached && cached !== "") {
            root.playingLocalFile = false
            root.justPlayedByUrlHit = cid
            audioMetadataProbe.probe(cid, cached)
            audioEngine.play(cached)
            playerBar.playing = true
            networkManager.getSongInfo(cid)
            root.ensureLocalDownload(cid, cached)
            root.prefetchNeighbors()
            return
        }

        root.playingLocalFile = false
        networkManager.getSongInfo(cid)
        root.prefetchNeighbors()
    }

    function showToast(msg) {
        toastText.text = msg
        toast.opacity = 1
        toastTimer.restart()
    }

    function timeStrToMs(mm, ss, xx) {
        let m = parseInt(mm)
        let s = parseInt(ss)
        let ms = xx ? parseInt((xx + "000").substring(0, 3)) : 0
        return m * 60000 + s * 1000 + ms
    }

    function parseLrcToDict(text) {
        let dict = {}
        if (!text) return dict
        let lines = text.split("\n")
        let re = /\[(\d+):(\d+)(?:[.:](\d+))?\](.*)/
        for (let i = 0; i < lines.length; i++) {
            let m = re.exec(lines[i])
            if (m) {
                let t = timeStrToMs(m[1], m[2], m[3])
                let txt = m[4].trim()
                if (txt) dict[t] = txt
            }
        }
        return dict
    }

    function lookupTranslation(transDict, t) {
        if (transDict[t] !== undefined) return transDict[t]
        for (let off = 50; off <= 500; off += 50) {
            if (transDict[t - off] !== undefined) return transDict[t - off]
            if (transDict[t + off] !== undefined) return transDict[t + off]
        }
        return ""
    }

    function parseLrc(lrcText, transText) {
        if (!lrcText) return []
        let dict = parseLrcToDict(lrcText)
        let transDict = parseLrcToDict(transText)
        let out = []
        let keys = Object.keys(dict).map(k => parseInt(k)).sort((a, b) => a - b)
        for (let k of keys) {
            out.push({
                time: k,
                text: dict[k],
                translated: lookupTranslation(transDict, k)
            })
        }
        return out
    }
}