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

    property string updateStatus: "idle"
    property string updateMessage: ""
    property string updateUrl: ""
    property string updateVersion: ""

    readonly property string repoUrl: "https://github.com/Cudny10D/Mass"

    // 简单 toast
    property string toastMsg: ""

    property var backgrounds: []

    function showToast(msg) {
        root.toastMsg = msg
        toast.opacity = 1
        toastTimer.restart()
    }

    // 外部直接切到某个分类（顶部搜索、快捷入口、截图核对用）
    function openCategory(key) {
        if (key !== "") settingsPageRoot.category = key
    }

    function refreshCacheSizes() {
        audioCacheSizeMB = audioCache.totalSize() / 1024 / 1024
        httpCacheSizeMB = networkManager.httpCacheSize() / 1024 / 1024
    }

    function formatSize(mb) {
        if (mb >= 1024) return (mb / 1024).toFixed(2) + " GB"
        if (mb < 0.1) return "0 MB"
        return mb.toFixed(1) + " MB"
    }

    function refreshBackgrounds() {
        backgrounds = [{ url: "", name: "默认" }]
                       .concat(appSettings.getBackgrounds())
    }

    Component.onCompleted: {
        refreshCacheSizes()
        refreshBackgrounds()
    }

    onVisibleChanged: if (visible) refreshBackgrounds()

    Connections {
        target: appSettings
        function onUpdateAvailable(version, url, notes) {
            root.updateStatus = "available"
            root.updateVersion = version
            root.updateUrl = url
            root.updateMessage = "发现新版本 " + version
            if (notes !== "") root.updateMessage += " ｜ " + notes
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

    // ============================================================
    // 内联组件：可展开的后端选择器
    // ============================================================
    component ExpandableBackend: ColumnLayout {
        id: backendRoot

        property string label: ""
        property bool selected: false
        property bool available: true
        property bool hasConfig: true
        property bool expanded: false

        signal picked()

        default property alias expandContent: expandColumn.data

        Layout.fillWidth: true
        spacing: 0
        opacity: backendRoot.available ? 1.0 : 0.4
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 34

            RowLayout {
                anchors.fill: parent
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    radius: 0
                    color: "transparent"
                    border.color: backendRoot.selected ? Theme.accent : Theme.border
                    border.width: 2
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 8; height: 8; radius: 0
                        color: Theme.accent
                        visible: backendRoot.selected
                        scale: backendRoot.selected ? 1.0 : 0.0
                        Behavior on scale {
                            NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                        }
                    }
                }

                Text {
                    text: backendRoot.label
                    color: backendRoot.available ? Theme.text : Theme.textMuted
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Rectangle {
                    visible: backendRoot.hasConfig && backendRoot.available
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 0
                    color: gearHover.containsMouse || backendRoot.expanded
                           ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "⚙"
                        color: backendRoot.expanded ? Theme.accent : Theme.textDim
                        font.pixelSize: Theme.fs(14)
                        rotation: backendRoot.expanded ? 90 : 0
                        Behavior on rotation {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: gearHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: backendRoot.expanded = !backendRoot.expanded
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.rightMargin: backendRoot.hasConfig ? 32 : 0
                enabled: backendRoot.available
                onClicked: backendRoot.picked()
            }
        }

        Item {
            id: expandWrapper
            Layout.fillWidth: true
            Layout.leftMargin: 28
            Layout.topMargin: backendRoot.expanded ? 4 : 0
            Layout.bottomMargin: backendRoot.expanded ? 8 : 0
            Layout.preferredHeight: backendRoot.expanded
                                    ? expandColumn.implicitHeight + 12
                                    : 0
            clip: true
            Behavior on Layout.preferredHeight {
                NumberAnimation {
                    duration: 280
                    easing.type: Easing.OutCubic
                }
            }

            ColumnLayout {
                id: expandColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 8
            }
        }
    }

    // ============================================================
    // 内联组件：凭据输入行
    // ============================================================
    component CredentialRow: Item {
        id: credRoot

        property string label: ""
        property string placeholder: ""
        property string displayValue: ""
        property bool passwordMode: false

        signal saveRequested(string newValue)

        Layout.fillWidth: true
        implicitHeight: 34

        RowLayout {
            anchors.fill: parent
            spacing: 10

            Text {
                text: credRoot.label
                color: Theme.textDim
                font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                Layout.preferredWidth: 56
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: Theme.radius
                color: Theme.bgAlt
                border.color: inputField.activeFocus ? Theme.accent : Theme.border
                border.width: 1
                clip: true
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Text {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: Text.AlignVCenter
                    text: credRoot.displayValue !== ""
                          ? credRoot.displayValue
                          : credRoot.placeholder
                    color: credRoot.displayValue !== ""
                           ? Theme.text
                           : Theme.textMuted
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                    elide: Text.ElideMiddle
                    visible: !inputField.activeFocus

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            inputField.text = ""
                            inputField.forceActiveFocus()
                        }
                    }
                }

                TextInput {
                    id: inputField
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                    selectByMouse: true
                    clip: true
                    visible: activeFocus
                    echoMode: credRoot.passwordMode ? TextInput.Password
                                                    : TextInput.Normal
                    onAccepted: commit()
                    Keys.onEscapePressed: focus = false

                    function commit() {
                        if (text.trim() !== "") {
                            credRoot.saveRequested(text.trim())
                            text = ""
                            focus = false
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 60
                Layout.preferredHeight: 34
                radius: Theme.radius
                color: saveBtn.containsMouse ? Theme.accentHover : Theme.accent
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text: "保存"
                    color: Theme.ink
                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                }

                MouseArea {
                    id: saveBtn
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: inputField.commit()
                }
            }
        }
    }


    // 主题化滑块：默认外观不跟随 Theme，这里统一接管手柄与轨道配色
    component GlassSlider: Slider {
        id: ctrl
        implicitWidth: 180
        implicitHeight: 22

        handle: Rectangle {
            x: ctrl.leftPadding + ctrl.visualPosition * (ctrl.availableWidth - width)
            y: ctrl.topPadding + (ctrl.availableHeight - height) / 2
            width: 6
            height: 18
            radius: 0
            color: ctrl.pressed || ctrl.hovered ? Theme.accentHover : Theme.text
            antialiasing: false
        }

        background: Rectangle {
            x: ctrl.leftPadding
            y: ctrl.topPadding + (ctrl.availableHeight - height) / 2
            width: ctrl.availableWidth
            height: 2
            radius: 0
            color: Theme.borderLight
            antialiasing: false

            Rectangle {
                width: ctrl.visualPosition * parent.width
                height: parent.height
                radius: 0
                color: Theme.accent
                antialiasing: false
            }
        }
    }

    // 主题色取色条：轨道本身是渐变，手柄沿用同款细竖线
    component ColorBar: Slider {
        id: bar
        property var stops: []

        implicitWidth: 200
        implicitHeight: 22

        handle: Rectangle {
            x: bar.leftPadding + bar.visualPosition * (bar.availableWidth - width)
            y: bar.topPadding + (bar.availableHeight - height) / 2
            width: 4
            height: 18
            radius: 0
            color: bar.pressed || bar.hovered ? Theme.textBright : Theme.text
            antialiasing: false
        }

        background: Canvas {
            id: barCanvas
            x: bar.leftPadding
            y: bar.topPadding + (bar.availableHeight - height) / 2
            width: bar.availableWidth
            height: 10

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var g = ctx.createLinearGradient(0, 0, width, 0)
                for (var i = 0; i < bar.stops.length; ++i)
                    g.addColorStop(bar.stops[i].pos, bar.stops[i].color)
                ctx.fillStyle = g
                ctx.fillRect(0, 0, width, height)
                ctx.strokeStyle = Theme.border
                ctx.lineWidth = 1
                ctx.strokeRect(0.5, 0.5, width - 1, height - 1)
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        onStopsChanged: barCanvas.requestPaint()
    }

    // ============================================================
    // 页面
    // ============================================================
    Rectangle {
        id: settingsPageRoot
        property string category: "appearance"
        anchors.fill: parent
        color: "transparent"

        // ============================================================
        // 左侧分类导航
        // ============================================================
        Column {
            z: 10
            anchors {
                top: parent.top
                left: parent.left
                topMargin: 26
                leftMargin: Theme.contentSideMargin
            }
            width: 150
            spacing: 2

            Text {
                text: "SETTINGS / 设置"
                color: Theme.textMuted
                font {
                    family: Theme.monoFamily
                    pixelSize: Theme.microSize
                    letterSpacing: 1.8
                }
                leftPadding: 12
                bottomPadding: 10
            }

            Repeater {
                model: [
                    { key: "appearance", label: "外观" },
                    { key: "playback",   label: "播放" },
                    { key: "translate",  label: "翻译" },
                    { key: "download",   label: "下载" },
                    { key: "storage",    label: "存储" },
                    { key: "about",      label: "关于" }
                ]
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: 150
                    height: 30

                    property bool active: settingsPageRoot.category === modelData.key

                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 2
                        color: Theme.accent
                        opacity: parent.active ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    Text {
                        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                        text: "0" + (index + 1)
                        color: Theme.textMuted
                        font {
                            family: Theme.monoFamily
                            pixelSize: Theme.microSize
                            letterSpacing: 1
                        }
                    }

                    Text {
                        anchors { left: parent.left; leftMargin: 40; verticalCenter: parent.verticalCenter }
                        text: modelData.label
                        color: parent.active ? Theme.text
                                             : (navMouse.containsMouse ? Theme.text : Theme.textDim)
                        font {
                            family: Theme.fontFamily
                            pixelSize: Theme.fs(13)
                            weight: parent.active ? Font.DemiBold : Font.Normal
                        }
                    }

                    MouseArea {
                        id: navMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsPageRoot.category = modelData.key
                    }
                }
            }
        }

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
                    topMargin: 20
                    leftMargin: Theme.contentSideMargin + 170
                    rightMargin: Theme.contentSideMargin
                }
                spacing: 20

                // ============================================================
                // 顶部栏
                // ============================================================

                // ============================================================
                // 外观
                // ============================================================
                Rectangle {
                    visible: settingsPageRoot.category === "appearance"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Layout.fillWidth: true
                    Layout.preferredHeight: 300
                    radius: 0
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
                                text: "主题"
                                color: Theme.text
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                spacing: 6

                                Repeater {
                                    model: [
                                        { mode: "system", label: "跟随系统" },
                                        { mode: "light",  label: "亮色" },
                                        { mode: "dark",   label: "暗色" }
                                    ]
                                    delegate: Rectangle {
                                        required property var modelData

                                        width: labelText.implicitWidth + 24
                                        height: 28
                                        radius: 0
                                        antialiasing: true
                                        border.width: 1
                                        color: appSettings.themeMode === modelData.mode
                                               ? Theme.active
                                               : (modeMouse.containsMouse ? Theme.hover : "transparent")
                                        border.color: appSettings.themeMode === modelData.mode
                                                      ? Theme.accent : Theme.border

                                        Text {
                                            id: labelText
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: appSettings.themeMode === modelData.mode
                                                   ? Theme.textBright : Theme.textDim
                                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                                        }

                                        MouseArea {
                                            id: modeMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: appSettings.themeMode = modelData.mode
                                        }
                                    }
                                }
                            }
                        }



                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "播放条隐藏触发高度"
                                color: Theme.text
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                Layout.fillWidth: true
                            }
                            GlassSlider {
                                Layout.preferredWidth: 180
                                from: 40
                                to: 320
                                value: appSettings.playerTriggerHeight
                                onMoved: appSettings.playerTriggerHeight = value
                            }
                            Rectangle {
                                    Layout.preferredWidth: 42
                                    Layout.preferredHeight: 22
                                    radius: 0
                                    color: reset_playerTriggerHeight.containsMouse ? Theme.hover : "transparent"
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "RESET"
                                        color: Theme.textMuted
                                        font {
                                            family: Theme.monoFamily
                                            pixelSize: Theme.microSize
                                            letterSpacing: 0.8
                                        }
                                    }

                                    MouseArea {
                                        id: reset_playerTriggerHeight
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: appSettings.playerTriggerHeight = 160
                                    }
                            }
                            Text {
                                Layout.preferredWidth: 52
                                horizontalAlignment: Text.AlignRight
                                text: appSettings.playerTriggerHeight + " px"
                                color: Theme.textDim
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
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

                            GlassSlider {
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
                                    width: 6
                                    height: 18
                                    radius: 0
                                    color: parent.pressed ? Theme.accentHover : Theme.text
                                    z: 1
                                    antialiasing: false
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
                // 主题色
                // ============================================================
                Rectangle {
                    id: accentCard
                    visible: settingsPageRoot.category === "appearance"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Layout.fillWidth: true
                    Layout.preferredHeight: 224
                    radius: 0
                    color: Theme.panel

                    // 取色器的本地状态：拖动时以本地值为准，
                    // 不直接回读颜色，免得 8bit 量化把手柄拽回去。
                    property real hue: 120
                    property real sat: 0.24
                    property real lum: 0.38
                    property color probe: "#6E744C"

                    readonly property var presets: [
                        { hex: "#6E744C" },   // 橄榄（默认）
                        { hex: "#3F5B86" },   // 靛蓝
                        { hex: "#2F6A5A" },   // 松绿
                        { hex: "#8A4534" },   // 赭红
                        { hex: "#6B4A78" },   // 紫檀
                        { hex: "#8A6A2A" },   // 琥珀
                        { hex: "#8A3A5E" },   // 品红
                        { hex: "#4A4B46" }    // 石墨
                    ]

                    function currentAccent() {
                        return appSettings.accentColor !== ""
                                ? appSettings.accentColor
                                : Theme.accentDefault.toString()
                    }
                    function refresh() {
                        probe = currentAccent()
                        hue = Math.max(0, Math.min(1, probe.hslHue)) * 360
                        sat = probe.hslSaturation
                        lum = probe.hslLightness
                        hueBar.value = hue
                        satBar.value = sat * 100
                        lumBar.value = lum * 100
                        if (!hexField.activeFocus)
                            hexField.text = currentAccent().toUpperCase()
                    }
                    function applyHsl() {
                        const hex = Qt.hsla(hue / 360, sat, lum, 1)
                                        .toString().toUpperCase()
                        appSettings.accentColor = hex
                        if (!hexField.activeFocus) hexField.text = hex
                    }
                    function applyHex(raw) {
                        var t = String(raw).trim().replace(/^#/, "")
                        if (t.length === 3)
                            t = t[0] + t[0] + t[1] + t[1] + t[2] + t[2]
                        if (!/^[0-9a-fA-F]{6}$/.test(t)) { refresh(); return }
                        appSettings.accentColor = "#" + t.toUpperCase()
                        refresh()
                    }
                    function isActive(hex) {
                        return currentAccent().toUpperCase() === hex
                    }
                    function reset() {
                        appSettings.accentColor = ""
                        refresh()
                    }

                    Component.onCompleted: refresh()

                    ColumnLayout {
                        anchors { fill: parent; margins: 20 }
                        spacing: 14

                        // —— 标题 + 当前值 + 手输 HEX + 恢复默认
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                Layout.fillWidth: true
                                text: "主题色"
                                color: Theme.accent
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(14); bold: true }
                            }

                            Text {
                                text: "ACCENT"
                                color: Theme.textMuted
                                font {
                                    family: Theme.monoFamily
                                    pixelSize: Theme.microSize
                                    letterSpacing: 1.4
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: 0
                                antialiasing: true
                                color: Theme.accent
                                border.width: 1
                                border.color: Theme.border
                            }

                            TextField {
                                id: hexField
                                Layout.preferredWidth: 92
                                Layout.preferredHeight: 26
                                leftPadding: 8
                                rightPadding: 8
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.text
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.ink
                                font {
                                    family: Theme.monoFamily
                                    pixelSize: Theme.microSize + 1
                                    letterSpacing: 0.6
                                }
                                background: Rectangle {
                                    radius: 0
                                    color: "transparent"
                                    border.width: 1
                                    border.color: hexField.activeFocus ? Theme.accent : Theme.border
                                }
                                onEditingFinished: accentCard.applyHex(text)
                            }

                            Rectangle {
                                Layout.preferredWidth: 52
                                Layout.preferredHeight: 26
                                radius: 0
                                color: resetAccent.containsMouse ? Theme.hover : "transparent"
                                border.width: 1
                                border.color: Theme.border
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "RESET"
                                    color: Theme.textDim
                                    font {
                                        family: Theme.monoFamily
                                        pixelSize: Theme.microSize
                                        letterSpacing: 0.8
                                    }
                                }

                                MouseArea {
                                    id: resetAccent
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: accentCard.reset()
                                }
                            }
                        }

                        // —— 预设色板
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                Layout.preferredWidth: 68
                                text: "预设"
                                color: Theme.text
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                            }

                            Repeater {
                                model: accentCard.presets
                                delegate: Item {
                                    required property var modelData
                                    implicitWidth: 30
                                    implicitHeight: 30

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 0
                                        antialiasing: true
                                        color: modelData.hex
                                        border.width: 1
                                        border.color: Theme.border
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        radius: 0
                                        color: "transparent"
                                        border.width: 1
                                        border.color: Theme.text
                                        visible: accentCard.isActive(modelData.hex)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            appSettings.accentColor = modelData.hex
                                            accentCard.refresh()
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        // —— 色相
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                Layout.preferredWidth: 68
                                text: "色相"
                                color: Theme.textDim
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                            }

                            ColorBar {
                                id: hueBar
                                Layout.fillWidth: true
                                Layout.preferredHeight: 22
                                from: 0; to: 360; stepSize: 1
                                stops: [
                                    { pos: 0.00, color: "#C0392B" },
                                    { pos: 0.17, color: "#C9A227" },
                                    { pos: 0.33, color: "#5E8A3A" },
                                    { pos: 0.50, color: "#2F7E72" },
                                    { pos: 0.67, color: "#3A5E9A" },
                                    { pos: 0.83, color: "#6B4A8A" },
                                    { pos: 1.00, color: "#C0392B" }
                                ]
                                onMoved: {
                                    accentCard.hue = value
                                    accentCard.applyHsl()
                                }
                            }

                            Text {
                                Layout.preferredWidth: 46
                                horizontalAlignment: Text.AlignRight
                                text: Math.round(accentCard.hue) + "°"
                                color: Theme.textDim
                                font {
                                    family: Theme.monoFamily
                                    pixelSize: Theme.microSize + 1
                                }
                            }
                        }

                        // —— 饱和度
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                Layout.preferredWidth: 68
                                text: "饱和度"
                                color: Theme.textDim
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                            }

                            ColorBar {
                                id: satBar
                                Layout.fillWidth: true
                                Layout.preferredHeight: 22
                                from: 0; to: 100; stepSize: 1
                                stops: [
                                    { pos: 0, color: Qt.hsla(accentCard.hue / 360, 0,
                                                             accentCard.lum, 1).toString() },
                                    { pos: 1, color: Qt.hsla(accentCard.hue / 360, 1,
                                                             accentCard.lum, 1).toString() }
                                ]
                                onMoved: {
                                    accentCard.sat = value / 100
                                    accentCard.applyHsl()
                                }
                            }

                            Text {
                                Layout.preferredWidth: 46
                                horizontalAlignment: Text.AlignRight
                                text: Math.round(accentCard.sat * 100) + "%"
                                color: Theme.textDim
                                font {
                                    family: Theme.monoFamily
                                    pixelSize: Theme.microSize + 1
                                }
                            }
                        }

                        // —— 明度
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                Layout.preferredWidth: 68
                                text: "明度"
                                color: Theme.textDim
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                            }

                            ColorBar {
                                id: lumBar
                                Layout.fillWidth: true
                                Layout.preferredHeight: 22
                                from: 18; to: 62; stepSize: 1
                                stops: [
                                    { pos: 0.0, color: "#000000" },
                                    { pos: 0.5, color: Qt.hsla(accentCard.hue / 360,
                                                               accentCard.sat, 0.5, 1).toString() },
                                    { pos: 1.0, color: "#FFFFFF" }
                                ]
                                onMoved: {
                                    accentCard.lum = value / 100
                                    accentCard.applyHsl()
                                }
                            }

                            Text {
                                Layout.preferredWidth: 46
                                horizontalAlignment: Text.AlignRight
                                text: Math.round(accentCard.lum * 100) + "%"
                                color: Theme.textDim
                                font {
                                    family: Theme.monoFamily
                                    pixelSize: Theme.microSize + 1
                                }
                            }
                        }
                    }
                }

                // ============================================================
                // 自定义背景
                // ============================================================
                Rectangle {
                    visible: settingsPageRoot.category === "appearance"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Layout.fillWidth: true
                    Layout.preferredHeight: 244
                    radius: 0
                    color: Theme.panel

                    ColumnLayout {
                        anchors { fill: parent; margins: 20 }
                        spacing: 14

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "自定义背景"
                                color: Theme.accent
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(14); bold: true }
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                width: 118; height: 28; radius: 0
                                color: bgFolderBtn.containsMouse ? Theme.hover : Theme.panelAlt
                                antialiasing: true
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "打开背景文件夹"
                                    color: Theme.text
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                                }

                                MouseArea {
                                    id: bgFolderBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: appSettings.openBackgroundsFolder()
                                }
                            }

                            Rectangle {
                                width: 56; height: 28; radius: 0
                                color: bgRefreshBtn.containsMouse ? Theme.hover : Theme.panelAlt
                                antialiasing: true
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "刷新"
                                    color: Theme.text
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                                }

                                MouseArea {
                                    id: bgRefreshBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.refreshBackgrounds()
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "图片放进 " + appSettings.backgroundsDir() + " 后自动识别"
                            color: Theme.textMuted
                            elide: Text.ElideMiddle
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(10) }
                        }

                        GridView {
                            id: bgGrid
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            cellWidth: 92
                            cellHeight: 74
                            model: root.backgrounds

                            delegate: Item {
                                width: bgGrid.cellWidth
                                height: bgGrid.cellHeight

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 84; height: 58
                                    radius: Theme.radius
                                    color: Theme.panelAlt
                                    clip: true
                                    border.width: 2
                                    border.color: appSettings.backgroundImage === modelData.url
                                                  ? Theme.accent : "transparent"
                                    antialiasing: true

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.url
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        visible: modelData.url !== ""
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: modelData.url === ""
                                        text: "默认"
                                        color: Theme.textDim
                                        font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: appSettings.backgroundImage = modelData.url
                                    }
                                }
                            }
                        }
                    }
                }

                // ============================================================
                // 播放 / 翻译
                // ============================================================
                Rectangle {
                    visible: settingsPageRoot.category === "translate"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Layout.fillWidth: true
                    Layout.preferredHeight: playTranslateCol.implicitHeight + 40
                    radius: 0
                    color: Theme.panel

                    ColumnLayout {
                        id: playTranslateCol
                        anchors { fill: parent; margins: 20 }
                        spacing: 14

                        Text {
                            text: "播放 / 翻译"
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
                            TechSwitch {
                                checked: appSettings.translateLyric
                                onClicked: appSettings.translateLyric = !appSettings.translateLyric
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "在线 API 翻译"
                                color: appSettings.translateLyric ? Theme.text : Theme.textMuted
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                Layout.fillWidth: true
                            }
                            TechSwitch {
                                checked: appSettings.apiTranslate
                                enabled: appSettings.translateLyric
                                onClicked: appSettings.apiTranslate = !appSettings.apiTranslate
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "桌面歌词（Ctrl+L）"
                                color: Theme.text
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                Layout.fillWidth: true
                            }
                            TechSwitch {
                                checked: appSettings.desktopLyricEnabled
                                onClicked: appSettings.desktopLyricEnabled = !appSettings.desktopLyricEnabled
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.borderLight
                            opacity: 0.6
                            enabled: false
                        }

                        Text {
                            text: "翻译后端"
                            color: Theme.textDim
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                        }

                        // MyMemory
                        ExpandableBackend {
                            label: "MyMemory（默认，无需配置）"
                            selected: !translationService.useDeepL
                            hasConfig: false
                            onPicked: {
                                translationService.useDeepL = false
                            }
                        }

                        // DeepL
                        ExpandableBackend {
                            label: "DeepL（官方，需 API Key）"
                            selected: translationService.useDeepL
                            onPicked: translationService.useDeepL = true

                            CredentialRow {
                                Layout.fillWidth: true
                                label: "Key"
                                placeholder: "粘贴 DeepL API Key（xxx:fx）"
                                displayValue: translationService.hasApiKey()
                                              ? "••••••••••••••••（已保存）"
                                              : ""
                                onSaveRequested: (v) => translationService.setApiKey(v)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "当前后端"
                                color: Theme.textDim
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                                Layout.preferredWidth: 80
                            }

                            Text {
                                text: translationService.activeBackendName()
                                color: translationService.activeBackendName().startsWith("MyMemory")
                                       ? Theme.textMuted
                                       : Theme.accent
                                font {
                                    family: Theme.fontFamily
                                    pixelSize: Theme.fs(12)
                                    bold: !translationService.activeBackendName().startsWith("MyMemory")
                                }
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                let lines = [
                                    "• MyMemory：免费，每日约 5,000 字符，逐行翻译",
                                    "• DeepL：每月 50 万字符免费额度，翻译质量顶尖"
                                ]
                                return lines.join("\n")
                            }
                            color: Theme.textMuted
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                            wrapMode: Text.WordWrap
                            lineHeight: 1.4
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: translationService.quotaExhausted
                            text: "⚠ DeepL 本月配额已耗尽，已自动切回 MyMemory。"
                            color: Theme.danger
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // ============================================================
                // 播放
                // ============================================================
                Rectangle {
                    visible: settingsPageRoot.category === "playback"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Layout.fillWidth: true
                    Layout.preferredHeight: playCol.implicitHeight + 40
                    radius: 0
                    color: Theme.panel

                    ColumnLayout {
                        id: playCol
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
                            text: "启动音量"
                            color: Theme.text
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                            Layout.fillWidth: true
                        }
                        GlassSlider {
                            Layout.preferredWidth: 180
                            from: 0.0
                            to: 1.0
                            value: appSettings.volumeDefault
                            onMoved: appSettings.volumeDefault = value
                        }
                        Rectangle {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 22
                                radius: 0
                                color: reset_volumeDefault.containsMouse ? Theme.hover : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "RESET"
                                    color: Theme.textDim
                                    font.pixelSize: Theme.fs(12)
                                }

                                MouseArea {
                                    id: reset_volumeDefault
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: appSettings.volumeDefault = 0.8
                                }
                        }
                        Text {
                            Layout.preferredWidth: 44
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(appSettings.volumeDefault * 100) + "%"
                            color: Theme.textDim
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "启动播放模式"
                            color: Theme.text
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                            Layout.fillWidth: true
                        }
                        ComboBox {
                            id: loopModeCombo
                            Layout.preferredWidth: 132
                            model: ["顺序播放", "单曲循环", "列表循环", "随机播放"]
                            currentIndex: appSettings.loopMode
                            onActivated: (i) => appSettings.loopMode = i

                            background: Rectangle {
                                radius: 0
                                color: Theme.panelAlt
                                border.width: 1
                                border.color: Theme.border
                            }

                            // 下拉菜单的进出场动画。
                            // Qt Quick Controls 的默认样式只有进场没有退场，
                            // 关闭时是「啪」地消失；这里补上淡出 + 轻微缩小。
                            popup.enter: Transition {
                                NumberAnimation {
                                    property: "opacity"
                                    from: 0; to: 1
                                    duration: 140
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: loopModeCombo.popup.contentItem
                                    property: "scale"
                                    from: 0.95; to: 1.0
                                    duration: 160
                                    easing.type: Easing.OutCubic
                                }
                            }
                            popup.exit: Transition {
                                NumberAnimation {
                                    property: "opacity"
                                    to: 0
                                    duration: 120
                                    easing.type: Easing.InCubic
                                }
                                NumberAnimation {
                                    target: loopModeCombo.popup.contentItem
                                    property: "scale"
                                    to: 0.96
                                    duration: 120
                                    easing.type: Easing.InCubic
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "拖动进度条实时跳转"
                            color: Theme.text
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                            Layout.fillWidth: true
                        }
                        TechSwitch {
                            checked: appSettings.seekPreview
                            onClicked: appSettings.seekPreview = !appSettings.seekPreview
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "切歌淡入"
                            color: Theme.text
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                            Layout.fillWidth: true
                        }
                        TechSwitch {
                            checked: appSettings.crossfade
                            onClicked: appSettings.crossfade = !appSettings.crossfade
                        }
                    }
                    }
                }

                // ============================================================
                // 关闭设置
                // ============================================================
                Rectangle {
                    visible: settingsPageRoot.category === "about"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Layout.fillWidth: true
                    Layout.preferredHeight: 290
                    radius: 0
                    color: Theme.panel

                    ColumnLayout {
                        anchors { fill: parent; margins: 20 }
                        spacing: 14

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
                                    radius: 0
                                    color: "transparent"
                                    border.color: appSettings.closeBehavior === "tray"
                                                  ? Theme.accent : Theme.border
                                    border.width: 2
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 8; height: 8; radius: 0
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
                                    radius: 0
                                    color: "transparent"
                                    border.color: appSettings.closeBehavior === "quit"
                                                  ? Theme.accent : Theme.border
                                    border.width: 2
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 8; height: 8; radius: 0
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
                    visible: settingsPageRoot.category === "download"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Layout.fillWidth: true
                    Layout.preferredHeight: 130
                    radius: 0
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
                                    color: Theme.ink
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                                }

                                MouseArea {
                                    id: browseBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        let picked = appSettings.pickFolder(
                                            "选择下载目录", appSettings.downloadPath)
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
                    visible: settingsPageRoot.category === "storage"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Layout.fillWidth: true
                    Layout.preferredHeight: storageCol.implicitHeight + 40
                    radius: 0
                    color: Theme.panel

                    ColumnLayout {
                        id: storageCol
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
                                radius: 0
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
                            Text {
                                text: "封面缓存上限"
                                color: Theme.text
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                Layout.fillWidth: true
                            }
                            GlassSlider {
                                Layout.preferredWidth: 200
                                from: 64
                                to: 2048
                                stepSize: 64
                                value: appSettings.imageCacheMb
                                onMoved: appSettings.imageCacheMb = value
                            }
                            Rectangle {
                                    Layout.preferredWidth: 42
                                    Layout.preferredHeight: 22
                                    radius: 0
                                    color: reset_imageCacheMb.containsMouse ? Theme.hover : "transparent"
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "RESET"
                                        color: Theme.textMuted
                                        font {
                                            family: Theme.monoFamily
                                            pixelSize: Theme.microSize
                                            letterSpacing: 0.8
                                        }
                                    }

                                    MouseArea {
                                        id: reset_imageCacheMb
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: appSettings.imageCacheMb = 256
                                    }
                            }
                            Text {
                                Layout.preferredWidth: 68
                                horizontalAlignment: Text.AlignRight
                                text: appSettings.imageCacheMb + " MB"
                                color: Theme.textDim
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "HTTP 缓存上限"
                                color: Theme.text
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                Layout.fillWidth: true
                            }
                            GlassSlider {
                                Layout.preferredWidth: 200
                                from: 32
                                to: 1024
                                stepSize: 32
                                value: appSettings.httpCacheMb
                                onMoved: appSettings.httpCacheMb = value
                            }
                            Rectangle {
                                    Layout.preferredWidth: 42
                                    Layout.preferredHeight: 22
                                    radius: 0
                                    color: reset_httpCacheMb.containsMouse ? Theme.hover : "transparent"
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "RESET"
                                        color: Theme.textMuted
                                        font {
                                            family: Theme.monoFamily
                                            pixelSize: Theme.microSize
                                            letterSpacing: 0.8
                                        }
                                    }

                                    MouseArea {
                                        id: reset_httpCacheMb
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: appSettings.httpCacheMb = 128
                                    }
                            }
                            Text {
                                Layout.preferredWidth: 68
                                horizontalAlignment: Text.AlignRight
                                text: appSettings.httpCacheMb + " MB"
                                color: Theme.textDim
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "预取下一首"
                                color: Theme.text
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                Layout.fillWidth: true
                            }
                            TechSwitch {
                                checked: appSettings.prefetchNext
                                onClicked: appSettings.prefetchNext = !appSettings.prefetchNext
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
                                radius: 0
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

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderLight; opacity: 0.6; enabled: false }

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
                                radius: 0
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

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderLight; opacity: 0.6; enabled: false }

                        // ★ 使用歌词包开关
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "使用已导入的歌词包"
                                    color: Theme.text
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                }
                                Text {
                                    text: "关闭后将忽略本地歌词包，改用在线翻译 API 重新翻译"
                                    color: Theme.textMuted
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            TechSwitch {
                                checked: translationService.useLyricsPack
                                onClicked: translationService.useLyricsPack = !translationService.useLyricsPack
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderLight; opacity: 0.6; enabled: false }

                        // ★ 歌词翻译包
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "歌词翻译包"
                                    color: Theme.text
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                }
                                Text {
                                    text: "已缓存 " + translationService.cacheCount +
                                          " 首翻译歌词，可导出分享或导入他人分享的包"
                                    color: Theme.textMuted
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(11) }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Text {
                                text: translationService.cacheCount + " 首"
                                color: Theme.textDim
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                                Layout.preferredWidth: 90
                                horizontalAlignment: Text.AlignRight
                            }

                            Rectangle {
                                Layout.preferredWidth: 72
                                Layout.preferredHeight: 30
                                radius: 0
                                color: exportLyricsBtn.containsMouse && translationService.cacheCount > 0
                                       ? Theme.accentHover : Theme.accent
                                opacity: translationService.cacheCount > 0 ? 1.0 : 0.4
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "导出"
                                    color: Theme.ink
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                                }

                                MouseArea {
                                    id: exportLyricsBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: translationService.cacheCount > 0
                                    onClicked: {
                                        let fname = "lyrics-pack-" +
                                            Qt.formatDate(new Date(), "yyyyMMdd") +
                                            ".json"
                                        let path = appSettings.pickSaveFile(
                                            "导出歌词包", fname)
                                        if (path === "") return
                                        if (translationService.exportCache(path)) {
                                            root.showToast("已导出 " +
                                                translationService.cacheCount +
                                                " 首歌词翻译")
                                        } else {
                                            root.showToast("导出失败")
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 72
                                Layout.preferredHeight: 30
                                radius: 0
                                color: importLyricsBtn.containsMouse ? Theme.hover : "transparent"
                                border.color: Theme.border
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "导入"
                                    color: Theme.text
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                                }

                                MouseArea {
                                    id: importLyricsBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        let path = appSettings.pickOpenFile(
                                            "选择歌词包", "JSON (*.json)")
                                        if (path === "") return
                                        let n = translationService.importCache(path)
                                        if (n > 0) {
                                            root.showToast("已导入 " + n +
                                                " 首歌词翻译")
                                        } else {
                                            root.showToast("没有新增歌词（可能已存在）")
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 72
                                Layout.preferredHeight: 30
                                radius: 0
                                color: delPackBtn.containsMouse && translationService.cacheCount > 0
                                       ? "#33e81123" : "transparent"
                                border.color: delPackBtn.containsMouse && translationService.cacheCount > 0
                                              ? "transparent" : Theme.border
                                border.width: delPackBtn.containsMouse && translationService.cacheCount > 0 ? 0 : 1
                                opacity: translationService.cacheCount > 0 ? 1.0 : 0.4
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "删除"
                                    color: "#e81123"
                                    font {
                                        family: Theme.fontFamily
                                        pixelSize: Theme.fs(12)
                                        bold: delPackBtn.containsMouse && translationService.cacheCount > 0
                                    }
                                }

                                MouseArea {
                                    id: delPackBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: translationService.cacheCount > 0
                                    onClicked: confirmDialog.openFor("lyricsPack")
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderLight; opacity: 0.6; enabled: false }

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
                                radius: 0
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
                                radius: 0
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
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
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
                // 关于 / 应用
                // ============================================================
                Rectangle {
                    visible: settingsPageRoot.category === "about"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Layout.fillWidth: true
                    Layout.preferredHeight: aboutCol.implicitHeight + 40
                    radius: 0
                    color: Theme.panel

                    ColumnLayout {
                        id: aboutCol
                        anchors { fill: parent; margins: 20 }
                        spacing: 14

                        Text {
                            text: "关于 / 应用"
                            color: Theme.accent
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(14); bold: true }
                        }
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "启动时检查更新"
                                    color: Theme.text
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                    Layout.fillWidth: true
                                }
                                TechSwitch {
                                    checked: appSettings.checkUpdate
                                    onClicked: appSettings.checkUpdate = !appSettings.checkUpdate
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "记住窗口位置与大小"
                                    color: Theme.text
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(13) }
                                    Layout.fillWidth: true
                                }
                                TechSwitch {
                                    checked: appSettings.rememberGeometry
                                    onClicked: appSettings.rememberGeometry = !appSettings.rememberGeometry
                                }
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

                            Rectangle {
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 32
                                radius: 0
                                color: repoBtn.containsMouse ? Theme.hover : "transparent"
                                border.color: Theme.border
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "打开仓库"
                                    color: Theme.text
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
                                }

                                MouseArea {
                                    id: repoBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: appSettings.openUrl(root.repoUrl)
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 32
                                radius: 0
                                color: checkUpdateBtn.containsMouse && root.updateStatus !== "checking"
                                       ? Theme.accentHover : Theme.accent
                                opacity: root.updateStatus === "checking" ? 0.5 : 1.0
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: root.updateStatus === "checking" ? "检查中..." : "检查更新"
                                    color: Theme.ink
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
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

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 0
                            visible: root.updateStatus === "available" && root.updateUrl !== ""
                            color: downloadBtn.containsMouse ? Theme.accentHover : Theme.accent
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                anchors.centerIn: parent
                                text: "前往下载 " + root.updateVersion
                                color: Theme.ink
                                font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                            }

                            MouseArea {
                                id: downloadBtn
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: appSettings.openUrl(root.updateUrl)
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderLight; opacity: 0.6; enabled: false }

                        Text {
                            text: "应用控制"
                            color: Theme.textDim
                            font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                radius: 0
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
                                Layout.preferredHeight: 32
                                radius: 0
                                color: restartBtn.containsMouse ? Theme.accentHover : Theme.accent
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "重启应用"
                                    color: Theme.ink
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
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
                                Layout.preferredHeight: 32
                                radius: 0
                                color: quitBtn.containsMouse ? Theme.danger : "transparent"
                                border.color: quitBtn.containsMouse ? "transparent" : Theme.danger
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "关闭应用"
                                    color: quitBtn.containsMouse ? Theme.ink : Theme.danger
                                    font { family: Theme.fontFamily; pixelSize: Theme.fs(12); bold: true }
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
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

    // ============================================================
    // 确认清空弹窗
    // ============================================================
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
            } else if (t === "lyricsPack") {
                titleText = "删除已导入的歌词包"
                bodyText = "将删除所有已缓存的翻译歌词（" +
                           translationService.cacheCount +
                           " 首）。删除后再次播放时需要重新翻译。"
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
            radius: 0
            color: Theme.panel
            border.color: Theme.border
            border.width: 1

            scale: confirmDialog.opacity > 0.5 ? 1.0 : 0.85
            Behavior on scale {
                NumberAnimation { duration: 260; easing.type: Easing.OutBack }
            }

            ColumnLayout {
                anchors { fill: parent; margins: 20 }
                spacing: 14

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
                        radius: 0
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
                        radius: 0
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
                                    refreshTimer.restart()
                                    clearingResetTimer.restart()
                                } else if (t === "http") {
                                    networkManager.clearHttpCache()
                                    refreshTimer.restart()
                                    clearingResetTimer.restart()
                                } else if (t === "lyricsPack") {
                                    translationService.clearLyricsPack()
                                    root.clearing = false
                                    root.showToast("已删除歌词包")
                                } else {
                                    audioCache.clearAll()
                                    networkManager.clearHttpCache()
                                    refreshTimer.restart()
                                    clearingResetTimer.restart()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // Toast
    // ============================================================
    Rectangle {
        id: toast
        parent: Overlay.overlay
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60
        width: toastText.implicitWidth + 40
        height: 40
        radius: 0
        color: Theme.glassBgDeep
        opacity: 0
        visible: opacity > 0.01
        z: 2000

        Behavior on opacity { NumberAnimation { duration: 200 } }

        Text {
            id: toastText
            anchors.centerIn: parent
            text: root.toastMsg
            color: Theme.textBright
            font { family: Theme.fontFamily; pixelSize: Theme.fs(12) }
        }

        Timer {
            id: toastTimer
            interval: 2500
            onTriggered: toast.opacity = 0
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