import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root

    signal exitFullscreen()

    property string coverUrl: ""
    property string title: ""
    property string artist: ""
    property var lyricLines: []
    property int currentLyricIndex: -1
    property bool showTranslation: true

    property bool showLyrics: true

    // ★ Hero 动画期间隐藏真实封面（避免和过渡卡片重叠）
    property bool coverHidden: false

    // ★ 暴露大封面容器，供 Main.qml 计算 Hero 动画目标位置
    readonly property alias coverWrapperItem: coverWrapper

    readonly property int lyricRowHeight: Theme.fs(88)

    // 鼓点脉冲 0..1：由 audioEngine.beat 驱动，背景据此缩放/提亮
    property real beatPulse: 0

    Connections {
        target: audioEngine
        function onBeat(strength) {
            // 幅度压低、回落放慢：每次鼓点是一个完整的小呼吸，
            // 而不是频繁的闪烁
            root.beatPulse = Math.min(0.85, 0.32 + strength * 0.45)
            beatDecay.restart()
        }
    }

    NumberAnimation {
        id: beatDecay
        target: root
        property: "beatPulse"
        to: 0
        duration: 340
        easing.type: Easing.OutCubic
    }

    TextEdit {
        id: clipboardHelper
        visible: false
        width: 0
        height: 0

        function copyText(text) {
            clipboardHelper.text = text
            clipboardHelper.selectAll()
            clipboardHelper.copy()
        }
    }

    Rectangle {
        id: toast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 80
        width: toastText.implicitWidth + 48
        height: 44
        radius: 0
        color: Theme.darkMode ? "#ee000000" : "#eeffffff"
        border.color: Theme.accent
        border.width: 1
        opacity: 0
        visible: opacity > 0.01
        z: 1000

        Behavior on opacity { NumberAnimation { duration: 220 } }

        Text {
            id: toastText
            anchors.centerIn: parent
            color: Theme.textBright
            font { family: Theme.fontFamily; pixelSize: Theme.fs(13); bold: true }
        }

        Timer {
            id: toastTimer
            interval: 2200
            onTriggered: toast.opacity = 0
        }
    }

    function showToast(msg) {
        toastText.text = msg
        toast.opacity = 1
        toastTimer.restart()
    }

    function buildShareText(singleLine) {
        let lines = []
        lines.push("🎵 " + (root.title || "未命名"))
        if (root.artist) lines.push("🎤 " + root.artist)
        lines.push("")

        if (singleLine) {
            let idx = -1
            for (let i = 0; i < root.lyricLines.length; i++) {
                if (root.lyricLines[i].text === singleLine) {
                    idx = i
                    break
                }
            }
            if (idx >= 0) {
                let start = Math.max(0, idx - 1)
                let end = Math.min(root.lyricLines.length - 1, idx + 1)
                for (let i = start; i <= end; i++) {
                    let marker = (i === idx) ? "▶ " : "   "
                    lines.push(marker + root.lyricLines[i].text)
                    if (showTranslation && root.lyricLines[i].translated) {
                        lines.push("   " + root.lyricLines[i].translated)
                    }
                }
            }
        } else {
            for (let i = 0; i < root.lyricLines.length; i++) {
                lines.push(root.lyricLines[i].text)
                if (showTranslation && root.lyricLines[i].translated) {
                    lines.push(root.lyricLines[i].translated)
                }
            }
        }

        lines.push("")
        lines.push("—— 来自 Mass")
        return lines.join("\n")
    }

    Popup {
        id: lyricMenu
        width: 200
        padding: 0
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        z: 2000

        property string menuLineText: ""
        property int menuLineTime: 0

        function popupAt(sceneX, sceneY, lineText, lineTime) {
            menuLineText = lineText
            menuLineTime = lineTime

            let px = sceneX
            let py = sceneY
            if (px + width > root.width) px = root.width - width - 8
            if (py + height > root.height) py = root.height - height - 8

            x = px
            y = py
            open()
        }

        background: Rectangle {
            color: Theme.panel
            radius: 0
            border.color: Theme.border
            border.width: 1

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 6
                anchors.leftMargin: 2
                anchors.rightMargin: -2
                radius: parent.radius
                color: Theme.shadowDeep
                opacity: 0.4
                z: -1
            }
        }

        contentItem: Column {
            spacing: 0

            Item {
                width: lyricMenu.width
                height: 40

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 0
                    color: seekArea.containsMouse ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                    spacing: 10

                    Text {
                        text: "跳转到这里"
                        color: seekArea.containsMouse ? Theme.text : Theme.textDim
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                        Layout.fillWidth: true
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    Text {
                        text: Theme.formatTime(lyricMenu.menuLineTime)
                        color: Theme.textMuted
                        opacity: seekArea.containsMouse ? 1.0 : 0.65
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                }

                MouseArea {
                    id: seekArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        audioEngine.seek(lyricMenu.menuLineTime)
                        showToast("已跳转到 " + Theme.formatTime(lyricMenu.menuLineTime))
                        lyricMenu.close()
                    }
                }
            }

            Rectangle {
                width: parent.width - 16
                x: 8
                height: 1
                color: Theme.borderLight
                opacity: 0.5
            }

            Item {
                width: lyricMenu.width
                height: 40

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 0
                    color: copyLineArea.containsMouse ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                    spacing: 10

                    Text {
                        text: "复制这句歌词"
                        color: copyLineArea.containsMouse ? Theme.text : Theme.textDim
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                        Layout.fillWidth: true
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                MouseArea {
                    id: copyLineArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        clipboardHelper.copyText(lyricMenu.menuLineText)
                        showToast("已复制这句歌词")
                        lyricMenu.close()
                    }
                }
            }

            Item {
                width: lyricMenu.width
                height: 40

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 0
                    color: shareLineArea.containsMouse ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                    spacing: 10

                    Text {
                        text: "分享这句歌词"
                        color: shareLineArea.containsMouse ? Theme.text : Theme.textDim
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                        Layout.fillWidth: true
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                MouseArea {
                    id: shareLineArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        let txt = buildShareText(lyricMenu.menuLineText)
                        clipboardHelper.copyText(txt)
                        showToast("分享文本已复制到剪贴板")
                        lyricMenu.close()
                    }
                }
            }

            Rectangle {
                width: parent.width - 16
                x: 8
                height: 1
                color: Theme.borderLight
                opacity: 0.5
            }

            Item {
                width: lyricMenu.width
                height: 40

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 0
                    color: copyAllArea.containsMouse ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                    spacing: 10

                    Text {
                        text: "复制全部歌词"
                        color: copyAllArea.containsMouse ? Theme.text : Theme.textDim
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                        Layout.fillWidth: true
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                MouseArea {
                    id: copyAllArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        let txt = buildShareText("")
                        clipboardHelper.copyText(txt)
                        showToast("整首歌词已复制")
                        lyricMenu.close()
                    }
                }
            }

            Item {
                width: lyricMenu.width
                height: 40

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 0
                    color: shareAllArea.containsMouse ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                    spacing: 10

                    Text {
                        text: "分享整首歌词"
                        color: shareAllArea.containsMouse ? Theme.accent : Theme.textDim
                        font {
                            family: Theme.fontFamily
                            pixelSize: Theme.fs(13)
                            bold: shareAllArea.containsMouse
                        }
                        Layout.fillWidth: true
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                MouseArea {
                    id: shareAllArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        let txt = buildShareText("")
                        clipboardHelper.copyText(txt)
                        showToast("分享文本已复制到剪贴板")
                        lyricMenu.close()
                    }
                }
            }
        }
    }

    // ============================================================
    // 背景（★ 修复：切换歌曲时不再残留旧封面）
    // ============================================================
    Rectangle {
        anchors.fill: parent
        radius: 0
        color: Theme.bg
        clip: true

        // ★ 底衬：当背景图未加载时，显示主题纯色
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.bg
            enabled: false
        }

        Image {
            id: bgImage
            anchors.fill: parent
            source: root.coverUrl
            fillMode: Image.PreserveAspectCrop
            // 动态背景：缓慢缩放，让静态封面有呼吸感
            scale: 1.04
            SequentialAnimation on scale {
                loops: Animation.Infinite
                running: bgImage.status === Image.Ready
                NumberAnimation {
                    to: 1.14; duration: 20000; easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 1.04; duration: 20000; easing.type: Easing.InOutSine
                }
            }
            asynchronous: true
            cache: false          // ★ 关键：避免显示上一次缓存的封面
            visible: false
        }

        MultiEffect {
            id: bgBlur
            source: bgImage
            anchors.fill: parent
            blurEnabled: true
            blur: 1.0
            blurMax: 80
            // 鼓点时整层被「推」一下：轻微放大，并按主题变亮/变暗。
            // 深色模式下白闪会像漏光，所以那里改成压暗。
            opacity: root.coverUrl !== "" ? 0.35 + root.beatPulse * 0.22 : 0
            scale: 1.0 + root.beatPulse * 0.07
            brightness: Theme.darkMode
                        ? (0.0 - root.beatPulse * 0.16)
                        : (0.02 + root.beatPulse * 0.12)
            transformOrigin: Item.Center
            // ★ 只在图片真正加载完成后才显示
            visible: bgImage.status === Image.Ready && root.coverUrl !== ""
            enabled: false
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.bg
            opacity: Theme.darkMode ? 0.72 : 0.82
            enabled: false
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: parent.height * 0.5
            bottomLeftRadius: 0
            bottomRightRadius: 0
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Theme.shadowDeep }
            }
            enabled: false
        }

        // 鼓点闪光：浅色提亮、深色压暗
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.darkMode ? "#000000" : "#ffffff"
            opacity: root.beatPulse * (Theme.darkMode ? 0.14 : 0.07)
            enabled: false
        }
    }

    // ============================================================
    // 主内容
    // ============================================================
    Item {
        id: contentRoot
        anchors.fill: parent
        anchors.margins: 40

        readonly property real coverMinSize: Math.min(contentRoot.height - 96,
                                                       contentRoot.width * 0.36)
        readonly property real coverMaxSize: Math.min(contentRoot.height - 60,
                                                       contentRoot.width * 0.46)
        readonly property real lyricsLeftMargin: coverMinSize + 56
        readonly property real headerClosedWidth: Math.min(480, contentRoot.width * 0.55)

        readonly property real coverCenterY: 60 + 20
                                              + (contentRoot.height - 60 - 20) / 2

        Item {
            id: headerWrapper
            height: 60
            y: 0
            z: 200

            x: 0
            width: contentRoot.width

            RowLayout {
                id: headerRow
                anchors.fill: parent
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: root.title || "未播放"
                        color: Theme.textBright
                        font {
                            family: Theme.fontFamily
                            pixelSize: Theme.fs(28)
                            bold: true
                            letterSpacing: 0.5
                        }
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.artist || "—"
                        color: Theme.textMuted
                        font {
                            family: Theme.fontFamily
                            pixelSize: Theme.microSize
                            letterSpacing: 1.4
                        }
                        elide: Text.ElideRight
                    }
                }

                Item {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 30
                
                    Row {
                        anchors.centerIn: parent
                        spacing: 7
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "词"
                            color: root.showLyrics ? Theme.text : Theme.textDim
                            font {
                                family: Theme.fontFamily
                                pixelSize: Theme.fs(12)
                                weight: Font.DemiBold
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.showLyrics ? "ON" : "OFF"
                            color: root.showLyrics ? Theme.accentHover : Theme.textMuted
                            font {
                                family: Theme.monoFamily
                                pixelSize: Theme.microSize
                                letterSpacing: 1
                            }
                        }
                    }
                
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 1
                        color: root.showLyrics ? Theme.accent : Theme.border
                        opacity: root.showLyrics ? 1 : 0.5
                    }
                
                    MouseArea {
                        id: lyrBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showLyrics = !root.showLyrics
                    }
                }

                Item {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 30
                
                    Row {
                        anchors.centerIn: parent
                        spacing: 7
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "译"
                            color: root.showTranslation ? Theme.text : Theme.textDim
                            font {
                                family: Theme.fontFamily
                                pixelSize: Theme.fs(12)
                                weight: Font.DemiBold
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.showTranslation ? "ON" : "OFF"
                            color: root.showTranslation ? Theme.accentHover : Theme.textMuted
                            font {
                                family: Theme.monoFamily
                                pixelSize: Theme.microSize
                                letterSpacing: 1
                            }
                        }
                    }
                
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 1
                        color: root.showTranslation ? Theme.accent : Theme.border
                        opacity: root.showTranslation ? 1 : 0.5
                    }
                
                    MouseArea {
                        id: transBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showTranslation = !root.showTranslation
                    }
                }

                // 关闭：回到上一页
                Item {
                    Layout.preferredWidth: 78
                    Layout.preferredHeight: 30
                    Layout.leftMargin: 10

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "关闭"
                            color: closeBtn.containsMouse ? Theme.accentHover : Theme.textDim
                            font {
                                family: Theme.fontFamily
                                pixelSize: Theme.fs(12)
                                weight: Font.DemiBold
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "ESC"
                            color: Theme.textMuted
                            font {
                                family: Theme.monoFamily
                                pixelSize: Theme.microSize
                                letterSpacing: 1
                            }
                        }
                    }

                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 1
                        color: closeBtn.containsMouse ? Theme.accent : Theme.border
                        opacity: 0.6
                    }

                    MouseArea {
                        id: closeBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.exitFullscreen()
                    }
                }
            }
        }

        // ============================================================
        // 封面（★ 加 opacity 绑定，Hero 动画期间隐藏）
        // ============================================================
        Item {
            id: coverWrapper

            opacity: root.coverHidden ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 150 } }

            property real coverSize: root.showLyrics
                                     ? contentRoot.coverMinSize
                                     : contentRoot.coverMaxSize

            width: coverSize
            height: coverSize

            x: root.showLyrics
               ? 0
               : (contentRoot.width - contentRoot.coverMaxSize) / 2

            y: contentRoot.coverCenterY - height / 2

            Behavior on coverSize {
                NumberAnimation {
                    duration: 450
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on x {
                NumberAnimation {
                    duration: 450
                    easing.type: Easing.OutCubic
                }
            }

            property bool isHover: fullCoverMouse.containsMouse
            readonly property real coverRadius: 0

            Rectangle {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 4
                anchors.verticalCenterOffset: 8
                width: parent.width * 0.9
                height: parent.height * 0.9
                radius: coverWrapper.coverRadius + 2
                color: Theme.shadowDeep
                enabled: false
            }

            Rectangle {
                id: coverBase
                anchors.fill: parent
                radius: coverWrapper.coverRadius
                color: Theme.panelAlt
            }

            Image {
                id: coverImage
                anchors.fill: parent
                source: root.coverUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: 900
                sourceSize.height: 900
                visible: false
                layer.enabled: true
                layer.smooth: true

                transformOrigin: Item.Center
                rotation: 0

                NumberAnimation on rotation {
                    running: audioEngine.isPlaying()
                             && root.coverUrl !== ""
                             && !coverWrapper.isHover
                             && coverImage.status === Image.Ready
                    from: 0
                    to: 360
                    duration: 60000
                    loops: Animation.Infinite
                }
            }

            Item {
                id: coverMask
                anchors.fill: parent
                visible: false
                layer.enabled: true

                Rectangle {
                    anchors.fill: parent
                    radius: coverWrapper.coverRadius
                    color: "white"
                    antialiasing: true
                    smooth: true
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: coverImage
                visible: coverImage.status === Image.Ready
                maskEnabled: true
                maskSource: coverMask
            }

            Text {
                anchors.centerIn: parent
                text: "♪"
                color: Theme.textMuted
                font.pixelSize: 80
                visible: coverImage.status !== Image.Ready
            }

            Rectangle {
                anchors.fill: parent
                radius: coverWrapper.coverRadius
                color: "#000000"
                opacity: coverWrapper.isHover ? 0.55 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }

                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    opacity: coverWrapper.isHover ? 1 : 0
                    scale: coverWrapper.isHover ? 1.0 : 0.85
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 64
                        height: 64
                        radius: 0
                        color: Theme.accent

                        Text {
                            anchors.centerIn: parent
                            text: "⛶"
                            color: Theme.darkMode ? "#000000" : "#ffffff"
                            font.pixelSize: 26
                            font.bold: true
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "退出全屏"
                        color: "#ffffff"
                        font {
                            family: Theme.fontFamily
                            pixelSize: Theme.fs(14)
                            bold: true
                        }
                    }
                }
            }

            MouseArea {
                id: fullCoverMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.exitFullscreen()
            }
        }

        // ============================================================
        // 歌词
        // ============================================================
        Item {
            id: lyricsWrapper
            anchors {
                top: headerWrapper.bottom
                topMargin: 20
                left: parent.left
                leftMargin: contentRoot.lyricsLeftMargin
                right: parent.right
                bottom: parent.bottom
            }
            z: 100

            opacity: root.showLyrics ? 1 : 0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutCubic
                }
            }


            Item {
                id: lyricContainer
                // 高度取行高的奇数倍：滚动时裁切边永远落在两行之间，不会切断文字
                readonly property int visibleRows: {
                    var n = Math.floor(parent.height / root.lyricRowHeight)
                    if (n < 1) return 1
                    if (n % 2 === 0) n -= 1
                    return Math.max(1, n)
                }
                width: parent.width
                height: visibleRows * root.lyricRowHeight
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                readonly property real autoY: {
                    if (root.currentLyricIndex < 0)
                        return (height - root.lyricRowHeight) / 2
                    return (height - root.lyricRowHeight) / 2
                           - root.currentLyricIndex * root.lyricRowHeight
                }

                property bool userScrolling: false
                property real userY: 0
                readonly property real blurFactor: userScrolling ? 0 : 1

                Column {
                    id: lyricColumn
                    width: parent.width
                    y: lyricContainer.userScrolling
                       ? lyricContainer.userY
                       : lyricContainer.autoY
                    spacing: 0

                    Behavior on y {
                        enabled: !lyricContainer.userScrolling
                        NumberAnimation {
                            duration: 500
                            easing.type: Easing.OutCubic
                        }
                    }

                    Repeater {
                        model: root.lyricLines

                        delegate: Item {
                            id: lyricRow
                            width: lyricColumn.width
                            height: root.lyricRowHeight

                            property int myIndex: index
                            property int distance: {
                                if (root.currentLyricIndex < 0) return 999
                                return Math.abs(myIndex - root.currentLyricIndex)
                            }
                            property bool isCurrent: distance === 0
                            property bool isHover: rowMouse.containsMouse

                            // 不再让非当前歌词缩小：整列统一字号，
                            // 远近只靠模糊表达（景深），文字本身不再「瘦一圈」
                            property real fontSize: lyricRow.isCurrent
                                                  ? Theme.fs(21) : Theme.fs(16)

                            // 深度模糊：非当前行全部加重，越远越糊
                            property real baseBlur: {
                                if (distance === 0) return 0.0
                                if (distance === 1) return 0.55
                                if (distance === 2) return 0.85
                                if (distance === 3) return 1.15
                                return 1.5
                            }

                            property real blurAmount: 0

                            // 只做轻微压暗（不再靠透明度把非当前行「淡掉」）
                            property real contentOpacity: {
                                if (distance === 0) return 1.0
                                if (distance === 1) return 0.78
                                if (distance === 2) return 0.6
                                return 0.45
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: 0
                                color: lyricRow.isHover
                                       ? (Theme.darkMode ? "#15ffffff" : "#10000000")
                                       : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                enabled: false
                            }

                            Rectangle {
                                anchors {
                                    left: parent.left
                                    leftMargin: 4
                                    verticalCenter: parent.verticalCenter
                                }
                                width: 2
                                height: lyricRow.isCurrent ? 22 : 0
                                radius: 0
                                color: Theme.accent
                                opacity: lyricRow.isHover ? 0.7 : 1.0
                                Behavior on height {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: modelData.text
                                    color: lyricRow.isCurrent ? Theme.text : Theme.textDim
                                    font {
                                        family: Theme.fontFamily
                                        pixelSize: lyricRow.fontSize
                                        weight: lyricRow.isCurrent ? Font.Bold : Font.Medium
                                    }
                                    horizontalAlignment: Text.AlignLeft
                                    wrapMode: Text.WordWrap
                                    opacity: lyricRow.contentOpacity

                                    // 当前行已无模糊，改为点亮辉光；非当前行仍走模糊
                                    layer.enabled: false
                                    layer.effect: MultiEffect {
                                        blurEnabled: lyricRow.blurAmount > 0.01
                                        blur: lyricRow.blurAmount
                                        blurMax: 32
                                        // 辉光：与文字同色的居中模糊阴影（不涉及着色器）
                                        // 仅深色模式点亮，亮色下辉光显得脏
                                        shadowEnabled: lyricRow.isCurrent && Theme.darkMode
                                        shadowColor: Theme.accent
                                        shadowBlur: 1.0
                                        shadowVerticalOffset: 0
                                        shadowHorizontalOffset: 0
                                    }

                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                    Behavior on font.pixelSize {
                                        NumberAnimation {
                                            duration: 300
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    visible: root.showTranslation
                                             && modelData.translated !== undefined
                                             && modelData.translated !== ""
                                    text: modelData.translated || ""
                                    color: lyricRow.isCurrent ? Theme.textDim : Theme.textMuted
                                    font {
                                        family: Theme.monoFamily
                                        pixelSize: Theme.fs(10.5)
                                        letterSpacing: 0.4
                                    }
                                    horizontalAlignment: Text.AlignLeft
                                    wrapMode: Text.WordWrap
                                    opacity: lyricRow.contentOpacity * 0.85

                                    layer.enabled: lyricRow.blurAmount > 0.01
                                    layer.effect: MultiEffect {
                                        blurEnabled: true
                                        blur: lyricRow.blurAmount
                                        blurMax: 32
                                    }

                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }
                            }

                            Text {
                                anchors {
                                    right: parent.right
                                    rightMargin: 12
                                    verticalCenter: parent.verticalCenter
                                }
                                visible: lyricRow.isHover
                                text: Theme.formatTime(modelData.time)
                                color: Theme.textMuted
                                font {
                                    family: Theme.fontFamily
                                    pixelSize: Theme.fs(10)
                                    letterSpacing: 0.5
                                }
                                opacity: lyricRow.isHover ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor

                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        if (modelData.time !== undefined) {
                                            audioEngine.seek(modelData.time)
                                            showToast("已跳转到 " +
                                                      Theme.formatTime(modelData.time))
                                        }
                                    } else if (mouse.button === Qt.RightButton) {
                                        let scenePos = mapToItem(null,
                                                                  mouse.x,
                                                                  mouse.y)
                                        lyricMenu.popupAt(scenePos.x,
                                                          scenePos.y,
                                                          modelData.text,
                                                          modelData.time)
                                    }
                                }
                            }
                        }
                    }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse
                    onWheel: (event) => {
                        let dy = event.angleDelta.y
                        if (dy === 0) return

                        if (!lyricContainer.userScrolling) {
                            lyricContainer.userY = lyricColumn.y
                            lyricContainer.userScrolling = true
                        }

                        let newY = lyricContainer.userY + dy * 0.5

                        let minY = -(lyricColumn.height - lyricContainer.height + 60)
                        let maxY = 60
                        if (newY > maxY) newY = maxY
                        if (newY < minY) newY = minY

                        lyricContainer.userY = newY
                        recoverTimer.restart()
                    }
                }

                Timer {
                    id: recoverTimer
                    interval: 2000
                    onTriggered: {
                        lyricContainer.userScrolling = false
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: root.lyricLines.length === 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "♪"
                        color: Theme.textMuted
                        font.pixelSize: 36
                        opacity: 0.5
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "暂无歌词"
                        color: Theme.textMuted
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(14) }
                    }
                }
            }
        }
    }
}