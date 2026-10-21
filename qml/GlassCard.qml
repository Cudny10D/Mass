import QtQuick
import QtQuick.Effects

Item {
    id: glassCard

    property real cornerRadius: 24
    property alias radius: glassCard.cornerRadius

    property real blurAmount: 1.0
    property real blurMultiplier: 1.0
    property real tintOpacity: 0.42
    property color tintColor: Theme.darkMode ? "#1a1c22" : "#e8ecf4"
    property real highlightOpacity: 0.28
    property real borderOpacity: 0.12
    property Item backgroundSource: null

    property real noiseOpacity: 0.05
    property real saturationBoost: 0.25

    property real shadowOpacity: Theme.darkMode ? 0.55 : 0.30
    property real shadowOffsetY: 3

    // 圆角遮罩形状（同时作为 mask 与投影的形状来源）
    Rectangle {
        id: maskShape
        anchors.fill: parent
        radius: glassCard.cornerRadius
        color: "white"
        antialiasing: true
        smooth: true
        visible: false
        layer.enabled: true
        layer.smooth: true
    }

    // 外投影（由同一个圆角形状生成；内部挖空，避免剪影从半透明玻璃里透出来压暗面板）
    MultiEffect {
        z: -1
        anchors.fill: parent
        source: maskShape
        autoPaddingEnabled: true
        blurEnabled: false
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: glassCard.shadowOpacity
        shadowBlur: 1.0
        shadowVerticalOffset: glassCard.shadowOffsetY
        shadowHorizontalOffset: 0
        maskEnabled: true
        maskSource: maskShape
        maskInverted: true
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.5
        smooth: true
    }

    // 捕获背景对应区域
    ShaderEffectSource {
        id: bgCapture
        sourceItem: glassCard.backgroundSource
        live: true
        hideSource: false
        visible: false
        smooth: true
        recursive: false
        sourceRect: {
            if (!glassCard.backgroundSource) return Qt.rect(0, 0, 0, 0)
            var p = glassCard.mapToItem(glassCard.backgroundSource, 0, 0)
            return Qt.rect(p.x, p.y, glassCard.width, glassCard.height)
        }
    }

    // 模糊 + 圆角遮罩
    MultiEffect {
        id: blurEffect
        anchors.fill: parent
        source: bgCapture
        maskEnabled: true
        maskSource: maskShape
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.5
        blurEnabled: true
        blur: glassCard.blurAmount
        blurMax: 64
        blurMultiplier: glassCard.blurMultiplier
        saturation: glassCard.saturationBoost
        contrast: 0.05
        smooth: true
    }

    // 色调叠加
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(glassCard.tintColor.r,
                       glassCard.tintColor.g,
                       glassCard.tintColor.b,
                       glassCard.tintOpacity)
        radius: glassCard.cornerRadius
        antialiasing: true
        smooth: true
    }

    // 噪点
    Canvas {
        id: noise
        anchors.fill: parent
        opacity: glassCard.noiseOpacity
        // 一次画满静态噪点；不用着色器，避免编译失败导致整层不渲染
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            // 只做浅色细颗粒，不用黑白噪点：黑白点是"雪花"，会把乳白质感盖掉
            var count = Math.round(width * height * 0.04)
            for (var i = 0; i < count; i++) {
                var v = 210 + Math.round(Math.random() * 45)
                ctx.fillStyle = "rgba(" + v + "," + v + "," + v + ",0.5)"
                ctx.fillRect(Math.floor(Math.random() * width),
                             Math.floor(Math.random() * height), 1, 1)
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    // 高光边框
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: glassCard.cornerRadius
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, glassCard.borderOpacity)
        antialiasing: true
    }

    // 左上角高光
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 1
        anchors.leftMargin: 1
        width: parent.width
        height: Math.min(parent.height * 0.32, 44)
        radius: glassCard.cornerRadius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, Math.min(1.0, glassCard.highlightOpacity * 0.45)) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
        }
        visible: !Theme.darkMode
        antialiasing: true
    }
}
