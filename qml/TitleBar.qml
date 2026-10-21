import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// ============================================================
// 顶部标题区（原窗口标题栏）
//
//   ┌ MASS                                         — □ × ┐
//   │ 曲目资料库                                        │
//   │ MASS / MONSTER SIREN DATABASE   发现音乐 ↗ 音乐检索 / ... │
//   └───────────────────────────────────────────────────┘
//
// 左侧大标题由页面决定（pageTitle），副标是固定的库名；
// 右侧是页签导航；右上角是极简窗口控制。
// ============================================================
Item {
    id: root

    property string windowTitle: "Mass"
    property string pageTitle: "曲目资料库"
    property string pageSubtitle: "MASS / MONSTER SIREN DATABASE"
    property string currentPage: "siren"
    property bool maximized: false

    signal pageChanged(string page)
    signal minimizeRequested()
    signal maximizeRequested()
    signal closeRequested()

    implicitHeight: Theme.headerHeight
    implicitWidth: 800

    readonly property var navIds: ["siren", "search", "playlist", "local", "history", "settings"]
    readonly property var navLabels: ["发现音乐 ↗", "音乐检索 /", "＋ 我的音乐", "本地文件", "播放历史", "设置"]

    // 整条标题栏都可以拖动窗口
    MouseArea {
        anchors.fill: parent
        z: -10
        onPressed: root.Window.window.startSystemMove()
        onDoubleClicked: root.maximizeRequested()
    }

    // ── 右上角窗口控制 ──────────────────────────────────────────
    Row {
        id: winControls
        anchors.right: parent.right
        anchors.rightMargin: Math.max(12, Theme.contentSideMargin - 16)
        anchors.top: parent.top
        anchors.topMargin: 8
        spacing: 2

        Repeater {
            model: [
                { glyph: "—", tip: "最小化", act: "min" },
                { glyph: root.maximized ? "❐" : "□", tip: root.maximized ? "还原" : "最大化", act: "max" },
                { glyph: "✕", tip: "关闭", act: "close" }
            ]

            delegate: Rectangle {
                width: 30
                height: 24
                color: hoverArea.containsMouse
                       ? (modelData.act === "close" ? Theme.danger : Theme.hover)
                       : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: modelData.glyph
                    color: hoverArea.containsMouse && modelData.act === "close"
                           ? Theme.ink : Theme.textMuted
                    font {
                        family: Theme.monoFamily
                        pixelSize: Theme.fs(11)
                    }
                }

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.act === "min") root.minimizeRequested()
                        else if (modelData.act === "max") root.maximizeRequested()
                        else root.closeRequested()
                    }
                }
            }
        }
    }

    // ── 标题 + 导航 ────────────────────────────────────────────
    Item {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: Theme.contentSideMargin
            rightMargin: Theme.contentSideMargin
            bottomMargin: 14
        }
        height: 46

        Column {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            spacing: 5

            Text {
                text: root.pageTitle
                color: Theme.text
                font {
                    family: Theme.displayFamily
                    pixelSize: Theme.fs(26)
                    bold: true
                    letterSpacing: 0.4
                }
            }

            Text {
                text: root.pageSubtitle
                color: Theme.textMuted
                font {
                    family: Theme.monoFamily
                    pixelSize: Theme.microSize
                    letterSpacing: 1.6
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            spacing: 30

            Repeater {
                model: root.navIds.length

                delegate: Item {
                    id: navItem
                    width: navText.implicitWidth
                    height: 26

                    readonly property bool active: root.currentPage === root.navIds[index]

                    Text {
                        id: navText
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 5
                        text: root.navLabels[index]
                        color: navItem.active
                               ? Theme.text
                               : (navMouse.containsMouse ? Theme.text : Theme.textDim)
                        font {
                            family: Theme.fontFamily
                            pixelSize: Theme.fs(12.5)
                            weight: navItem.active ? Font.DemiBold : Font.Normal
                            letterSpacing: 0.3
                        }
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }

                    // 当前页：一条橄榄色细线，不做胶囊
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        width: parent.width
                        height: 2
                        color: Theme.accent
                        opacity: navItem.active ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    }

                    MouseArea {
                        id: navMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pageChanged(root.navIds[index])
                    }
                }
            }
        }
    }
}
