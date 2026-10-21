import QtQuick
import QtQuick.Effects

// 侧边 Dock：液态玻璃 + 可拖动的滑动选择块
//
// 参照 AndroidLiquidGlass 的 LiquidBottomTabs：
//   - 底板是一整块玻璃（这里用真正的折射着色器，见 LiquidGlass.qml）
//   - 当前页由一块玻璃选择块表示，在图标之间滑动
//   - 选择块可以直接拖动，松手吸附到最近的图标
//
// 注意：选择块必须放在图标之前声明（z 序在下面），否则会盖住图标。
Item {
    id: root

    property bool hovered: false
    property int collapsedWidth: 52
    property int expandedWidth: 68

    signal pageChanged(string page)
    property string currentPage: "siren"
    property Item backgroundSource: null

    // 页面顺序 / 图标（顺序改动时只改这两行）
    // 图标后面的 \uFE0E 是「文本呈现」变体选择符；字体用 Segoe UI Symbol，
    // 否则 Windows 会把 ♥ ⚙ 交给彩色 emoji 字体渲染。
    readonly property var pageIds: ["siren", "search", "local", "history", "playlist", "settings"]
    readonly property var pageIcons: ["◈\uFE0E", "⌕\uFE0E", "♥\uFE0E",
                                      "⟲\uFE0E", "♫\uFE0E", "⚙\uFE0E"]

    readonly property int itemSize: 48
    readonly property int itemGap: 4
    readonly property int pitch: itemSize + itemGap
    readonly property int contentHeight: pageIds.length * itemSize + (pageIds.length - 1) * itemGap
    readonly property int contentTop: Math.round((height - contentHeight) / 2)
    readonly property int currentIndex: Math.max(0, pageIds.indexOf(currentPage))

    // 选择块的实时位置（拖动时是小数，松手后吸附到整数）
    property real sliderIndex: currentIndex
    property int hoveredIndex: -1
    property bool dragging: false

    width: hovered ? expandedWidth : collapsedWidth
    height: pageIds.length * 52 + 24
    clip: false

    Behavior on width {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    // 外部（点图标/切页）改变当前页时：滑块跟过去，并触发一次液体拉伸。
    // 拖动中不要抢滑块位置。
    onCurrentIndexChanged: {
        if (!dragging) sliderIndex = currentIndex
        stretchAnim.restart()
    }

    // 悬停展开 / 收起
    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                root.hovered = true
                collapseTimer.stop()
            } else {
                collapseTimer.restart()
            }
        }
    }
    Timer {
        id: collapseTimer
        interval: 220
        onTriggered: root.hovered = false
    }

    // ── 玻璃底板 ────────────────────────────────────────────────
    LiquidGlass {
        id: dockGlass
        anchors.fill: parent
        radius: 0
        backgroundSource: root.backgroundSource

        blurMultiplier: 1.8
        tintOpacity: appSettings.glassTint
        saturation: 0.45
        highlightOpacity: 0.26
        borderOpacity: 0.24
        shadowOpacity: 0.35
        shadowOffsetY: 4

        refractionHeight: 12
        refractionAmount: 22
        depthEffect: false
        chromaticAberration: false
    }

    // ── 滑动选择块 ──────────────────────────────────────────────
    Item {
        id: selection
        x: 4
        // 宽度直接跟随 root.width（root.width 自己已经有 220ms 动画）。
        // 早先这里又挂了一个 Behavior on width，两段动画叠在一起，
        // 才会出现「Dock 收起了、滑块还没收」的不同步。
        width: root.width - 8

        property real stretch: 0
        readonly property real dragGrow: root.dragging ? 3 : 0

        y: root.contentTop + root.sliderIndex * root.pitch + 1
        transform: Translate { y: -(selection.stretch + selection.dragGrow) / 2 }

        // 只在「点图标切页」时做一次吸附动画；拖动时由手指直接驱动
        Behavior on y {
            enabled: !root.dragging
            NumberAnimation {
                duration: 380
                easing.type: Easing.OutBack
                easing.overshoot: 1.1
            }
        }

        height: root.itemSize - 2 + stretch + dragGrow

        SequentialAnimation {
            id: stretchAnim
            NumberAnimation {
                target: selection; property: "stretch"
                to: 9; duration: 90; easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: selection; property: "stretch"
                to: 0; duration: 300; easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            id: radiusRect
            anchors.fill: parent
            radius: 0
            antialiasing: true
            color: Theme.darkMode ? Qt.rgba(1, 1, 1, 0.15)
                                  : Qt.rgba(0, 0, 0, 0.09)
            border.width: 1
            border.color: Theme.darkMode ? Qt.rgba(1, 1, 1, 0.34)
                                         : Qt.rgba(0, 0, 0, 0.16)
        }

        Rectangle {
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                margins: 1
            }
            height: parent.height * 0.52
            radius: 0
            antialiasing: true
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(1, 1, 1, Theme.darkMode ? 0.20 : 0.42)
                }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
    }

    // ── 图标列 ──────────────────────────────────────────────────
    Column {
        id: iconColumn
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.contentTop
        spacing: root.itemGap

        Repeater {
            model: root.pageIds.length

            delegate: Item {
                id: iconItem
                width: root.itemSize
                height: root.itemSize

                readonly property bool isActive: root.currentPage === root.pageIds[index]
                readonly property bool isHover: root.hoveredIndex === index

                Text {
                    anchors.centerIn: parent
                    text: root.pageIcons[index]
                    color: isActive ? Theme.accent
                                    : (isHover ? Theme.text : Theme.textDim)
                    font {
                        // 用 Segoe UI Symbol 而不是默认字体：默认字体链会把
                        // ♥ ⚙ 之类交给彩色 emoji 字体，渲染成紫色/红色图标。
                        family: "Segoe UI Symbol"
                        pixelSize: Theme.fs(20)
                        bold: isActive
                    }
                    scale: isActive ? 1.0 : (isHover ? 1.12 : 0.95)
                    Behavior on scale {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
            }
        }
    }

    // ── 输入：单击切页 + 直接拖动滑块 ───────────────────────────
    // 用一个覆盖整块 dock 的 MouseArea 统一处理，
    // 这样拖动时接收器不会跟着滑块移动（否则会抖动）。
    MouseArea {
        id: dockMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        property real pressY: 0
        property bool moved: false

        function indexAt(y) {
            const i = Math.floor((y - root.contentTop) / root.pitch)
            return Math.max(0, Math.min(root.pageIds.length - 1, i))
        }
        function fractionAt(y) {
            return Math.max(0, Math.min(root.pageIds.length - 1,
                (y - root.contentTop - root.itemSize / 2) / root.pitch))
        }

        onEntered: root.hoveredIndex = indexAt(mouseY)
        onExited: {
            root.hoveredIndex = -1
            if (!root.dragging) root.sliderIndex = root.currentIndex
        }
        onPositionChanged: (m) => {
            root.hoveredIndex = indexAt(m.y)
            if (pressed) {
                if (Math.abs(m.y - pressY) > 3) {
                    root.dragging = true
                    moved = true
                }
                if (moved) root.sliderIndex = fractionAt(m.y)
            }
        }
        onPressed: (m) => {
            pressY = m.y
            moved = false
        }
        onReleased: (m) => {
            if (moved) {
                const target = Math.round(root.sliderIndex)
                root.sliderIndex = target
                if (root.pageIds[target] !== root.currentPage)
                    root.pageChanged(root.pageIds[target])
            } else {
                const i = indexAt(m.y)
                root.sliderIndex = i
                if (root.pageIds[i] !== root.currentPage)
                    root.pageChanged(root.pageIds[i])
            }
            root.dragging = false
            moved = false
        }
        onCanceled: {
            root.dragging = false
            moved = false
            root.sliderIndex = root.currentIndex
        }
    }
}
