import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Item {
    id: root

    signal requestHideToTray()
    signal requestRestart()
    signal requestQuit()

    property real audioCacheSizeMB: 0
    property real httpCacheSizeMB: 0
    property bool clearing: false

    // ★ 检查更新状态
    property string updateStatus: "idle"    // idle / checking / available / notAvailable / failed
    property string updateMessage: ""
    property string updateUrl: ""
    property string updateVersion: ""

    function refreshCacheSizes() {
        audioCacheSizeMB = audioCache.totalSize() / 1024 / 1024
        httpCacheSizeMB = networkManager.httpCacheSize() / 1024 / 1024
    }

    function formatSize(mb) {
        if (mb >= 1024) return (mb / 1024).toFixed(2) + " GB"
        if (mb < 0.1) return "0 MB"
        return mb.toFixed(1) + " MB"
    }

    Component.onCompleted: refreshCacheSizes()

    // ★ 更新检查结果
    Connections {
        target: appSettings
        function onUpdateAvailable(version, url, notes) {
            root.updateStatus = "available"
            root.updateVersion = version
            root.updateUrl = url
            root.updateMessage = "发现新版本 " + version
            if (notes !== "") {
                root.updateMessage += " ｜ " + notes
            }
        }
        function onUpdateNotAvailable(version) {
            root.updateStatus = "notAvailable"
            root.updateMessage = "当前已是最新版本（" + version + "）"
        }
        function onUpdateCheckFailed(error) {
            root.updateStatus = "failed"
            root.updateMessage = "检查失败：" + error
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Flickable {
            anchors.fill: parent
            contentHeight: contentCol.height + 80
            clip: true

            ColumnLayout {
                id: contentCol
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: 16
                    leftMargin: 96
                    rightMargin: 40
                }
                spacing: 20

                // ============================================================
                // 顶部栏
                // ============================================================
                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 8

                    Text {
                        text: "设置"
                        color: Theme.text
                        font { family: Theme.fontFamily; pixelSize: Theme.fs(24); bold: true }
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 16
                        color: closeTopBtn.containsMouse ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: closeTopBtn.containsMouse ? Theme.danger : Theme.textDim
                            font.pixelSize: Theme.fs(14)
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: closeTopBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.requestHideToTray()
                        }
                    }
                }

                // ============================================================
                // 外观
                // ============================================================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 190
                    radius: Theme.radiusLarge
                    color: Theme.panel

                    ColumnLayout {
                        anchors { fill: parent; margins: 20 }
                        spacing: 14

                        Text {
                            text: "外观"
                            color: Theme.accent
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(14); bold: true }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "暗色模式"
                                color: Theme.text
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                Layout.fillWidth: true
                            }
                            Switch {
                                checked: appSettings.darkMode
                                onToggled: {
                                    appSettings.darkMode = checked
                                    Theme.darkMode = checked
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            Text {
                                text: "字体大小"
                                color: Theme.text
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                Layout.preferredWidth: 80
                            }

                            Text {
                                text: "A"
                                color: Theme.textDim
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                            }

                            Slider {
                                id: fontSlider
                                Layout.fillWidth: true
                                Layout.preferredHeight: 24
                                from: 0.8
                                to: 1.5
                                stepSize: 0.05
                                value: appSettings.fontScale
                                onMoved: appSettings.fontScale = value

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
                                    width: parent.pressed ? 18 : 14
                                    height: width
                                    radius: width / 2
                                    color: Theme.accent
                                    z: 1
                                    Behavior on width { NumberAnimation { duration: 100 } }
                                }
                            }

                            Text {
                                text: "A"
                                color: Theme.textDim
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(17); bold: true }
                            }

                            Text {
                                text: Math.round(fontSlider.value * 100) + "%"
                                color: Theme.text
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                                Layout.preferredWidth: 50
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }

                // ============================================================
                // 播放
                // ============================================================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 130
                    radius: Theme.radiusLarge
                    color: Theme.panel

                    ColumnLayout {
                        anchors { fill: parent; margins: 20 }
                        spacing: 14

                        Text {
                            text: "播放"
                            color: Theme.accent
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(14); bold: true }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "歌词显示翻译"
                                color: Theme.text
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                Layout.fillWidth: true
                            }
                            Switch {
                                checked: appSettings.translateLyric
                                onToggled: appSettings.translateLyric = checked
                            }
                        }
                    }
                }

                // ============================================================
                // ★ 关于 / 检查更新（放在存储卡片之前，更容易找到）
                // ============================================================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160
                    radius: Theme.radiusLarge
                    color: Theme.panel

                    ColumnLayout {
                        anchors { fill: parent; margins: 20 }
                        spacing: 14

                        Text {
                            text: "关于"
                            color: Theme.accent
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(14); bold: true }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: "当前版本"
                                color: Theme.text
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                Layout.fillWidth: true
                            }

                            Text {
                                text: appSettings.currentVersion()
                                color: Theme.textDim
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                            }

                            // ★ 检查更新按钮
                            Rectangle {
                                Layout.preferredWidth: 110
                                Layout.preferredHeight: 32
                                radius: 16
                                color: checkUpdateBtn.containsMouse && root.updateStatus !== "checking"
                                       ? Theme.accentHover : Theme.accent
                                opacity: root.updateStatus === "checking" ? 0.5 : 1.0
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: root.updateStatus === "checking"
                                          ? "检查中..."
                                          : "检查更新"
                                    color: Theme.darkMode ? "#000000" : "#ffffff"
                                    font {
                                        family: Theme.fontFamily
                                        pixelSize: Theme.fs(12)
                                        bold: true
                                    }
                                }

                                MouseArea {
                                    id: checkUpdateBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: root.updateStatus !== "checking"
                                    onClicked: {
                                        root.updateStatus = "checking"
                                        root.updateMessage = "正在检查..."
                                        appSettings.checkForUpdates()
                                    }
                                }
                            }
                        }

                        // 更新结果提示
                        Text {
                            Layout.fillWidth: true
                            visible: root.updateStatus !== "idle"
                            text: root.updateMessage
                            color: {
                                if (root.updateStatus === "available") return Theme.accent
                                if (root.updateStatus === "failed") return Theme.danger
                                if (root.updateStatus === "notAvailable") return Theme.textMuted
                                return Theme.textDim
                            }
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                            wrapMode: Text.WordWrap
                        }

                        // 下载新版按钮
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: 17
                            visible: root.updateStatus === "available" && root.updateUrl !== ""
                            color: downloadBtn.containsMouse ? Theme.accentHover : Theme.accent
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                anchors.centerIn: parent
                                text: "前往下载 " + root.updateVersion
                                color: Theme.darkMode ? "#000000" : "#ffffff"
                                font {
                                    family: Theme.fontFamily
                                    pixelSize: Theme.fs(12)
                                    bold: true
                                }
                            }

                            MouseArea {
                                id: downloadBtn
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: appSettings.openUrl(root.updateUrl)
                            }
                        }
                    }
                }

                // ============================================================
                // 关闭设置
                // ============================================================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 170
                    radius: Theme.radiusLarge
                    color: Theme.panel

                    ColumnLayout {
                        anchors { fill: parent; margins: 20 }
                        spacing: 12

                        Text {
                            text: "关闭设置"
                            color: Theme.accent
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(14); bold: true }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32

                            RowLayout {
                                anchors.fill: parent
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18
                                    radius: 9
                                    color: "transparent"
                                    border.color: appSettings.closeBehavior === "tray"
                                                  ? Theme.accent : Theme.border
                                    border.width: 2

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 8; height: 8; radius: 4
                                        color: Theme.accent
                                        visible: appSettings.closeBehavior === "tray"
                                    }
                                }

                                Text {
                                    text: "最小到托盘"
                                    color: Theme.text
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: appSettings.closeBehavior = "tray"
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32

                            RowLayout {
                                anchors.fill: parent
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18
                                    radius: 9
                                    color: "transparent"
                                    border.color: appSettings.closeBehavior === "quit"
                                                  ? Theme.accent : Theme.border
                                    border.width: 2

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 8; height: 8; radius: 4
                                        color: Theme.accent
                                        visible: appSettings.closeBehavior === "quit"
                                    }
                                }

                                Text {
                                    text: "关闭启动器"
                                    color: Theme.text
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: appSettings.closeBehavior = "quit"
                            }
                        }

                        Text {
                            text: "关闭主窗口时执行的操作"
                            color: Theme.textMuted
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                        }
                    }
                }

                // ============================================================
                // 下载
                // ============================================================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 130
                    radius: Theme.radiusLarge
                    color: Theme.panel

                    ColumnLayout {
                        anchors { fill: parent; margins: 20 }
                        spacing: 14

                        Text {
                            text: "下载"
                            color: Theme.accent
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(14); bold: true }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: "保存目录"
                                color: Theme.text
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                Layout.preferredWidth: 80
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                radius: Theme.radius
                                color: Theme.bgAlt
                                border.color: pathInput.activeFocus ? Theme.accent : Theme.border
                                border.width: 1
                                clip: true
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                    verticalAlignment: Text.AlignVCenter
                                    text: appSettings.downloadPath
                                    color: Theme.text
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                                    elide: Text.ElideMiddle
                                    visible: !pathInput.activeFocus

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            pathInput.text = appSettings.downloadPath
                                            pathInput.forceActiveFocus()
                                            pathInput.cursorPosition = pathInput.text.length
                                        }
                                    }
                                }

                                TextInput {
                                    id: pathInput
                                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Theme.text
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                                    selectByMouse: true
                                    clip: true
                                    visible: activeFocus
                                    onEditingFinished: {
                                        if (text.trim() !== "") appSettings.downloadPath = text.trim()
                                    }
                                    Keys.onEscapePressed: focus = false
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 34
                                radius: Theme.radius
                                color: browseBtn.containsMouse ? Theme.accentHover : Theme.accent
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "浏览..."
                                    color: Theme.darkMode ? "#000000" : "#ffffff"
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                                }

                                MouseArea {
                                    id: browseBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        let picked = appSettings.pickFolder(
                                            "选择下载目录",
                                            appSettings.downloadPath
                                        )
                                        if (picked !== "") appSettings.downloadPath = picked
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 130
                                Layout.preferredHeight: 34
                                radius: Theme.radius
                                color: openDlBtn.containsMouse ? Theme.hover : "transparent"
                                border.color: Theme.border
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "打开文件夹"
                                    color: Theme.text
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                                }

                                MouseArea {
                                    id: openDlBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: appSettings.openDownloadFolder()
                                }
                            }
                        }
                    }
                }

                // ============================================================
                // 存储
                // ============================================================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 290
                    radius: Theme.radiusLarge
                    color: Theme.panel

                    ColumnLayout {
                        anchors { fill: parent; margins: 20 }
                        spacing: 14

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "存储"
                                color: Theme.accent
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(14); bold: true }
                                Layout.fillWidth: true
                            }
                            Text {
                                text: "总计 " + root.formatSize(audioCacheSizeMB + httpCacheSizeMB)
                                color: Theme.textDim
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                            }
                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: 13
                                color: refreshSizeBtn.containsMouse ? Theme.hover : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "⟳"
                                    color: refreshSizeBtn.containsMouse ? Theme.accent : Theme.textDim
                                    font.pixelSize: Theme.fs(14)
                                }

                                MouseArea {
                                    id: refreshSizeBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !root.clearing
                                    onClicked: root.refreshCacheSizes()
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "音频缓存"
                                    color: Theme.text
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                }
                                Text {
                                    text: "已下载到本地的歌曲文件，清空后需重新下载"
                                    color: Theme.textMuted
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Text {
                                text: root.formatSize(root.audioCacheSizeMB)
                                color: Theme.textDim
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                                Layout.preferredWidth: 90
                                horizontalAlignment: Text.AlignRight
                            }

                            Rectangle {
                                Layout.preferredWidth: 72
                                Layout.preferredHeight: 30
                                radius: 15
                                color: audioClearBtn.containsMouse && !root.clearing
                                       ? "#33e81123" : "transparent"
                                border.color: audioClearBtn.containsMouse && !root.clearing
                                              ? "transparent" : Theme.border
                                border.width: audioClearBtn.containsMouse && !root.clearing ? 0 : 1
                                opacity: root.clearing ? 0.4 : 1.0
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "清空"
                                    color: "#e81123"
                                    font {
                                        family: Theme.fontFamily
                                        pixelSize: Theme.fs(12)
                                        bold: audioClearBtn.containsMouse && !root.clearing
                                    }
                                }

                                MouseArea {
                                    id: audioClearBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !root.clearing
                                    onClicked: confirmDialog.openFor("audio")
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

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "图片 / 歌词缓存"
                                    color: Theme.text
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                }
                                Text {
                                    text: "专辑封面、歌词、API 响应"
                                    color: Theme.textMuted
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Text {
                                text: root.formatSize(root.httpCacheSizeMB)
                                color: Theme.textDim
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                                Layout.preferredWidth: 90
                                horizontalAlignment: Text.AlignRight
                            }

                            Rectangle {
                                Layout.preferredWidth: 72
                                Layout.preferredHeight: 30
                                radius: 15
                                color: httpClearBtn.containsMouse && !root.clearing
                                       ? "#33e81123" : "transparent"
                                border.color: httpClearBtn.containsMouse && !root.clearing
                                              ? "transparent" : Theme.border
                                border.width: httpClearBtn.containsMouse && !root.clearing ? 0 : 1
                                opacity: root.clearing ? 0.4 : 1.0
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "清空"
                                    color: "#e81123"
                                    font {
                                        family: Theme.fontFamily
                                        pixelSize: Theme.fs(12)
                                        bold: httpClearBtn.containsMouse && !root.clearing
                                    }
                                }

                                MouseArea {
                                    id: httpClearBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !root.clearing
                                    onClicked: confirmDialog.openFor("http")
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

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: "清空全部缓存"
                                color: Theme.text
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 32
                                radius: 16
                                color: openLogBtn.containsMouse ? Theme.hover : "transparent"
                                border.color: Theme.border
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "打开日志"
                                    color: Theme.text
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                                }

                                MouseArea {
                                    id: openLogBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: appSettings.openLogFolder()
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 32
                                radius: 16
                                color: root.clearing
                                       ? (Theme.darkMode ? "#442222" : "#ffdddd")
                                       : (allClearBtn.containsMouse ? "#cc0e1a" : "#e81123")
                                opacity: root.clearing ? 0.5 : 1.0
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: root.clearing ? "清空中..." : "清空全部"
                                    color: "#ffffff"
                                    font {
                                        family: Theme.fontFamily
                                        pixelSize: Theme.fs(12)
                                        bold: true
                                    }
                                }

                                MouseArea {
                                    id: allClearBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !root.clearing
                                    onClicked: confirmDialog.openFor("all")
                                }
                            }
                        }
                    }
                }

                // ============================================================
                // 应用
                // ============================================================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 130
                    radius: Theme.radiusLarge
                    color: Theme.panel

                    ColumnLayout {
                        anchors { fill: parent; margins: 20 }
                        spacing: 14

                        Text {
                            text: "应用"
                            color: Theme.accent
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(14); bold: true }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                radius: 18
                                color: minimizeBtn.containsMouse ? Theme.hover : "transparent"
                                border.color: Theme.border
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "隐藏到托盘"
                                    color: Theme.text
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                                }

                                MouseArea {
                                    id: minimizeBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.requestHideToTray()
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                radius: 18
                                color: restartBtn.containsMouse ? Theme.accentHover : Theme.accent
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "重启应用"
                                    color: Theme.darkMode ? "#000000" : "#ffffff"
                                    font {
                                        family: Theme.fontFamily
                                        pixelSize: Theme.fs(12)
                                        bold: true
                                    }
                                }

                                MouseArea {
                                    id: restartBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.requestRestart()
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                radius: 18
                                color: quitBtn.containsMouse ? "#cc0e1a" : "#e81123"
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "关闭应用"
                                    color: "#ffffff"
                                    font {
                                        family: Theme.fontFamily
                                        pixelSize: Theme.fs(12)
                                        bold: true
                                    }
                                }

                                MouseArea {
                                    id: quitBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.requestQuit()
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    // 确认清空弹窗
    Item {
        id: confirmDialog
        parent: Overlay.overlay
        anchors.fill: parent
        visible: opacity > 0.01
        opacity: 0
        z: 1000

        property string target: ""
        property string titleText: ""
        property string bodyText: ""

        function openFor(t) {
            target = t
            if (t === "audio") {
                titleText = "清空音频缓存"
                bodyText = "将删除所有已下载的本地音频文件（" +
                           root.formatSize(root.audioCacheSizeMB) +
                           "）。下次播放时需要重新下载。"
            } else if (t === "http") {
                titleText = "清空图片 / 歌词缓存"
                bodyText = "将删除所有缓存的专辑封面、歌词和 API 响应（" +
                           root.formatSize(root.httpCacheSizeMB) +
                           "）。下次浏览时需要重新加载。"
            } else {
                titleText = "清空全部缓存"
                bodyText = "将删除音频、封面、歌词、API 响应等全部缓存（" +
                           root.formatSize(root.audioCacheSizeMB + root.httpCacheSizeMB) +
                           "）。所有内容需重新下载。"
            }
            opacity = 1
        }
        function close() { opacity = 0 }

        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.5
            MouseArea { anchors.fill: parent; onClicked: confirmDialog.close() }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 420
            height: 200
            radius: Theme.radiusLarge
            color: Theme.panel
            border.color: Theme.border
            border.width: 1

            scale: confirmDialog.opacity > 0.5 ? 1.0 : 0.85
            Behavior on scale {
                NumberAnimation { duration: 260; easing.type: Easing.OutBack }
            }

            ColumnLayout {
                anchors { fill: parent; margins: 24 }
                spacing: 16

                Text {
                    text: confirmDialog.titleText
                    color: "#e81123"
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(16); bold: true }
                }

                Text {
                    text: confirmDialog.bodyText
                    color: Theme.text
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 32
                        radius: 16
                        color: cancelBtn.containsMouse ? Theme.hover : "transparent"
                        border.color: Theme.border
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "取消"
                            color: Theme.text
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                        }

                        MouseArea {
                            id: cancelBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: confirmDialog.close()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 32
                        radius: 16
                        color: confirmBtn.containsMouse ? "#cc0e1a" : "#e81123"

                        Text {
                            anchors.centerIn: parent
                            text: "确认清空"
                            color: "#ffffff"
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                        }

                        MouseArea {
                            id: confirmBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                var t = confirmDialog.target
                                confirmDialog.close()
                                root.clearing = true

                                if (t === "audio") {
                                    audioCache.clearAll()
                                } else if (t === "http") {
                                    networkManager.clearHttpCache()
                                } else {
                                    audioCache.clearAll()
                                    networkManager.clearHttpCache()
                                }

                                refreshTimer.restart()
                                clearingResetTimer.restart()
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 300
        onTriggered: root.refreshCacheSizes()
    }

    Timer {
        id: clearingResetTimer
        interval: 600
        onTriggered: root.clearing = false
    }
}