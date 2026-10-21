import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Window

ApplicationWindow {
    id: root
    // 默认窗口大小按屏幕等比给出（基准：2560x1440 下 1240x820）。
    // Screen 给的是逻辑像素，所以 DPI 缩放比会被自然吸收，
    // 不同分辨率/缩放比下观感一致。
    width:  Math.round(Math.max(880, Math.min(1760, Screen.width  * 0.484)))
    height: Math.round(Math.max(600, Math.min(1140, Screen.height * 0.570)))
    minimumWidth: 880
    minimumHeight: 600
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
    property var pendingMachineLines: []
    property string pendingLyricCid: ""
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

    // 顶部导航高亮用：全屏播放器不属于任何页签，沿用进入前的页
    readonly property string navPage: viewMode === "player" ? preFullscreenView : viewMode

    // 顶部大标题：跟随当前页（与参考项目一致，详情页显示专辑名）
    readonly property string pageTitle: {
        if (viewMode === "siren")
            return sirenPage.showingDetail ? (sirenPage.currentAlbumName || "专辑资料")
                                           : "曲目资料库"
        if (viewMode === "search")
            return searchPage.detailMode !== "results" ? (searchPage.currentTitle || "音乐检索")
                                                       : "音乐检索"
        if (viewMode === "local") return "本地文件"
        if (viewMode === "history") return "播放历史"
        if (viewMode === "playlist") return "我的音乐"
        if (viewMode === "settings") return "设置"
        if (viewMode === "player") return root.currentTitle || "正在播放"
        return "MASS"
    }

    // 用 windowState 而不是宽度比对来判断最大化：
    // showMaximized() 真正生效前 width 还是旧值，按宽度判断会在切换瞬间误判。
    readonly property bool windowMaximized: root.windowState === Qt.WindowMaximized

    property real windowScale: 1.0
    property real windowOpacity: 1.0

    property bool textInputFocused: false

    readonly property int dockTriggerWidth: appSettings.dockTriggerWidth
    readonly property int playerTriggerHeight: appSettings.playerTriggerHeight
    readonly property int sideBarLeftMargin: 16
    readonly property int sideBarWidth: 56
    readonly property bool listLoop: audioEngine.loopMode === 2
    readonly property bool shuffleMode: audioEngine.loopMode === 3

    readonly property bool anyPickerOpen: playerBar.pickerVisible
                                            || playlistPanel.pickerVisible

    function isLocalPath(p) {
        if (!p) return false
        return p.startsWith("file://") || p.startsWith("/")
            || (p.length > 2 && p[1] === ":")
    }

    function updateUiScale() {
        // 基准 1240 逻辑宽对应 1.0。上限保持 1.35：
        // 最大化时「铺满空间」交给网格自适应列数（Theme.gridMetrics），
        // 如果这里放开到 1.8，字号会撞上固定像素的封面/按钮，反而又空又小。
        let uiScale = width / 1240.0
        uiScale = Math.max(0.72, Math.min(1.35, uiScale))
        let userScale = appSettings.fontScale
        Theme.uiScale = Math.min(2.0, uiScale * userScale)
        // 内容留白与网格列数都只跟窗口宽度走（页面网格读这两个值，
        // 避免在 GridView 内部反推造成布局抖动）
        Theme.windowWidth = root.width
        Theme.contentSideMargin = Theme.sideMargin(root.width)
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

    // 最大化 / 还原。showMaximized() 对无边框窗口同样走系统路径
    // （贴合工作区、避让任务栏），并让原生命中测试生效，
    // 因此最大化后按住标题栏拖动会自动回落成普通窗口。
    function toggleMaximize() {
        if (root.windowMaximized || root.visibility === Window.Maximized) root.showNormal()
        else root.showMaximized()
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
        if (deltaMs > 0) root.showToast("快进 " + (deltaMs / 1000) + "s")
        else root.showToast("快退 " + (-deltaMs / 1000) + "s")
    }

    function handleEsc() {
        if (playerBar.pickerVisible) { playerBar.closePicker(); return }
        if (playlistPanel.pickerVisible) { playlistPanel.closePicker(); return }
        if (root.viewMode === "player") { root.viewMode = root.preFullscreenView; return }
        if (root.playlistOpen) { root.playlistOpen = false; return }

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
        if (isLocalPath(root.currentSongCid)) {
            root.showToast("本地歌曲无需下载")
            return
        }
        audioCache.downloadToLibrary(root.currentSongCid, root.currentTitle,
            root.currentArtist, "", root.currentCover,
            root.urlCache[root.currentSongCid] || "")
    }

    function triggerAddToPlaylist() {
        if (root.currentSongCid === "") return
        playerBar.openPickerDialog()
    }

    // ============================================================
    // 快捷键
    // ============================================================
    Shortcut { sequence: "Space"; onActivated: {
        if (root.textInputFocused || root.anyPickerOpen) return
        if (audioEngine.isPlaying()) audioEngine.pause(); else audioEngine.resume()
    }}
    Shortcut { sequence: "F"; onActivated: {
        if (root.textInputFocused || root.anyPickerOpen) return; root.toggleFullscreen()
    }}
    Shortcut { sequence: "A"; onActivated: {
        if (root.textInputFocused || root.anyPickerOpen) return; root.playPrev()
    }}
    Shortcut { sequence: "D"; onActivated: {
        if (root.textInputFocused || root.anyPickerOpen) return; root.playNext()
    }}
    Shortcut { sequence: "Left"; onActivated: {
        if (root.textInputFocused || root.anyPickerOpen) return; root.seekRelative(-5000)
    }}
    Shortcut { sequence: "Right"; onActivated: {
        if (root.textInputFocused || root.anyPickerOpen) return; root.seekRelative(5000)
    }}
    Shortcut { sequence: "G"; onActivated: {
        if (root.textInputFocused || root.anyPickerOpen) return
        root.playlistOpen = !root.playlistOpen
    }}
    Shortcut { sequence: "Up"; onActivated: {
        if (root.textInputFocused || root.anyPickerOpen) return; root.adjustVolume(0.05)
    }}
    Shortcut { sequence: "Down"; onActivated: {
        if (root.textInputFocused || root.anyPickerOpen) return; root.adjustVolume(-0.05)
    }}
    Shortcut { sequence: "Q"; onActivated: {
        if (root.textInputFocused || root.anyPickerOpen) return; root.triggerAddToPlaylist()
    }}
    Shortcut { sequence: "E"; onActivated: {
        if (root.textInputFocused || root.anyPickerOpen) return; root.triggerDownload()
    }}
    Shortcut { sequence: "Escape"; onActivated: {
        if (root.anyPickerOpen) { root.handleEsc(); return }
        if (root.textInputFocused) return
        root.handleEsc()
    }}
    Shortcut { sequence: "L"; onActivated: {
        if (root.textInputFocused || root.anyPickerOpen) return
        if (root.viewMode !== "player") return
        fullPlayer.showLyrics = !fullPlayer.showLyrics
    }}
    Shortcut { sequence: "T"; onActivated: {
        if (root.textInputFocused || root.anyPickerOpen) return
        if (root.viewMode !== "player") return
        fullPlayer.showTranslation = !fullPlayer.showTranslation
    }}
    Shortcut { sequence: "Ctrl+L"; onActivated: {
        appSettings.desktopLyricEnabled = !appSettings.desktopLyricEnabled
        root.showToast(appSettings.desktopLyricEnabled ? "桌面歌词已开启" : "桌面歌词已关闭")
    }}

    // 跟随系统时，系统主题变化也要反映到界面上
    Binding {
        target: Theme
        property: "darkMode"
        value: appSettings.darkMode
    }

    // 主题色：设置里存的是 #RRGGBB，空串回落内置橄榄绿
    Binding {
        target: Theme
        property: "accentBase"
        value: appSettings.accentColor !== "" ? appSettings.accentColor
                                              : Theme.accentDefault
    }


    // 记住窗口位置与大小（窗口上已有 onWidthChanged/onHeightChanged，
    // 不能再声明一次，所以用轮询并先比对，只在真正变化时写配置）
    function saveGeometry() {
        if (!appSettings.rememberGeometry) return
        if (root.visibility === Window.Minimized) return
        // 最大化/全屏时别把屏幕尺寸当成用户偏好的窗口大小存下来，
        // 否则下次启动会以最大化尺寸作为「默认窗口大小」。
        if (root.windowMaximized || root.visibility === Window.FullScreen) return
        if (appSettings.winX === root.x && appSettings.winY === root.y
                && appSettings.winW === root.width && appSettings.winH === root.height)
            return
        appSettings.winX = root.x
        appSettings.winY = root.y
        appSettings.winW = root.width
        appSettings.winH = root.height
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: root.saveGeometry()
    }

    // 切歌淡入：把音量从 0 渐入到当前目标音量。
    // 目标取「切入前的音量」而不是设置里的默认音量，
    // 否则用户手动调过音量后，切歌会把音量拉回默认值。
    NumberAnimation {
        id: volumeFadeIn
        target: audioEngine
        property: "volume"
        from: 0.0
        duration: 320
        easing.type: Easing.OutCubic
    }
    function startFadeIn() {
        if (!appSettings.crossfade) return
        const target = audioEngine.volume
        if (target <= 0.001) return
        volumeFadeIn.stop()
        volumeFadeIn.to = target
        audioEngine.volume = 0.0
        volumeFadeIn.start()
    }

    Component.onCompleted: {
        if (appSettings.rememberGeometry && appSettings.winW > 0) {
            root.width = appSettings.winW
            root.height = appSettings.winH
            root.x = appSettings.winX
            root.y = appSettings.winY
        }
        audioEngine.setVolume(appSettings.volumeDefault)
        audioEngine.loopMode = appSettings.loopMode
        if (appSettings.checkUpdate) appSettings.checkForUpdates()
        updateUiScale()
        updateTextInputFocus()
        systemTray.setCurrentSong(root.currentTitle, root.currentArtist)
        systemTray.setPlayingState(audioEngine.isPlaying())
        if (appSettings.desktopLyricEnabled) desktopLyric.show()
    }

    onWidthChanged: updateUiScale()
    onHeightChanged: updateUiScale()

    onFullscreenModeChanged: {
        if (!fullscreenMode) {
            dockAutoHide = false
            playerBarAutoHide = false
        } else {
            // 全屏播放器保留底部播放条，播放控制始终可达
            dockAutoHide = true
            playerBarAutoHide = false
        }
    }

    Connections {
        target: appSettings
        function onFontScaleChanged() { root.updateUiScale() }
        function onDesktopLyricEnabledChanged() {
            if (appSettings.desktopLyricEnabled) desktopLyric.show()
            else desktopLyric.hide()
        }
    }

    Connections {
        target: systemTray
        function onRequestTogglePlay() {
            if (audioEngine.isPlaying()) audioEngine.pause(); else audioEngine.resume()
        }
        function onRequestPlayPrev() { root.playPrev() }
        function onRequestPlayNext() { root.playNext() }
    }

    Timer { id: bootFinishTimer; interval: 800; onTriggered: root.bootLoading = false }
    Timer { id: bootTimeoutTimer; interval: 8000; running: root.bootLoading
            onTriggered: root.bootLoading = false }

    // [dev] --snapshot 时把窗口抓成图片，方便核对视觉（正式版可删）
    function devArg(name, fallback) {
        var a = Qt.application.arguments
        for (var i = 0; i < a.length; i++)
            if (a[i].indexOf(name + "=") === 0) return a[i].substring(name.length + 1)
        return fallback
    }
    Timer {
        id: devShotTimer
        interval: 2000
        repeat: false
        running: Qt.application.arguments.indexOf("--snapshot") !== -1 && !root.bootLoading
        onTriggered: {
            var page = root.devArg("--page", "")
            if (page === "siren-detail") {
                root.viewMode = "siren"
                sirenPage.devOpenFirstAlbum()
            } else if (page === "playlist-demo") {
                root.viewMode = "playlist"
                var pid = playlistManager.createPlaylist("测试歌单")
                var seed = [
                    { cid: "s1", name: "Baptised with Fire", artist: "塞壬唱片-MSR" },
                    { cid: "s2", name: "Mirari", artist: "塞壬唱片-MSR" },
                    { cid: "s3", name: "The Iberia Touch", artist: "塞壬唱片-MSR" },
                    { cid: "s4", name: "Nameless Song", artist: "塞壬唱片-MSR" }
                ]
                for (var si = 0; si < seed.length; si++)
                    playlistManager.addSong(pid, seed[si].cid, seed[si].name,
                                            seed[si].artist, "")
                playlistPage.enterPlaylist(pid, "测试歌单", "")
            } else if (page === "playlist-cleanup") {
                // [dev] 清掉截图用的临时歌单
                var all = playlistManager.playlists
                for (var pi = all.length - 1; pi >= 0; pi--)
                    if (all[pi].name === "测试歌单")
                        playlistManager.deletePlaylist(all[pi].id)
                devGrabTimer.restart()
            } else if (page === "search-demo") {
                root.viewMode = "search"
                searchPage.devSearch("大地")
            } else if (page === "player-demo") {
                root.currentTitle = "Iron Lotus"
                root.currentArtist = "塞壬唱片-MSR / Steven Grove"
                root.currentCover = ""
                root.lyricLines = [
                    { time: 0,  text: "风穿过钢铁的缝隙", translated: "Wind slips through the steel" },
                    { time: 1,  text: "灯在雨里亮了一整夜", translated: "Lamps burned all night in the rain" },
                    { time: 2,  text: "我们把名字写在墙上", translated: "We wrote our names upon the wall" },
                    { time: 3,  text: "I am not afraid", translated: "我不害怕" },
                    { time: 4,  text: "在这一刻，我的心平静如水", translated: "" },
                    { time: 5,  text: "没有谁能迫我退悔", translated: "" },
                    { time: 6,  text: "四面楚歌，这颗心无惧无畏", translated: "" },
                    { time: 7,  text: "铁花飞，飘逸不残灰", translated: "" },
                    { time: 8,  text: "千年之后还剩下什么？", translated: "" }
                ]
                root.currentLyricIndex = 4
                root.viewMode = "player"
            } else if (page !== "") {
                root.viewMode = page
            }
            if (root.devArg("--big", "") !== "") {
                root.width = 1480
                root.height = 920
            }
            var cat = root.devArg("--category", "")
            if (cat !== "") settingsPage.openCategory(cat)
            devGrabTimer.restart()
        }
    }
    Timer {
        id: devGrabTimer
        interval: 1600
        repeat: false
        onTriggered: {
            var out = root.devArg("--out", "C:/tmp/mass-shot.png")
            windowCard.grabToImage(function(result) {
                result.saveToFile(out)
                console.log("[snapshot] saved to", out)
            })
        }
    }

    function pauseForExit() { if (audioEngine.isPlaying()) audioEngine.pause() }

    Timer { id: minimizeAnimTimer; interval: 200; onTriggered: {
        root.showMinimized(); root.windowScale = 1.0; root.windowOpacity = 1.0 } }
    Timer { id: hideToTrayAnimTimer; interval: 200; onTriggered: {
        systemTray.hideToTray(); root.windowScale = 1.0; root.windowOpacity = 1.0 } }
    Timer { id: quitAnimTimer; interval: 200; onTriggered: {
        desktopLyric.close(); systemTray.quitApp() } }
    Timer { id: restartAnimTimer; interval: 200; onTriggered: {
        desktopLyric.close(); appSettings.restartApp() } }


    function animateMinimize() {
        // 无边框窗口下 showMinimized() 不会触发系统动画，仍用自定义缩放淡出
        if (windowScale !== 1.0 || windowOpacity !== 1.0) return
        windowScale = 0.9; windowOpacity = 0; minimizeAnimTimer.start()
    }
    function animateHideToTray() {
        if (windowScale !== 1.0 || windowOpacity !== 1.0) return
        windowScale = 0.9; windowOpacity = 0; hideToTrayAnimTimer.start()
    }
    function animateQuit() {
        if (windowScale !== 1.0 || windowOpacity !== 1.0) return
        pauseForExit(); windowScale = 0.9; windowOpacity = 0; quitAnimTimer.start()
    }
    function animateRestart() {
        if (windowScale !== 1.0 || windowOpacity !== 1.0) return
        pauseForExit(); windowScale = 0.9; windowOpacity = 0; restartAnimTimer.start()
    }
    function animateClose() {
        if (windowScale !== 1.0 || windowOpacity !== 1.0) return
        if (appSettings.closeBehavior === "quit") {
            pauseForExit(); windowScale = 0.9; windowOpacity = 0; quitAnimTimer.start()
        } else {
            windowScale = 0.9; windowOpacity = 0; hideToTrayAnimTimer.start()
        }
    }

    onClosing: (close) => { close.accepted = false; animateClose() }

    Rectangle {
        id: windowCard
        anchors.fill: parent
        // 圆角由 DWM 处理
        radius: 0
        clip: true

        scale: root.windowScale
        opacity: root.windowOpacity
        transformOrigin: Item.Center
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        color: Theme.bg
        Behavior on color { ColorAnimation { duration: Theme.themeAnim } }

        // 纸面网格：终端感的底层纹理，只在浅色里明显一点
        Canvas {
            id: paperGrid
            anchors.fill: parent
            opacity: Theme.darkMode ? 0.5 : 0.7
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = Theme.darkMode ? "#14FFFFFF" : "#12000000"
                ctx.lineWidth = 1
                var step = 56
                for (var x = 0; x < width; x += step) {
                    ctx.beginPath(); ctx.moveTo(x + 0.5, 0); ctx.lineTo(x + 0.5, height); ctx.stroke()
                }
                for (var y = 0; y < height; y += step) {
                    ctx.beginPath(); ctx.moveTo(0, y + 0.5); ctx.lineTo(width, y + 0.5); ctx.stroke()
                }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: Theme
                function onDarkModeChanged() { paperGrid.requestPaint() }
            }
        }

        // 自定义背景
        Image {
            anchors.fill: parent
            source: appSettings.backgroundImage
            visible: appSettings.backgroundImage !== ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
        }

        // 压暗保证可读
        Rectangle {
            anchors.fill: parent
            visible: appSettings.backgroundImage !== ""
            color: appSettings.darkMode ? "#D91A1B17" : "#D9ECEAE5"
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
            id: mainContent
            anchors.fill: parent
            spacing: 0

            Item {
                id: titleBarWrapper
                Layout.fillWidth: true
                Layout.preferredHeight: titleBarWrapper.barHeight
                clip: true
                property real barHeight: root.fullscreenMode ? 0 : Theme.headerHeight
                Behavior on barHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                TitleBar {
                    id: titleBar
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: Theme.headerHeight
                    pageTitle: root.pageTitle
                    currentPage: root.navPage
                    maximized: root.windowMaximized
                    onPageChanged: (p) => {
                        if (root.viewMode === "player") root.viewMode = p
                        else root.viewMode = p
                    }
                    onMaximizeRequested: root.toggleMaximize()
                    onMinimizeRequested: root.animateMinimize()
                    onCloseRequested: root.animateClose()
                }
            }

            Item {
                id: contentArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // 播放条不占布局，靠底部内缩给它留位置
                anchors.bottomMargin: root.playerBarAutoHide ? 0 : Theme.playerBarHeight
                Behavior on anchors.bottomMargin {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }

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

                // ★ 本地页
                LocalPage {
                    id: localPage
                    anchors.fill: parent
                    visible: root.viewMode === "local"
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

        PlayerBar {
            id: playerBar
            x: 0
            width: parent.width
            y: root.playerBarAutoHide ? parent.height : parent.height - height
            enabled: !root.playerBarAutoHide && !root.bootLoading
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            coverUrl: root.currentCover
            title: root.currentTitle
            artist: root.currentArtist
            songCid: root.currentSongCid
            songUrl: root.urlCache[root.currentSongCid] || ""

            hasPrev: {
                if (root.playQueue.length === 0) return false
                if (root.queueIndex > 0) return true
                return (root.listLoop || root.shuffleMode) && root.playQueue.length > 1
            }
            hasNext: {
                if (root.playQueue.length === 0) return false
                if (root.queueIndex < 0) return false
                if (root.queueIndex + 1 < root.playQueue.length) return true
                return (root.listLoop || root.shuffleMode) && root.playQueue.length > 1
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
            anchors.bottomMargin: root.playerBarAutoHide ? 24 : (Theme.playerBarHeight + 16)
            width: toastText.implicitWidth + 36
            height: 34
            color: Theme.bg
            border.width: 1
            border.color: Theme.border
            opacity: 0
            visible: opacity > 0
            z: 2000
            Behavior on anchors.bottomMargin { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            Text {
                id: toastText
                anchors.centerIn: parent
                color: Theme.text
                font {
                    family: Theme.monoFamily
                    pixelSize: Theme.fs(10.5)
                    letterSpacing: 1
                }
            }
            Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
            Timer { id: toastTimer; interval: 2500; onTriggered: toast.opacity = 0 }
        }

        Rectangle {
            id: bootOverlay
            anchors.fill: parent
            color: Theme.bg
            opacity: root.bootLoading ? 1 : 0
            visible: opacity > 0.01
            z: 99999
            enabled: root.bootLoading
            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

            Column {
                anchors.centerIn: parent
                spacing: 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "MASS"
                    color: Theme.text
                    font {
                        family: Theme.displayFamily
                        pixelSize: Theme.fs(34)
                        bold: true
                        letterSpacing: 8
                    }
                }

                Item { width: 1; height: 10 }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "MONSTER SIREN / MUSIC DATABASE"
                    color: Theme.textMuted
                    font {
                        family: Theme.monoFamily
                        pixelSize: Theme.microSize
                        letterSpacing: 3
                    }
                }

                Item { width: 1; height: 30 }

                // 细进度线：一条从 0 铺到满的橄榄色线
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 180; height: 2

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.border
                    }

                    Rectangle {
                        id: bootBar
                        width: 0
                        height: parent.height
                        color: Theme.accent
                        SequentialAnimation {
                            running: root.bootLoading
                            loops: Animation.Infinite
                            NumberAnimation { target: bootBar; property: "width"
                                              from: 0; to: 180; duration: 1600
                                              easing.type: Easing.InOutQuad }
                            PauseAnimation { duration: 260 }
                            NumberAnimation { target: bootBar; property: "width"
                                              to: 0; duration: 0 }
                        }
                    }
                }

                Item { width: 1; height: 16 }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.bootAlbumsReceived ? "LOADING INTERFACE …" : "READING RECORDS …"
                    color: Theme.textDim
                    font {
                        family: Theme.monoFamily
                        pixelSize: Theme.microSize
                        letterSpacing: 2
                    }
                }
            }
        }
    }

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

        function onLyricReady(lyric, translated) {
            root.lyricLines = root.parseLrc(lyric, translated)
            root.currentLyricIndex = -1
            if (!lyric || lyric === "") return
            let hasCache = translationService.hasCached(root.currentSongCid)
            if (!hasCache && translated && translated !== "") return
            let lines = []
            let re = /\[(\d+):(\d+)(?:[.:](\d+))?\](.*)/
            let rawLines = lyric.split("\n")
            for (let i = 0; i < rawLines.length; i++) {
                let m = re.exec(rawLines[i])
                if (m && m[4].trim() !== "") lines.push(m[4].trim())
            }
            if (lines.length === 0) return
            root.pendingMachineLines = lines
            root.pendingLyricCid = root.currentSongCid
            if (!appSettings.apiTranslate) return
            // 先试网易云（自带官方中文翻译），取不到再退回机器翻译
            if (root.currentTitle !== "") {
                networkManager.fetchNeteaseLyric(root.currentSongCid,
                                                 root.currentTitle,
                                                 root.currentArtist)
            } else {
                root.runMachineTranslation()
            }
        }

        function onNeteaseLyricReady(cid, lrc, tlyric) {
            if (cid !== root.currentSongCid) return
            if (!tlyric || tlyric === "") { root.runMachineTranslation(); return }
            root.pendingMachineLines = []
            let transDict = root.parseLrcToDict(tlyric)
            let newLines = []
            for (let i = 0; i < root.lyricLines.length; i++) {
                let line = root.lyricLines[i]
                newLines.push({
                    time: line.time, text: line.text,
                    translated: root.lookupTranslation(transDict, line.time)
                })
            }
            root.lyricLines = newLines
        }

        function onNeteaseLyricFailed(cid, error) {
            if (cid !== root.currentSongCid) return
            root.runMachineTranslation()
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
        function onLoopModeChanged(mode) {
            appSettings.loopMode = mode
            const names = ["顺序播放", "单曲循环", "列表循环", "随机播放"]
            root.showToast(names[mode] || "")
        }
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
        target: translationService
        function onLyricsTranslated(cid, translated) {
            if (cid !== root.currentSongCid) return
            let cachedSource = translationService.getCachedSource(cid)
            let newLines = []
            if (cachedSource && cachedSource.length === translated.length
                    && cachedSource.length > 0) {
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
                    newLines.push({ time: line.time, text: line.text, translated: tr })
                }
            } else {
                for (let i = 0; i < root.lyricLines.length; i++) {
                    let line = root.lyricLines[i]
                    newLines.push({
                        time: line.time, text: line.text,
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
        if (isLocalPath(cid)) return
        if (root.downloadingSet[cid]) return
        if (audioCache.hasCache(cid)) return
        let d = Object.assign({}, root.downloadingSet)
        d[cid] = true
        root.downloadingSet = d
        audioCache.download(cid, url)
    }
    function prefetchNeighbors() {
        if (!appSettings.prefetchNext) return
        if (root.playQueue.length === 0) return
        let n = root.playQueue.length
        let idx = root.queueIndex
        let nextIdx = idx + 1
        if (nextIdx >= n && root.listLoop && n > 1) nextIdx = 0
        if (nextIdx < 0 || nextIdx >= n) return
        let s = root.playQueue[nextIdx]
        if (!s || !s.cid) return
        if (isLocalPath(s.cid)) return
        if (root.urlCache[s.cid]) {
            audioMetadataProbe.probe(s.cid, root.urlCache[s.cid])
            return
        }
        networkManager.prefetchSongInfo(s.cid)
    }
    function checkMousePosition(x, y) {
        if (!root.fullscreenMode) {
            if (root.playerBarAutoHide) root.playerBarAutoHide = false
            return
        }
        // 全屏播放器里，只有鼠标压到窗口底边才浮出播放条
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
    function shuffleIndex() {
        let n = root.playQueue.length
        if (n <= 1) return 0
        let i = root.queueIndex
        while (i === root.queueIndex) i = Math.floor(Math.random() * n)
        return i
    }
    function playNext() {
        if (root.playQueue.length === 0) { root.showToast("播放列表为空"); return }
        if (root.shuffleMode && root.playQueue.length > 1) root.queueIndex = root.shuffleIndex()
        else if (root.queueIndex + 1 < root.playQueue.length) root.queueIndex++
        else if (root.listLoop && root.playQueue.length > 1) root.queueIndex = 0
        else { root.showToast("已经是最后一首了"); return }
        let s = root.playQueue[root.queueIndex]
        root.playSong(s.cid, s.name, s.artist, s.cover)
    }
    function playPrev() {
        if (root.playQueue.length === 0) { root.showToast("播放列表为空"); return }
        if (root.shuffleMode && root.playQueue.length > 1) root.queueIndex = root.shuffleIndex()
        else if (root.queueIndex > 0) root.queueIndex--
        else if (root.listLoop && root.playQueue.length > 1) root.queueIndex = root.playQueue.length - 1
        else { root.showToast("已经是第一首了"); return }
        let s = root.playQueue[root.queueIndex]
        root.playSong(s.cid, s.name, s.artist, s.cover)
    }
    function onTrackFinished() {
        if (root.playQueue.length === 0) return
        if (root.shuffleMode && root.playQueue.length > 1) {
            root.queueIndex = root.shuffleIndex()
            let s0 = root.playQueue[root.queueIndex]
            root.playSong(s0.cid, s0.name, s0.artist, s0.cover)
        } else if (root.queueIndex + 1 < root.playQueue.length) {
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

    // ★ playSong 支持本地文件
    function playSong(cid, name, artist, cover) {
        root.startFadeIn()
        root.currentSongCid = cid
        root.currentTitle = name
        root.currentArtist = artist
        root.currentCover = cover
        root.currentLyricIndex = -1
        root.lyricLines = []
        root.justPlayedByUrlHit = ""

        systemTray.setCurrentSong(name, artist)
        historyManager.addSong(cid, name, artist, cover)

        // ★ 本地文件路径处理
        if (isLocalPath(cid)) {
            root.playingLocalFile = true
            let fileUrl = cid.startsWith("file://") ? cid : ("file:///" + cid)
            audioEngine.play(fileUrl)
            playerBar.playing = true

            // 尝试加载同名 .lrc 歌词
            let lrcPath = appSettings.findSidecarFile(cid, ["lrc", "LRC"])
            if (lrcPath !== "") {
                let lrcText = appSettings.readTextFile(lrcPath)
                if (lrcText !== "") {
                    root.lyricLines = root.parseLrc(lrcText, "")
                }
            }
            return
        }

        // 原有网络路径
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

    // 网易云拿不到译文时的退路
    function runMachineTranslation() {
        let lines = root.pendingMachineLines
        root.pendingMachineLines = []
        if (!lines || lines.length === 0) return
        if (!appSettings.apiTranslate) return
        translationService.translateLyrics(root.pendingLyricCid, lines, "zh-CN")
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
            out.push({ time: k, text: dict[k], translated: lookupTranslation(transDict, k) })
        }
        return out
    }
}