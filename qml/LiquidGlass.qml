import QtQuick
import QtQuick.Effects

// 液态玻璃（Liquid Glass）
//
// 移植自 AndroidLiquidGlass / kyant0 的 backdrop 库：
// 捕获背后内容 → 模糊 → 用圆角矩形 SDF 在边缘做折射（可叠色散）→ 染色 + 描边 + 高光。
//
// 关于 ShaderEffect 的坑（重要）：
//   Qt 6 的 RHI 先用 qsb 把 shaders/*.frag|vert 编成 SPIR-V，SPIR-V 只接受
//   GLSL ES 310+。若用 ES 100 的 varying / gl_FragColor，着色器会**静默失效**：
//   不报错、不渲染，玻璃直接消失。所以这里的 shader 全部是 310 es，并且显式
//   指定了 vertexShader（Qt 在自定义 vertex shader 时才会走我们声明的版本）。
Item {
    id: glass

    // ── 形状 ────────────────────────────────────────────────────
    property real cornerRadius: 24
    property alias radius: glass.cornerRadius

    // ── 背景来源 ────────────────────────────────────────────────
    property Item backgroundSource: null

    // ── 模糊 ────────────────────────────────────────────────────
    property real blurAmount: 1.0
    property real blurMultiplier: 1.0
    property real saturation: 0.35

    // ── 折射（核心）─────────────────────────────────────────────
    property real refractionHeight: 20   // 折射作用带宽度（px）
    property real refractionAmount: 40   // 沿法线推出的像素数
    property bool depthEffect: true      // 叠加深度感
    property bool chromaticAberration: true // 边缘色散

    // ── 染色 ────────────────────────────────────────────────────
    property color tintColor: Theme.darkMode ? "#1a1c22" : "#e8ecf4"
    property real tintOpacity: 0.16

    // ── 描边与高光 ──────────────────────────────────────────────
    property real borderOpacity: 0.32
    property real highlightOpacity: Theme.darkMode ? 0.10 : 0.30

    // ── 投影 ────────────────────────────────────────────────────
    property real shadowOpacity: Theme.darkMode ? 0.55 : 0.30
    property real shadowOffsetY: 4

    // 折射要把采样坐标推出玻璃边界，捕获区必须外扩这么多像素，
    // 否则边缘会采到捕获纹理之外（钳制出硬边）。
    readonly property real lensPadding: Math.ceil(refractionHeight + Math.abs(refractionAmount) + 2)
    readonly property real captureW: width + lensPadding * 2
    readonly property real captureH: height + lensPadding * 2

    // 圆角遮罩形状（用于投影与裁剪）
    Rectangle {
        id: maskShape
        anchors.fill: parent
        radius: glass.cornerRadius
        color: "white"
        antialiasing: true
        smooth: true
        visible: false
        layer.enabled: true
        layer.smooth: true
    }

    // 外投影
    MultiEffect {
        z: -1
        anchors.fill: parent
        source: maskShape
        autoPaddingEnabled: true
        blurEnabled: false
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: glass.shadowOpacity
        shadowBlur: 1.0
        shadowVerticalOffset: glass.shadowOffsetY
        shadowHorizontalOffset: 0
        maskEnabled: true
        maskSource: maskShape
        maskInverted: true
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.5
        smooth: true
    }

    // 捕获背后内容（外扩 lensPadding，供折射采样）
    ShaderEffectSource {
        id: bgCapture
        sourceItem: glass.backgroundSource
        live: true
        recursive: false
        hideSource: false
        smooth: true
        visible: false
        sourceRect: {
            if (!glass.backgroundSource) return Qt.rect(0, 0, 0, 0)
            var p = glass.mapToItem(glass.backgroundSource, 0, 0)
            return Qt.rect(p.x - glass.lensPadding, p.y - glass.lensPadding,
                           glass.captureW, glass.captureH)
        }
    }

    // 模糊
    MultiEffect {
        id: blurEffect
        anchors.fill: parent
        source: bgCapture
        visible: false
        blurEnabled: true
        blur: glass.blurAmount
        blurMax: 64
        blurMultiplier: glass.blurMultiplier
        saturation: glass.saturation
        contrast: 0.05
        smooth: true
        // 注意：MultiEffect 输出的是「放大过」的纹理（xOffset/yOffset 为负、
        // 实际内容从 padding 处开始），所以下面 shader 用它当 source 时，
        // 用 ShaderEffectSource 再包一层把几何对齐回来。
    }

    // 把模糊结果重新对齐成与捕获区同尺寸的纹理，
    // 这样 shader 里 content 的 [0,1] 就严格对应捕获区。
    ShaderEffectSource {
        id: blurredCapture
        sourceItem: blurEffect
        live: true
        recursive: false
        hideSource: true
        smooth: true
        visible: false
        sourceRect: Qt.rect(-blurEffect.xOffset, -blurEffect.yOffset,
                            glass.captureW, glass.captureH)
        width: glass.captureW
        height: glass.captureH
    }

    // 折射层：铺满「外扩后」的区域，shader 内部再把玻璃矩形摆到中间
    ShaderEffect {
        id: lens
        x: -glass.lensPadding
        y: -glass.lensPadding
        width: glass.captureW
        height: glass.captureH

        vertexShader: "qrc:/shaders/liquidglass.vert.qsb"
        fragmentShader: "qrc:/shaders/liquidglass.frag.qsb"

        property real cornerRadius: glass.cornerRadius
        property real lensPadding: glass.lensPadding
        property real refractionHeight: glass.refractionHeight
        property real refractionAmount: glass.refractionAmount

        // 与 shader 里 uniform block 的成员一一对应（名字必须一致）。
        // 注意不能叫 size / offset / width / height —— 这些是 Item 的内置属性，
        // 同名 property 会被内置值覆盖，shader 永远收到 0 或错误尺寸。
        property vector2d uSize: Qt.vector2d(width, height)
        property vector2d uOffset: Qt.vector2d(glass.lensPadding, glass.lensPadding)
        property vector4d uCornerRadii: {
            var r = Math.max(0, glass.cornerRadius)
            return Qt.vector4d(r, r, r, r)
        }
        // x=refractionHeight y=refractionAmount z=depthEffect w=aberration
        property vector4d uParams: Qt.vector4d(
            glass.refractionHeight,
            glass.refractionAmount,
            glass.depthEffect ? 1.0 : 0.0,
            glass.chromaticAberration ? 1.0 : 0.0)

        property variant content: blurredCapture
    }

    // 染色
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(glass.tintColor.r,
                       glass.tintColor.g,
                       glass.tintColor.b,
                       glass.tintOpacity)
        radius: glass.cornerRadius
        antialiasing: true
        smooth: true
    }

    // 描边（内圈 1px 亮边）
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: glass.cornerRadius
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, glass.borderOpacity)
        antialiasing: true
        smooth: true
    }

    // 顶部高光（模拟玻璃受光面）
    //
    // 注意：不能让高光矩形横向铺满整个宽度。胶囊两端的圆角半径（=高度/2）
    // 远大于高光条自身的高度，矩形那 18px 的小圆角根本贴不住 46px 的胶囊角，
    // 两端就会「戳」到圆角外面 —— 这就是高光溢出播放器范围的原因。
    // 这里左右各内缩一个 cornerRadius，只覆盖顶部直边段；太窄/竖长的形状
    //（比如 Dock）直接不画，避免在圆形端头里出现一块怪光斑。
    Rectangle {
        id: topHighlight
        readonly property real inset: Math.min(glass.cornerRadius, glass.width * 0.28)
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 1
        anchors.leftMargin: inset
        anchors.rightMargin: inset
        height: Math.min(glass.height * 0.38, glass.cornerRadius * 1.6)
        radius: 0
        visible: width > 8 && width > height * 0.8
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, glass.highlightOpacity) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
        }
        antialiasing: true
        smooth: true
    }
}
