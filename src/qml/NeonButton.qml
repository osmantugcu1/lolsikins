import QtQuick 2.15
import QtQuick.Controls 2.15
import lolsikins.theme 1.0

// Pill button with a neon gradient and glow. outline gives a quieter variant.
AbstractButton {
    id: control

    property string glyph: ""
    property bool danger: false
    property bool outline: false
    property string tip: ""

    readonly property color colorA: danger ? Neon.danger : Neon.primary
    readonly property color colorB: danger ? "#FF8A3D" : Neon.secondary
    readonly property color labelColor: !enabled ? Neon.alpha(Neon.text, 0.35)
                                                 : outline ? (hovered ? Neon.text : colorA) : Neon.textOnNeon

    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    implicitHeight: 40
    implicitWidth: contentRow.implicitWidth + 36
    font.pixelSize: 13
    font.bold: true
    font.letterSpacing: 1.1

    ToolTip.visible: tip !== "" && hovered
    ToolTip.text: tip
    ToolTip.delay: 400

    contentItem: Item {
        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 8
            Text {
                visible: control.glyph !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: control.glyph
                font.family: "FontAwesome"
                font.pixelSize: control.font.pixelSize + 1
                color: control.labelColor
            }
            Text {
                visible: control.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: control.text
                font: control.font
                color: control.labelColor
            }
        }
    }

    background: Item {
        // Layered halos fake a blur glow without graphical effects.
        Repeater {
            model: control.enabled && !control.outline ? 3 : 0
            Rectangle {
                anchors.fill: parent
                anchors.margins: -(index + 1) * 3
                radius: height / 2
                color: "transparent"
                border.width: 3
                border.color: Neon.alpha(control.colorA, (control.hovered ? 0.22 : 0.10) / (index + 1))
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            opacity: control.enabled ? 1 : 0.35
            color: control.outline ? (control.hovered ? Neon.alpha(control.colorA, 0.14) : "transparent") : control.colorA
            gradient: control.outline ? null : fill
            border.width: control.outline ? 1.5 : 0
            border.color: Neon.alpha(control.colorA, control.hovered ? 1 : 0.7)
            Gradient {
                id: fill
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: control.colorA }
                GradientStop { position: 1.0; color: control.colorB }
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: "white"
            opacity: control.pressed ? 0.18 : (control.hovered && !control.outline ? 0.08 : 0)
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
    }
}
