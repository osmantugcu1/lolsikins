import QtQuick 2.15
import QtQuick.Controls 2.15
import lolsikins.theme 1.0

// On/off switch with a neon track.
AbstractButton {
    id: control
    checkable: true
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    implicitWidth: 46
    implicitHeight: 26

    property string tip: ""
    ToolTip.visible: tip !== "" && hovered
    ToolTip.text: tip
    ToolTip.delay: 400

    contentItem: Item { }

    background: Item {
        Rectangle {
            visible: control.checked
            anchors.fill: parent
            anchors.margins: -3
            radius: height / 2
            color: "transparent"
            border.width: 3
            border.color: Neon.alpha(Neon.primary, control.hovered ? 0.3 : 0.15)
        }
        Rectangle {
            id: track
            anchors.fill: parent
            radius: height / 2
            color: control.checked ? Neon.primary : Neon.surfaceRaised
            gradient: control.checked ? on : null
            border.width: control.checked ? 0 : 1
            border.color: control.hovered ? Neon.alpha(Neon.primary, 0.6) : Neon.border
            opacity: control.enabled ? 1 : 0.4
            Gradient {
                id: on
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Neon.primary }
                GradientStop { position: 1.0; color: Neon.secondary }
            }
        }
        Rectangle {
            width: control.height - 6
            height: width
            radius: width / 2
            y: 3
            x: control.checked ? control.width - width - 3 : 3
            color: control.checked ? "white" : Neon.textMuted
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
    }
}
