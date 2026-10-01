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

    readonly property int lyricRowHeight: 110

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
        radius: 22
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
        lines.push("—— 来自 Monster Siren Records")
        return lines.join("\n")
    }

    Popup {
        id: lyricMenu
        width: 220
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
            radius: 10
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
                    radius: 6
                    color: seekArea.containsMouse ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                    spacing: 10

                    Text {
                        text: "▶"
                        color: Theme.accent
                        font.pixelSize: Theme.fs(12)
                    }

                    Text {
                        text: "跳转到这里"
                        color: Theme.text
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                        Layout.fillWidth: true
                    }

                    Text {
                        text: formatTime(lyricMenu.menuLineTime)
                        color: Theme.textMuted
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                    }
                }

                MouseArea {
                    id: seekArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        audioEngine.seek(lyricMenu.menuLineTime)
                        showToast("已跳转到 " + formatTime(lyricMenu.menuLineTime))
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
                    radius: 6
                    color: copyLineArea.containsMouse ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                    spacing: 10

                    Text {
                        text: "📋"
                        font.pixelSize: Theme.fs(12)
                    }

                    Text {
                        text: "复制这句歌词"
                        color: Theme.text
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                        Layout.fillWidth: true
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
                    radius: 6
                    color: shareLineArea.containsMouse ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                    spacing: 10

                    Text {
                        text: "📤"
                        font.pixelSize: Theme.fs(12)
                    }

                    Text {
                        text: "分享这句歌词"
                        color: Theme.text
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                        Layout.fillWidth: true
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
                    radius: 6
                    color: copyAllArea.containsMouse ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                    spacing: 10

                    Text {
                        text: "📄"
                        font.pixelSize: Theme.fs(12)
                    }

                    Text {
                        text: "复制全部歌词"
                        color: Theme.text
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                        Layout.fillWidth: true
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
                    radius: 6
                    color: shareAllArea.containsMouse ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                    spacing: 10

                    Text {
                        text: "🎁"
                        font.pixelSize: Theme.fs(12)
                    }

                    Text {
                        text: "分享整首歌词"
                        color: Theme.accent
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(13); bold: true }
                        Layout.fillWidth: true
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

    function formatTime(ms) {
        if (!ms || ms < 0) return "0:00"
        let s = Math.floor(ms / 1000)
        let m = Math.floor(s / 60); s = s % 60
        return m + ":" + s.toString().padStart(2, "0")
    }

    // ============================================================
    // 背景
    // ============================================================
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusWindow
        color: Theme.bg
        clip: true

        Image {
            id: bgImage
            anchors.fill: parent
            source: root.coverUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: false
        }

        MultiEffect {
            source: bgImage
            anchors.fill: parent
            blurEnabled: true
            blur: 1.0
            blurMax: 80
            opacity: 0.35
            visible: root.coverUrl !== ""
            enabled: false
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.bg
            opacity: 0.6
            enabled: false
        }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: parent.height * 0.5
            bottomLeftRadius: parent.radius
            bottomRightRadius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Theme.shadowDeep }
            }
            enabled: false
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 40

        // ============================================================
        // 左侧封面（★ 圆角修复）
        // ============================================================
        Item {
            id: fullCoverArea
            Layout.preferredWidth: Math.min(parent.height - 40, 380)
            Layout.preferredHeight: width
            Layout.alignment: Qt.AlignVCenter

            property bool isHover: fullCoverMouse.containsMouse
            readonly property real coverRadius: 14

            Rectangle {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 4
                anchors.verticalCenterOffset: 8
                width: parent.width * 0.9
                height: parent.height * 0.9
                radius: fullCoverArea.coverRadius + 2
                color: Theme.shadowDeep
                enabled: false
            }

            Rectangle {
                id: coverBase
                anchors.fill: parent
                radius: fullCoverArea.coverRadius
                color: Theme.panelAlt
            }

            Image {
                id: coverImage
                anchors.fill: parent
                source: root.coverUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: 760
                sourceSize.height: 760
                visible: false
                layer.enabled: true
                layer.smooth: true

                transformOrigin: Item.Center
                rotation: 0

                NumberAnimation on rotation {
                    running: audioEngine.isPlaying()
                             && root.coverUrl !== ""
                             && !fullCoverArea.isHover
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
                    radius: fullCoverArea.coverRadius
                    color: "white"
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
                radius: fullCoverArea.coverRadius
                color: "#000000"
                opacity: fullCoverArea.isHover ? 0.55 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }

                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    opacity: fullCoverArea.isHover ? 1 : 0
                    scale: fullCoverArea.isHover ? 1.0 : 0.85
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
                        radius: 32
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
        // 右侧信息 + 歌词
        // ============================================================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 20

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: root.title || "未播放"
                        color: Theme.textBright
                        font {
                            family: Theme.fontFamily
                            pixelSize: Theme.fs(28)
                            bold: true
                            letterSpacing: 0.5
                        }
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.artist || "—"
                        color: Theme.textDim
                        font {
                            family: Theme.fontFamily
                            pixelSize: Theme.fs(16)
                            letterSpacing: 0.3
                        }
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 78
                    Layout.preferredHeight: 30
                    radius: 15
                    color: root.showTranslation
                           ? Theme.accent
                           : (transBtn.containsMouse ? Theme.hover : "transparent")
                    border.color: root.showTranslation ? "transparent" : Theme.border
                    border.width: root.showTranslation ? 0 : 1
                    Behavior on color { ColorAnimation { duration: 180 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: "译"
                            color: root.showTranslation
                                   ? (Theme.darkMode ? "#000000" : "#ffffff")
                                   : Theme.textDim
                            font {
                                family: Theme.fontFamily
                                pixelSize: Theme.fs(13)
                                bold: true
                            }
                        }

                        Text {
                            text: root.showTranslation ? "开" : "关"
                            color: root.showTranslation
                                   ? (Theme.darkMode ? "#000000" : "#ffffff")
                                   : Theme.textDim
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                        }
                    }

                    MouseArea {
                        id: transBtn
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.showTranslation = !root.showTranslation
                    }
                }
            }

            // ============================================================
            // 歌词区：滚动时去模糊，2 秒后恢复
            // ============================================================
            Item {
                id: lyricContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
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

                            property real fontSize: {
                                if (distance === 0) return Theme.fs(30)
                                if (distance === 1) return Theme.fs(22)
                                if (distance === 2) return Theme.fs(18)
                                if (distance === 3) return Theme.fs(16)
                                return Theme.fs(15)
                            }

                            property real baseBlur: {
                                if (distance === 0) return 0.0
                                if (distance === 1) return 0.15
                                if (distance === 2) return 0.35
                                if (distance === 3) return 0.55
                                return 0.7
                            }

                            property real blurAmount: baseBlur * lyricContainer.blurFactor

                            property real contentOpacity: {
                                if (distance === 0) return 1.0
                                if (distance === 1) return 0.7
                                if (distance === 2) return 0.5
                                if (distance === 3) return 0.35
                                return 0.25
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: 8
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
                                width: 3
                                height: (lyricRow.isHover || lyricRow.isCurrent) ? 28 : 0
                                radius: 1.5
                                color: lyricRow.isCurrent ? Theme.accent : Theme.textDim
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
                                    color: lyricRow.isCurrent ? Theme.accent : Theme.text
                                    font {
                                        family: Theme.fontFamily
                                        pixelSize: lyricRow.fontSize
                                        weight: lyricRow.isCurrent ? Font.Bold : Font.Medium
                                    }
                                    horizontalAlignment: Text.AlignLeft
                                    wrapMode: Text.WordWrap
                                    opacity: lyricRow.contentOpacity

                                    layer.enabled: lyricRow.blurAmount > 0.01
                                    layer.effect: MultiEffect {
                                        blurEnabled: true
                                        blur: lyricRow.blurAmount
                                        blurMax: 32
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
                                    color: lyricRow.isCurrent ? Theme.text : Theme.textMuted
                                    font {
                                        family: Theme.fontFamily
                                        pixelSize: lyricRow.isCurrent
                                                  ? Theme.fs(16)
                                                  : Theme.fs(13)
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
                                text: "点击跳转"
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
                                                      formatTime(modelData.time))
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