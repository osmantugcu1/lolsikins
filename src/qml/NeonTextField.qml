import QtQuick 2.15
import QtQuick.Controls 2.15
import lolsikins.theme 1.0

// Rounded text field with an optional leading glyph and a neon focus ring.
TextField {
    id: control
    property string glyph: ""

    selectByMouse: true
    color: Neon.text
    placeholderTextColor: Neon.textMuted
    selectionColor: Neon.alpha(Neon.primary, 0.4)
    selectedTextColor: Neon.text
    font.pixelSize: 13
    leftPadding: glyph !== "" ? 38 : 14
    rightPadding: 14
    topPadding: 0
    bottomPadding: 0
    implicitHeight: 40
    topInset: 0
    bottomInset: 0
    verticalAlignment: TextInput.AlignVCenter

    background: Rectangle {
        radius: height / 2
        color: Neon.alpha(Neon.surface, 0.85)
        border.width: control.activeFocus ? 1.5 : 1
        border.color: control.activeFocus ? Neon.primary : control.hovered ? Neon.alpha(Neon.primary, 0.45) : Neon.border
        Text {
            visible: control.glyph !== ""
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: control.glyph
            font.family: "FontAwesome"
            font.pixelSize: 14
            color: control.activeFocus ? Neon.primary : Neon.textMuted
        }
    }
}
