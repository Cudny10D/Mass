pragma Singleton
import QtQuick

QtObject {
    id: theme

    property bool darkMode: true
    property real uiScale: 1.0
    property bool windowFullscreen: false

    function fs(baseSize) {
        return Math.round(baseSize * uiScale)
    }

    // Accent
    property color accent:      darkMode ? "#ffffff" : "#000000"
    property color accentHover: darkMode ? "#d0d0d0" : "#202020"
    property color accentGlow:  darkMode ? "#30ffffff" : "#30000000"
    property color onAccent:    darkMode ? "#000000" : "#ffffff"

    // Backgrounds
    property color bg:       darkMode ? "#1e1e1e" : "#ffffff"
    property color bgAlt:    darkMode ? "#181818" : "#f5f5f5"
    property color panel:    darkMode ? "#252526" : "#f3f3f3"
    property color panelAlt: darkMode ? "#2d2d30" : "#e8e8e8"
    property color sideBar:  darkMode ? "#1a1a1a" : "#ececec"
    property color titleBar: darkMode ? "#2b2b2c" : "#eaeaea"

    // Border / Hover
    property color border:      darkMode ? "#3e3e42" : "#d4d4d4"
    property color borderLight: darkMode ? "#2a2d2e" : "#e4e4e4"
    property color hover:       darkMode ? "#2a2d2e" : "#e0e0e0"
    property color active:      darkMode ? "#37373d" : "#d6d6d6"

    // Text
    property color text:       darkMode ? "#e8e8e8" : "#1a1a1a"
    property color textDim:    darkMode ? "#a8a8a8" : "#555555"
    property color textMuted:  darkMode ? "#707070" : "#888888"
    property color textBright: darkMode ? "#ffffff" : "#000000"

    property color danger: "#e81123"

    // Glass / Shadows
    property color glassBgDeep:    darkMode ? "#1a000000" : "#99ffffff"
    property color glassHighlight: darkMode ? "#40ffffff" : "#66ffffff"
    property color pillHighlight:  darkMode ? "#66ffffff" : "#80ffffff"

    property color shadowSoft:   darkMode ? "#00000050" : "#00000015"
    property color shadowMedium: darkMode ? "#00000080" : "#00000022"
    property color shadowDeep:   darkMode ? "#000000c0" : "#00000033"

    property color windowTopColor:    darkMode ? "#232324" : "#fafafa"
    property color windowBottomColor: darkMode ? "#161617" : "#ececec"

    // Gradients
    readonly property var gradientGlass: darkMode
        ? ["#40ffffff", "#14ffffff"]
        : ["#b3ffffff", "#66ffffff"]

    readonly property var gradientPill: darkMode
        ? ["#4dffffff", "#1affffff"]
        : ["#ccffffff", "#99ffffff"]

    readonly property var gradientWindow: darkMode
        ? ["#232324", "#161617"]
        : ["#fafafa", "#ececec"]

    // Layout
    readonly property string fontFamily: "Microsoft YaHei"
    readonly property int radiusSmall: 4
    readonly property int radius: 8
    readonly property int radiusLarge: 14
    readonly property int radiusWindow: 12
    readonly property int radiusPill: 34

    readonly property int animFast: 120
    readonly property int animNormal: 220
    readonly property int animSlow: 320
    readonly property int themeAnim: 320

    readonly property int playerBarHeight: 92
    readonly property int playerBarMargin: 14
    readonly property int playerBarBottomMargin: 12
    readonly property int playerBarMaxWidth: 900

    readonly property int sidebarWidth: 56
    readonly property int sidebarWidthExpanded: 200

    function windowTop(alpha) {
        return Qt.rgba(windowTopColor.r, windowTopColor.g,
                       windowTopColor.b, alpha)
    }
    function windowBottom(alpha) {
        return Qt.rgba(windowBottomColor.r, windowBottomColor.g,
                       windowBottomColor.b, alpha)
    }
}