import QtQuick 2.15
import QtQuick.Controls 2.15
import lolsikins.theme 1.0

// Round icon button (FontAwesome glyph) that lights up on hover.
AbstractButton {
    id: control

    property string glyph: ""
    property string tip: ""
    property bool danger: false
    property int size: 38
    readonly property color neon: danger ? Neon.danger : Neon.primary

    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    implicitWidth: size
    implicitHeight: size

    ToolTip.visible: tip !== "" && hovered
    ToolTip.text: tip
    ToolTip.delay: 400

    contentItem: Text {
        text: control.glyph
        font.family: "FontAwesome"
        font.pixelSize: Math.round(control.size * 0.42)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: !control.enabled ? Neon.alpha(Neon.textMuted, 0.4) : control.hovered ? control.neon : Neon.text
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    background: Rectangle {
        radius: width / 2
        color: control.pressed ? Neon.alpha(control.neon, 0.28) : control.hovered ? Neon.alpha(control.neon, 0.12) : "transparent"
        border.width: 1
        border.color: control.hovered && control.enabled ? Neon.alpha(control.neon, 0.7) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }
}
