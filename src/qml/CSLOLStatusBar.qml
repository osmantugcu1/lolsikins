import QtQuick 2.15
import lolsikins.theme 1.0

// Busy indicator: a neon streak running along the top edge plus the current status.
Item {
    id: root
    property string statusMessage: ""
    implicitHeight: 36
    clip: true

    Rectangle {
        anchors.fill: parent
        color: Neon.alpha(Neon.bg, 0.8)
    }
    Rectangle {
        id: streak
        height: 2
        width: root.width * 0.35
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Neon.alpha(Neon.primary, 0) }
            GradientStop { position: 0.5; color: Neon.primary }
            GradientStop { position: 1.0; color: Neon.alpha(Neon.secondary, 0) }
        }
        NumberAnimation on x {
            running: root.visible
            loops: Animation.Infinite
            from: -streak.width
            to: root.width
            duration: 1400
            easing.type: Easing.InOutQuad
        }
    }
    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        text: statusMessage
        color: Neon.textMuted
        font.pixelSize: 12
        elide: Text.ElideRight
    }
}
