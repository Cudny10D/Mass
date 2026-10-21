pragma Singleton
import QtQuick

// ============================================================
// 设计系统：莱茵生命终端（Rhine Lab terminal）
//
// 语言要点：
//   - 暖灰纸底 + 墨黑字，不用玻璃、不用大圆角、不用投影堆叠
//   - 大号粗体中文标题，配一行等宽小号大写英文标签
//   - 一切分隔用 1px 细线，一切色块用直角
//   - 强调色只有一种：低饱和橄榄绿，且只用在「可执行」的地方
// ============================================================
QtObject {
    id: theme

    property bool darkMode: false
    property real uiScale: 1.0

    function fs(baseSize) {
        return Math.round(baseSize * uiScale)
    }

    function formatTime(ms) {
        if (!ms || ms < 0) return "00:00"
        let s = Math.floor(ms / 1000)
        let m = Math.floor(s / 60); s = s % 60
        return m.toString().padStart(2, "0") + ":"
             + s.toString().padStart(2, "0")
    }

    // ── 字体 ────────────────────────────────────────────────────
    // 正文用系统中文黑体；技术标签用等宽，撑起「终端」气质。
    readonly property string fontFamily: "Microsoft YaHei"
    readonly property string displayFamily: "Microsoft YaHei"
    readonly property string monoFamily: "Consolas"

    // ── 强调色 ──────────────────────────────────────────────────
    // 唯一可被用户改写的色相入口：accentBase（设置 → 外观 → 主题色）。
    // 其余色阶全部从它派生，改一个值即整站换色：
    //   亮色模式 hover 压暗，暗色模式整体提亮，保证在纸底/墨底上都能看清。
    readonly property color accentDefault: "#6E744C"
    property color accentBase: accentDefault

    readonly property color accent: darkMode
        ? Qt.lighter(accentBase, 1.42)
        : accentBase
    readonly property color accentHover: darkMode
        ? Qt.lighter(accentBase, 1.78)
        : Qt.darker(accentBase, 1.28)
    readonly property color accentGlow: Qt.rgba(accent.r, accent.g, accent.b,
                                                darkMode ? 0.20 : 0.18)

    // accent 上的文字/图标按底色亮度自动取黑白：
    // 用户把主题色换成浅黄、浅青时也不会糊成一片。
    readonly property color ink: (0.299 * accent.r + 0.587 * accent.g
                                  + 0.114 * accent.b) > 0.56 ? "#16170F" : "#F6F4EE"

    // ── 底色 ────────────────────────────────────────────────────
    property color bg:       darkMode ? "#1A1B17" : "#ECEAE5"
    property color bgAlt:    darkMode ? "#20211C" : "#E2DFD7"
    property color panel:    darkMode ? "#232420" : "#F4F2EC"
    property color panelAlt: darkMode ? "#2B2C26" : "#E0DDD4"
    property color sideBar:  darkMode ? "#1A1B17" : "#ECEAE5"
    property color titleBar: darkMode ? "#1A1B17" : "#ECEAE5"

    // ── 细线 / 悬停 ──────────────────────────────────────────────
    property color border:      darkMode ? "#3A3B33" : "#C7C3B8"
    property color borderLight: darkMode ? "#2E2F29" : "#D9D5CB"
    property color hover:       darkMode ? "#2A2B25" : "#E2DFD6"
    property color active:      darkMode ? "#34352D" : "#D5D1C6"

    // ── 文字 ────────────────────────────────────────────────────
    property color text:       darkMode ? "#E7E5DC" : "#1B1C19"
    property color textDim:    darkMode ? "#A6A497" : "#5B5C55"
    property color textMuted:  darkMode ? "#75736A" : "#8B8A80"
    property color textBright: darkMode ? "#FFFFFF" : "#000000"

    property color danger: darkMode ? "#C9736A" : "#A3413A"

    // ── 面板（旧玻璃属性的替身，保持页面代码不改）──────────────
    property color glassBgDeep:    darkMode ? "#F21E1F1A" : "#F2F3F1EB"
    property color glassHighlight: darkMode ? "#1AFFFFFF" : "#66FFFFFF"
    property color pillHighlight:  darkMode ? "#14FFFFFF" : "#4DFFFFFF"

    property color shadowSoft:   darkMode ? "#00000030" : "#0000000D"
    property color shadowMedium: darkMode ? "#00000050" : "#00000014"
    property color shadowDeep:   darkMode ? "#00000070" : "#0000001F"

    property color windowTopColor:    darkMode ? "#1A1B17" : "#ECEAE5"
    property color windowBottomColor: darkMode ? "#191A16" : "#E9E7E1"

    readonly property var gradientGlass: darkMode
        ? ["#0DFFFFFF", "#05FFFFFF"]
        : ["#40FFFFFF", "#1AFFFFFF"]

    // ── 布局 ────────────────────────────────────────────────────
    readonly property int radiusSmall: 2
    readonly property int radius: 2
    readonly property int radiusLarge: 3
    readonly property int radiusWindow: 0
    readonly property int radiusPill: 2

    readonly property int animFast: 110
    readonly property int animNormal: 200
    readonly property int animSlow: 300
    readonly property int themeAnim: 260

    readonly property int headerHeight: 96
    readonly property int playerBarHeight: 86
    readonly property int playerBarMargin: 0
    readonly property int playerBarBottomMargin: 0
    readonly property int playerBarMaxWidth: 100000

    // 表格行高 / 表头高
    readonly property int rowHeight: 44
    readonly property int tableHeaderHeight: 30

    readonly property int sidebarWidth: 0
    readonly property int sidebarWidthExpanded: 0

    // ── 最大化适配 ────────────────────────────────────────────────
    // 内容留白与网格列数都只由「窗口宽度」推导，并在 Main.qml 的
    // onWidthChanged 里写入这两个值（不要在 GridView 内部反推，会抖）。
    property int windowWidth: 1240
    property int contentSideMargin: 56

    // 左边距固定在 56 左右，超宽屏才缓慢增加
    function sideMargin(viewportWidth) {
        return Math.round(Math.max(48, Math.min(96, viewportWidth * 0.042)))
    }

    readonly property int gridTargetCell: 196
    readonly property int gridGap: 20

    readonly property var gridMetrics: {
        const avail = Math.max(1, windowWidth - contentSideMargin * 2)
        const gap = gridGap
        const usable = Math.max(1, avail - gap)
        let columns = Math.round(usable / (gridTargetCell + gap))
        columns = Math.max(2, Math.min(14, columns))
        columns = Math.min(columns, Math.max(1, Math.floor(usable / (72 + gap))))
        return { columns: columns, cellWidth: usable / columns }
    }

    function windowTop(alpha) {
        return Qt.rgba(windowTopColor.r, windowTopColor.g,
                       windowTopColor.b, alpha)
    }
    function windowBottom(alpha) {
        return Qt.rgba(windowBottomColor.r, windowBottomColor.g,
                       windowBottomColor.b, alpha)
    }

    // 等宽小标签的通用字号
    readonly property int labelSize: Math.round(10 * uiScale)
    readonly property int microSize: Math.round(9 * uiScale)
}
