import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    implicitHeight: 44
    implicitWidth: 400

    property string windowTitle: "Mass"

    signal minimizeRequested()
    signal closeRequested()

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onPressed: root.Window.window.startSystemMove()
            // 双击不响应（因为已取消最大化）
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 18; rightMargin: 14 }
            spacing: 0

            Text {
                text: "◈"
                color: Theme.accent
                font.pixelSize: Theme.fs(16)
            }

            Text {
                Layout.leftMargin: 10
                text: root.windowTitle
                color: Theme.text
                font { family: Theme.fontFamily; pixelSize: Theme.fs(13); letterSpacing: 1 }
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 8

                // 最小化 —— 黄色圆点
                Rectangle {
                    width: 14; height: 14; radius: 7
                    color: "#febc2e"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.minimizeRequested()
                    }
                }

                // 最大化 —— 黑色圆点，禁用
                Rectangle {
                    width: 14; height: 14; radius: 7
                    color: "#1a1a1a"
                    border.color: "#333333"
                    border.width: 1

                    // 无 MouseArea → 不可点击
                }

                // 关闭 —— 红色圆点
                Rectangle {
                    width: 14; height: 14; radius: 7
                    color: "#ff5f57"

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }
        }
    }
}