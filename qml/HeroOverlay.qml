import QtQuick
import QtQuick.Effects

Item {
    id: hero
    anchors.fill: parent
    visible: active
    enabled: false
    z: 9999

    property bool active: false
    property string imageUrl: ""
    property rect fromRect: Qt.rect(0, 0, 0, 0)
    property rect toRect: Qt.rect(0, 0, 0, 0)
    property real fromRadius: 10
    property real toRadius: 12
    property int duration: 420
    property bool shadowEnabled: true

    signal finished()

    function start(url, from, to, rFrom, rTo) {
        imageUrl = url
        fromRect = from
        toRect = to
        fromRadius = (rFrom !== undefined) ? rFrom : 10
        toRadius = (rTo !== undefined) ? rTo : 12

        item.x = from.x
        item.y = from.y
        item.width = from.width
        item.height = from.height
        item.coverRadius = fromRadius

        hero.opacity = 1.0
        active = true
        anim.restart()
    }

    Item {
        id: item
        property real coverRadius: 10

        // 阴影
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 8
            anchors.leftMargin: 4
            anchors.rightMargin: -4
            anchors.bottomMargin: -8
            radius: item.coverRadius
            color: Theme.shadowDeep
            opacity: hero.shadowEnabled ? 0.4 : 0
            z: -1
            enabled: false
            antialiasing: true
        }

        // 原图
        Image {
            id: img
            anchors.fill: parent
            source: hero.imageUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: true
            sourceSize.width: 1024
            sourceSize.height: 1024
            smooth: true
            mipmap: true
            visible: false
        }

        // 圆角遮罩形状
        Rectangle {
            id: maskItem
            anchors.fill: parent
            visible: false
            radius: item.coverRadius
            color: "white"
            antialiasing: true
            smooth: true
            layer.enabled: true
            layer.smooth: true
        }

        // 遮罩后的图片
        MultiEffect {
            anchors.fill: parent
            source: img
            maskEnabled: true
            maskSource: maskItem
            smooth: true
        }
    }

    // 位置 + 尺寸 + 圆角过渡
    ParallelAnimation {
        id: anim
        NumberAnimation { target: item; property: "x";           to: hero.toRect.x;     duration: hero.duration; easing.type: Easing.OutCubic }
        NumberAnimation { target: item; property: "y";           to: hero.toRect.y;     duration: hero.duration; easing.type: Easing.OutCubic }
        NumberAnimation { target: item; property: "width";       to: hero.toRect.width; duration: hero.duration; easing.type: Easing.OutCubic }
        NumberAnimation { target: item; property: "height";      to: hero.toRect.height;duration: hero.duration; easing.type: Easing.OutCubic }
        NumberAnimation { target: item; property: "coverRadius"; to: hero.toRadius;     duration: hero.duration; easing.type: Easing.OutCubic }
        onFinished: fadeOut.start()
    }

    // ★ 淡出，让目标大封面在同一时间淡入 —— 消除切换瞬间的闪烁
    NumberAnimation {
        id: fadeOut
        target: hero
        property: "opacity"
        from: 1.0
        to: 0.0
        duration: 150
        easing.type: Easing.OutCubic
        onStarted: hero.finished()       // 让父级立即把大封面 opacity 从 0 → 1
        onFinished: {
            hero.active = false
            hero.opacity = 1.0
        }
    }
}