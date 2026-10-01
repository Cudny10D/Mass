import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root
    implicitHeight: Theme.playerBarHeight + Theme.playerBarBottomMargin * 2

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

    Rectangle {
        id: glowSource
        anchors.fill: pill
        anchors.margins: -36
        radius: pill.radius + 24
        color: Theme.darkMode ? "#60ffffff" : "#40000000"
        visible: false
        layer.enabled: true
        enabled: false
    }

    MultiEffect {
        source: glowSource
        anchors.fill: glowSource
        blurEnabled: true
        blur: 1.5
        blurMax: 96
        opacity: root.playing ? 0.85 : 0.65
        enabled: false
        Behavior on opacity { NumberAnimation { duration: 300 } }
    }

    Rectangle {
        anchors.fill: pill
        anchors.topMargin: 6
        anchors.bottomMargin: -6
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        radius: Theme.radiusPill
        color: Theme.shadowDeep
        opacity: 0.45
        enabled: false
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: Math.min(Theme.playerBarMaxWidth, parent.width - Theme.playerBarMargin * 2)
        height: Theme.playerBarHeight
        radius: height / 2
        clip: true

        color: Theme.darkMode ? Qt.rgba(0.145, 0.145, 0.149, 0.78)
                              : Qt.rgba(0.953, 0.953, 0.953, 0.55)

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: parent.height / 2
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.pillHighlight }
                GradientStop { position: 1.0; color: "#00ffffff" }
            }
            opacity: 0.35
            enabled: false
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 18
                rightMargin: 18
                topMargin: 10
                bottomMargin: 10
            }
            spacing: 16

            RowLayout {
                Layout.preferredWidth: 220
                Layout.minimumWidth: 180
                Layout.maximumWidth: 240
                spacing: 12

                Item {
                    id: coverArea
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56

                    property bool isHover: coverMouse.containsMouse

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 6
                        height: parent.height + 6
                        radius: width / 2
                        color: Theme.accent
                        opacity: root.playing ? 0.28 : 0
                        enabled: false
                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.panelAlt
                        enabled: false
                    }

                    // ★ 提高分辨率 → 消除锯齿
                    Image {
                        id: coverImg
                        anchors.fill: parent
                        source: root.coverUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        sourceSize.width: 224
                        sourceSize.height: 224
                        visible: false
                        layer.enabled: true
                        layer.smooth: true

                        transformOrigin: Item.Center
                        RotationAnimation on rotation {
                            running: root.playing
                                     && coverImg.status === Image.Ready
                                     && !coverArea.isHover
                            from: 0
                            to: 360
                            duration: 40000
                            loops: Animation.Infinite
                        }
                    }

                    // ★ mask 用 antialiasing + smooth
                    Item {
                        id: maskSourceItem
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        layer.smooth: true

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
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
                        maskSource: maskSourceItem
                        smooth: true
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "♪"
                        color: Theme.textMuted
                        font.pixelSize: 18
                        visible: coverImg.status !== Image.Ready
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "#000000"
                        opacity: coverArea.isHover ? 0.55 : 0
                        enabled: false
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "⛶"
                            color: "#ffffff"
                            font.pixelSize: 20
                            opacity: coverArea.isHover ? 1 : 0
                            scale: coverArea.isHover ? 1.0 : 0.6
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: coverMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.fullscreenClicked()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Text {
                        text: root.title || "未播放"
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
                        text: root.artist || "—"
                        color: Theme.textDim
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 300
                spacing: 6

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10

                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: loopBtn.containsMouse ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            anchors.centerIn: parent
                            text: "⟲"
                            color: audioEngine.loopMode === 0
                                   ? Theme.textDim
                                   : Theme.accent
                            font.pixelSize: Theme.fs(20)
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Rectangle {
                            visible: audioEngine.loopMode === 1
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.rightMargin: 1
                            anchors.topMargin: 1
                            width: 12; height: 12; radius: 6
                            color: Theme.accent
                            enabled: false

                            Text {
                                anchors.centerIn: parent
                                text: "1"
                                color: Theme.darkMode ? "#000000" : "#ffffff"
                                font {
                                    family: Theme.fontFamily
                                    pixelSize: 8
                                    bold: true
                                }
                            }
                        }

                        MouseArea {
                            id: loopBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: audioEngine.cycleLoopMode()
                        }
                    }

                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: root.hasPrev && prevBtn.containsMouse
                               ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        opacity: root.hasPrev ? 1.0 : 0.35
                        Text {
                            anchors.centerIn: parent
                            text: "◀"
                            color: root.hasPrev ? Theme.text : Theme.textMuted
                            font.pixelSize: Theme.fs(16)
                        }
                        MouseArea {
                            id: prevBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: root.hasPrev
                            onClicked: root.prevClicked()
                        }
                    }

                    Item {
                        width: 52; height: 52

                        Rectangle {
                            anchors.centerIn: parent
                            width: 52; height: 52; radius: 26
                            color: "transparent"
                            border.color: Theme.accent
                            border.width: 2
                            opacity: 0
                            enabled: false
                            SequentialAnimation on scale {
                                running: root.playing && !root.buffering
                                loops: Animation.Infinite
                                NumberAnimation {
                                    to: 1.35; duration: 1400
                                    easing.type: Easing.OutQuad
                                }
                                NumberAnimation { to: 1.0; duration: 0 }
                            }
                            SequentialAnimation on opacity {
                                running: root.playing && !root.buffering
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.5; duration: 150 }
                                NumberAnimation {
                                    to: 0.0; duration: 1250
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 48; height: 48; radius: 24
                            color: {
                                if (root.buffering)
                                    return Theme.darkMode ? "#2a2d2e" : "#dcdcdc"
                                return playBtn.containsMouse ? Theme.accentHover : Theme.accent
                            }
                            scale: playBtn.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Rectangle {
                                anchors {
                                    top: parent.top
                                    left: parent.left
                                    right: parent.right
                                }
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
                                anchors.centerIn: parent
                                text: root.buffering
                                      ? "◌"
                                      : (root.playing ? "❚❚" : "▶")
                                color: root.buffering
                                       ? Theme.textDim
                                       : (Theme.darkMode ? "#000000" : "#ffffff")
                                font {
                                    family: Theme.fontFamily
                                    pixelSize: 16
                                    bold: true
                                }
                                SequentialAnimation on opacity {
                                    running: root.buffering
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.4; duration: 600 }
                                    NumberAnimation { to: 1.0; duration: 600 }
                                }
                            }

                            MouseArea {
                                id: playBtn
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (audioEngine.isPlaying()) audioEngine.pause()
                                    else audioEngine.resume()
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: root.hasNext && nextBtn.containsMouse
                               ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        opacity: root.hasNext ? 1.0 : 0.35
                        Text {
                            anchors.centerIn: parent
                            text: "▶"
                            color: root.hasNext ? Theme.text : Theme.textMuted
                            font.pixelSize: Theme.fs(16)
                        }
                        MouseArea {
                            id: nextBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: root.hasNext
                            onClicked: root.nextClicked()
                        }
                    }

                    Item { width: 36; height: 36 }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: formatTime(progressArea.dragging
                                         ? progressArea.dragValue * audioEngine.duration
                                         : audioEngine.position)
                        color: progressArea.dragging ? Theme.accent : Theme.textDim
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                        Layout.preferredWidth: 38
                        horizontalAlignment: Text.AlignRight
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    Item {
                        id: progressArea
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16

                        property bool dragging: false
                        property real dragValue: 0
                        property bool hovering: progressMouse.containsMouse

                        readonly property real displayProgress: {
                            if (dragging) return dragValue
                            if (audioEngine.duration > 0)
                                return audioEngine.position / audioEngine.duration
                            return 0
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: (progressArea.hovering || progressArea.dragging) ? 5 : 4
                            radius: 3
                            color: Theme.borderLight
                            enabled: false
                            Behavior on height {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Rectangle {
                                width: parent.width * progressArea.displayProgress
                                height: parent.height
                                radius: parent.radius
                                color: Theme.accent
                                enabled: false

                                Behavior on width {
                                    enabled: !progressArea.dragging
                                    NumberAnimation { duration: 80 }
                                }
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: parent.width * progressArea.displayProgress - width / 2
                            width: progressArea.dragging ? 16 : (progressArea.hovering ? 14 : 0)
                            height: width
                            radius: width / 2
                            color: Theme.accent
                            enabled: false
                            visible: width > 0

                            Behavior on width {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        MouseArea {
                            id: progressMouse
                            anchors.fill: parent
                            hoverEnabled: true

                            function updateDragValue(mx) {
                                var v = mx / width
                                if (v < 0) v = 0
                                if (v > 1) v = 1
                                progressArea.dragValue = v
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
                                if (audioEngine.duration > 0) {
                                    audioEngine.seek(progressArea.dragValue * audioEngine.duration)
                                }
                            }
                            onCanceled: progressArea.dragging = false
                        }
                    }

                    Text {
                        text: formatTime(audioEngine.duration)
                        color: Theme.textDim
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                        Layout.preferredWidth: 38
                    }
                }
            }

            RowLayout {
                Layout.preferredWidth: 300
                Layout.minimumWidth: 260
                Layout.maximumWidth: 340
                spacing: 6

                Item {
                    width: 34; height: 34

                    Canvas {
                        id: progressRing
                        anchors.fill: parent
                        visible: root.downloadProgress >= 0
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            if (root.downloadProgress < 0) return

                            var cx = width / 2
                            var cy = height / 2
                            var r = Math.min(cx, cy) - 2
                            var startAngle = -Math.PI / 2
                            var endAngle = startAngle + Math.PI * 2 * root.downloadProgress

                            ctx.beginPath()
                            ctx.strokeStyle = Theme.accent
                            ctx.lineWidth = 2.5
                            ctx.lineCap = "round"
                            ctx.arc(cx, cy, r, startAngle, endAngle, false)
                            ctx.stroke()
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 17
                        color: dlBtn.containsMouse && root.songCid !== "" && root.downloadProgress < 0
                               ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        opacity: root.songCid !== "" ? 1.0 : 0.35

                        Text {
                            anchors.centerIn: parent
                            text: root.downloadProgress >= 0 ? "◌" : "↓"
                            color: root.downloadProgress >= 0
                                   ? Theme.accent
                                   : (dlBtn.containsMouse && root.songCid !== ""
                                      ? Theme.accent : Theme.text)
                            font {
                                family: Theme.fontFamily
                                pixelSize: Theme.fs(18)
                                bold: true
                            }
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }

                    MouseArea {
                        id: dlBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.songCid !== "" && root.downloadProgress < 0
                        onClicked: {
                            if (root.songCid === "") return
                            // ★ 加 album 参数
                            audioCache.downloadToLibrary(
                                root.songCid,
                                root.title,
                                root.artist,
                                root.songAlbum,
                                root.coverUrl,
                                root.songUrl
                            )
                        }
                    }
                }

                Connections {
                    target: root
                    function onDownloadProgressChanged() {
                        progressRing.requestPaint()
                    }
                }

                Rectangle {
                    width: 34; height: 34; radius: 17
                    color: addToPlBtn.containsMouse && root.songCid !== ""
                           ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    opacity: root.songCid !== "" ? 1.0 : 0.35

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: addToPlBtn.containsMouse && root.songCid !== ""
                               ? Theme.accent
                               : Theme.text
                        font {
                            family: Theme.fontFamily
                            pixelSize: Theme.fs(20)
                            bold: true
                        }
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    MouseArea {
                        id: addToPlBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.songCid !== ""
                        onClicked: {
                            pickerDialog.openFor(root.songCid,
                                                 root.title,
                                                 root.artist,
                                                 root.coverUrl)
                        }
                    }
                }

                Text {
                    text: "🔊"
                    color: Theme.textDim
                    font.pixelSize: Theme.fs(15)
                }

                Slider {
                    id: volumeSlider
                    z: 10
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    from: 0
                    to: 1
                    stepSize: 0
                    live: true
                    enabled: true

                    Component.onCompleted: {
                        value = 0.5
                        audioEngine.setVolume(value)
                    }
                    onMoved: audioEngine.setVolume(value)

                    background: Rectangle {
                        x: parent.leftPadding
                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                        width: parent.availableWidth
                        height: parent.hovered ? 5 : 4
                        radius: 3
                        color: Theme.borderLight
                        enabled: false
                        Behavior on height { NumberAnimation { duration: 120 } }

                        Rectangle {
                            width: parent.parent.visualPosition * parent.width
                            height: parent.height
                            radius: parent.radius
                            color: Theme.accent
                            enabled: false
                        }
                    }

                    handle: Rectangle {
                        x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                        width: parent.pressed ? 16 : 12
                        height: width
                        radius: width / 2
                        color: Theme.accent
                        z: 1
                        Behavior on width { NumberAnimation { duration: 100 } }
                    }
                }

                Rectangle {
                    width: 36; height: 36; radius: 18
                    color: playlistBtn.containsMouse ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: "☰"
                        color: Theme.text
                        font.pixelSize: Theme.fs(18)
                    }

                    MouseArea {
                        id: playlistBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.playlistClicked()
                    }
                }
            }
        }
    }

    PlaylistPickerDialog {
        id: pickerDialog
    }

    function formatTime(ms) {
        if (!ms || ms < 0) return "0:00"
        let s = Math.floor(ms / 1000)
        let m = Math.floor(s / 60); s = s % 60
        return m + ":" + s.toString().padStart(2, "0")
    }
}