import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// ============================================================
// 底部播放条
//
//  ──────────────────────────────────────────────────  ← 2px 进度线
//  [cover] 曲名                        循环  ‹  (▶)  ›  歌词        音量 ▮▮▮▮▮   队列
//          歌手 / MASS                00:00 / 00:00
//
// 没有胶囊、没有玻璃：整条贴在窗口底边，上面一条细线，
// 进度用最顶端的 2px 线表示，播放键是整条里唯一的实心色块。
// ============================================================
Item {
    id: root
    implicitHeight: Theme.playerBarHeight

    signal fullscreenClicked()
    signal prevClicked()
    signal nextClicked()
    signal playlistClicked()

    property int currentSongId: -1
    property string songCid: ""
    property string songUrl: ""
    property string songAlbum: ""
    property bool playing: false
    property bool hasPrev: false
    property bool hasNext: false
    property string coverUrl: ""
    property string title: ""
    property string artist: ""
    property bool buffering: false

    property real downloadProgress: -1
    property Item backgroundSource: null

    readonly property bool pickerVisible: pickerDialog.visible

    function openPickerDialog() {
        if (root.songCid === "") return
        pickerDialog.openFor(root.songCid, root.title, root.artist, root.coverUrl)
    }
    function closePicker() { pickerDialog.close() }

    Connections {
        target: audioEngine
        function onBufferingChanged(b) { root.buffering = b }
    }

    Connections {
        target: audioCache
        function onDownloadProgress(cid, received, total) {
            if (cid !== root.songCid) return
            if (total > 0) root.downloadProgress = received / total
        }
        function onDownloadFinished(cid, localPath) {
            if (cid !== root.songCid) return
            root.downloadProgress = -1
        }
        function onDownloadFailed(cid) {
            if (cid !== root.songCid) return
            root.downloadProgress = -1
        }
        function onLibraryDownloadFinished(cid, savedPath) {
            if (cid !== root.songCid) return
            root.downloadProgress = -1
        }
        function onLibraryDownloadFailed(cid, error) {
            if (cid !== root.songCid) return
            root.downloadProgress = -1
        }
    }

    onSongCidChanged: root.downloadProgress = -1

    // 拦截空白区域点击，避免穿透到下面的列表
    MouseArea {
        anchors.fill: parent
        z: -100
        onClicked: (mouse) => { mouse.accepted = true }
    }

    // ── 背景 + 顶部细线 ────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 1
        color: Theme.border
        opacity: 0.55
    }

    // ── 进度线（贴在最顶部，拖动可跳转）────────────────────────
    Item {
        id: progressArea
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 10
        z: 5

        property bool dragging: false
        property real dragValue: 0
        property bool hovering: progressMouse.containsMouse

        readonly property real displayProgress: {
            if (dragging) return dragValue
            if (audioEngine.duration > 0) return audioEngine.position / audioEngine.duration
            return 0
        }

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: (progressArea.hovering || progressArea.dragging) ? 3 : 2
            color: Theme.border
            opacity: 0.5
            antialiasing: true
            Behavior on height { NumberAnimation { duration: 110 } }

            Rectangle {
                width: parent.width * progressArea.displayProgress
                height: parent.height
                color: Theme.accentHover
                antialiasing: true
                Behavior on width {
                    enabled: !progressArea.dragging
                    NumberAnimation { duration: 80 }
                }
            }
        }

        MouseArea {
            id: progressMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function updateDragValue(mx) {
                var v = mx / width
                if (v < 0) v = 0
                if (v > 1) v = 1
                progressArea.dragValue = v
                if (appSettings.seekPreview)
                    audioEngine.seek(progressArea.dragValue * audioEngine.duration)
            }

            onPressed: (mouse) => {
                if (audioEngine.duration <= 0) return
                progressArea.dragging = true
                updateDragValue(mouse.x)
            }
            onPositionChanged: (mouse) => {
                if (progressArea.dragging) updateDragValue(mouse.x)
            }
            onReleased: (mouse) => {
                if (!progressArea.dragging) return
                progressArea.dragging = false
                if (audioEngine.duration > 0)
                    audioEngine.seek(progressArea.dragValue * audioEngine.duration)
            }
            onCanceled: progressArea.dragging = false
        }
    }

    // ── 左：封面 + 曲目信息 ────────────────────────────────────
    Item {
        id: leftBlock
        anchors {
            left: parent.left
            leftMargin: Math.max(16, Theme.contentSideMargin - 20)
            verticalCenter: parent.verticalCenter
            verticalCenterOffset: 2
        }
        width: Math.min(260, parent.width * 0.24)
        height: 52

        Rectangle {
            id: coverBox
            width: 46; height: 46
            color: Theme.panelAlt
            border.width: 1
            border.color: Theme.border

            Image {
                id: coverImage
                anchors.fill: parent
                anchors.margins: 1
                source: root.coverUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: 128
                sourceSize.height: 128
                smooth: true
                mipmap: true
            }

            Text {
                anchors.centerIn: parent
                visible: coverImage.status !== Image.Ready
                text: "♪"
                color: Theme.textMuted
                font.pixelSize: Theme.fs(14)
            }

            Rectangle {
                anchors.fill: parent
                visible: coverHover.hovered
                color: "#000000"
                opacity: 0.34
                Text {
                    anchors.centerIn: parent
                    text: "⛶"
                    color: "#FFFFFF"
                    font.pixelSize: Theme.fs(15)
                }
            }

            HoverHandler { id: coverHover }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.fullscreenClicked()
            }
        }

        Column {
            anchors {
                left: coverBox.right
                leftMargin: 14
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: 4

            Text {
                width: parent.width
                text: root.title || "尚未播放"
                color: Theme.text
                font {
                    family: Theme.fontFamily
                    pixelSize: Theme.fs(13)
                    weight: Font.DemiBold
                }
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: (root.artist || "MASS") + "  /  塞壬唱片"
                color: Theme.textMuted
                font {
                    family: Theme.fontFamily
                    pixelSize: Theme.microSize
                    letterSpacing: 0.6
                }
                elide: Text.ElideRight
            }
        }
    }

    // ── 中：走带控制 ───────────────────────────────────────────
    Item {
        id: centerBlock
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 2
        width: 340
        height: parent.height

        Row {
            id: transport
            anchors.horizontalCenter: parent.horizontalCenter
            y: 16
            spacing: 18

            // 循环模式
            Item {
                width: loopText.implicitWidth
                height: 46

                readonly property var names: ["顺序", "单曲", "列表", "随机"]

                Text {
                    id: loopText
                    anchors.centerIn: parent
                    text: parent.names[audioEngine.loopMode] || "顺序"
                    color: loopMouse.containsMouse ? Theme.text : Theme.textMuted
                    font {
                        family: Theme.monoFamily
                        pixelSize: Theme.labelSize
                        letterSpacing: 1.2
                    }
                }

                MouseArea {
                    id: loopMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: audioEngine.cycleLoopMode()
                }
            }

            // 上一首
            Item {
                width: 26; height: 46
                opacity: root.hasPrev ? 1 : 0.3

                Text {
                    anchors.centerIn: parent
                    text: "‹"
                    color: prevMouse.containsMouse && root.hasPrev ? Theme.text : Theme.textDim
                    font {
                        family: Theme.monoFamily
                        pixelSize: Theme.fs(22)
                    }
                }

                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.hasPrev
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.prevClicked()
                }
            }

            // 播放 / 暂停
            Rectangle {
                width: 46; height: 46
                radius: 0
                color: root.buffering
                       ? Theme.panelAlt
                       : (playMouse.containsMouse ? Theme.accentHover : Theme.accent)
                antialiasing: true
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text: root.playing ? "❚❚" : "▶"
                    color: root.buffering ? Theme.textMuted : Theme.ink
                    font {
                        family: Theme.monoFamily
                        pixelSize: Theme.fs(13)
                        bold: true
                    }
                    // ▶ 的视觉重心偏左，往右挪一点点
                    x: (parent.width - width) / 2 + (root.playing ? 0 : 1.5)
                    y: (parent.height - height) / 2
                }

                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (audioEngine.isPlaying()) audioEngine.pause()
                        else audioEngine.resume()
                    }
                }
            }

            // 下一首
            Item {
                width: 26; height: 46
                opacity: root.hasNext ? 1 : 0.3

                Text {
                    anchors.centerIn: parent
                    text: "›"
                    color: nextMouse.containsMouse && root.hasNext ? Theme.text : Theme.textDim
                    font {
                        family: Theme.monoFamily
                        pixelSize: Theme.fs(22)
                    }
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.hasNext
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.nextClicked()
                }
            }

            // 歌词
            Item {
                width: lyricText.implicitWidth
                height: 46

                Text {
                    id: lyricText
                    anchors.centerIn: parent
                    text: "歌词"
                    color: lyricMouse.containsMouse ? Theme.text : Theme.textMuted
                    font {
                        family: Theme.monoFamily
                        pixelSize: Theme.labelSize
                        letterSpacing: 1.6
                    }
                }

                MouseArea {
                    id: lyricMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.fullscreenClicked()
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: transport.bottom
            anchors.topMargin: 4
            text: Theme.formatTime(progressArea.dragging
                                   ? progressArea.dragValue * audioEngine.duration
                                   : audioEngine.position)
                  + " / " + Theme.formatTime(audioEngine.duration)
            color: progressArea.dragging ? Theme.accentHover : Theme.textMuted
            font {
                family: Theme.monoFamily
                pixelSize: Theme.microSize
                letterSpacing: 0.8
            }
        }
    }

    // ── 右：音质操作 + 音量 + 队列 ─────────────────────────────
    Row {
        id: rightBlock
        anchors {
            right: parent.right
            rightMargin: Math.max(16, Theme.contentSideMargin - 20)
            verticalCenter: parent.verticalCenter
            verticalCenterOffset: 2
        }
        spacing: 10

        // 加入歌单
        Item {
            width: 24; height: 24
            opacity: root.songCid !== "" ? 1 : 0.3

            Text {
                anchors.centerIn: parent
                text: "＋"
                color: addMouse.containsMouse && root.songCid !== "" ? Theme.accentHover : Theme.textDim
                font { family: Theme.monoFamily; pixelSize: Theme.fs(14) }
            }

            MouseArea {
                id: addMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.songCid !== ""
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openPickerDialog()
            }
        }

        // 下载
        Item {
            width: 24; height: 24
            opacity: root.songCid !== "" ? 1 : 0.3

            Text {
                anchors.centerIn: parent
                text: root.downloadProgress >= 0
                      ? Math.round(root.downloadProgress * 100) + "%"
                      : "↓"
                color: root.downloadProgress >= 0 ? Theme.accentHover
                       : (dlMouse.containsMouse && root.songCid !== "" ? Theme.accentHover : Theme.textDim)
                font {
                    family: Theme.monoFamily
                    pixelSize: root.downloadProgress >= 0 ? Theme.fs(7) : Theme.fs(14)
                }
            }

            MouseArea {
                id: dlMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.songCid !== "" && root.downloadProgress < 0
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.songCid === "") return
                    audioCache.downloadToLibrary(root.songCid, root.title,
                        root.artist, root.songAlbum, root.coverUrl, root.songUrl)
                }
            }
        }

        Item { width: 6; height: 24 }

        // 音量：等宽标签 + 段落条
        Item {
            width: volLabel.implicitWidth
            height: 24

            Text {
                id: volLabel
                anchors.centerIn: parent
                text: "音量"
                color: Theme.textMuted
                font {
                    family: Theme.monoFamily
                    pixelSize: Theme.microSize
                    letterSpacing: 1.4
                }
            }
        }

        Item {
            id: volumeBar
            width: 74
            height: 24

            readonly property int segments: 10
            readonly property real segW: (width - (segments - 1) * 3) / segments
            property real shownVolume: audioEngine.volume

            Repeater {
                model: volumeBar.segments

                delegate: Rectangle {
                    x: index * (volumeBar.segW + 3)
                    anchors.verticalCenter: parent.verticalCenter
                    width: volumeBar.segW
                    height: 10
                    color: (index + 0.5) / volumeBar.segments <= volumeBar.shownVolume
                           ? (volumeMouse.containsMouse ? Theme.accentHover : Theme.textDim)
                           : Theme.border
                    antialiasing: false
                    Behavior on color { ColorAnimation { duration: 90 } }
                }
            }

            MouseArea {
                id: volumeMouse
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                function setFrom(x) {
                    var v = Math.max(0, Math.min(1, x / volumeBar.width))
                    audioEngine.setVolume(v)
                }
                onPressed: (m) => setFrom(m.x)
                onPositionChanged: (m) => { if (pressed) setFrom(m.x) }
            }
        }

        Item { width: 6; height: 24 }

        // 队列
        Item {
            width: queueText.implicitWidth
            height: 24

            Text {
                id: queueText
                anchors.centerIn: parent
                text: "队列"
                color: queueMouse.containsMouse ? Theme.text : Theme.textDim
                font {
                    family: Theme.monoFamily
                    pixelSize: Theme.labelSize
                    letterSpacing: 1.6
                }
            }

            MouseArea {
                id: queueMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.playlistClicked()
            }
        }
    }

    PlaylistPickerDialog {
        id: pickerDialog
    }
}
