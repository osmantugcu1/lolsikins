import QtQuick 2.15
import QtQuick.Layouts 1.12
import QtQuick.Controls 2.15
import lolsikins.theme 1.0

// Modal panel with a neon frame, a title and a close button.
Popup {
    id: root

    property string title: ""
    property string glyph: ""
    property int maxWidth: 960
    default property alias content: body.data

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    anchors.centerIn: Overlay.overlay
    width: Math.min(parent.width - 48, maxWidth)
    height: parent.height - 48
    padding: 0

    Overlay.modal: Rectangle {
        color: "#D005050C"
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 }
        NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: 160; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
    }

    background: Item {
        Rectangle {
            anchors.fill: parent
            anchors.margins: -5
            radius: 23
            color: "transparent"
            border.width: 5
            border.color: Neon.alpha(Neon.primary, 0.08)
        }
        Rectangle {
            anchors.fill: parent
            radius: 18
            color: Neon.bg2
            border.width: 1
            border.color: Neon.alpha(Neon.primary, 0.45)
        }
    }

    // Anchors instead of a ColumnLayout: a relayout triggered by text size changes (e.g. switching
    // language) could leave the body squeezed at a stale position.
    contentItem: Item {
        RowLayout {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 24
            anchors.rightMargin: 14
            anchors.topMargin: 14
            height: 38
            spacing: 12
            Text {
                visible: root.glyph !== ""
                text: root.glyph
                font.family: "FontAwesome"
                font.pixelSize: 20
                color: Neon.primary
            }
            Text {
                Layout.fillWidth: true
                text: root.title
                color: Neon.text
                font.pixelSize: 20
                font.bold: true
                font.letterSpacing: 0.5
                elide: Text.ElideRight
            }
            NeonIconButton {
                glyph: "\uf00d"
                tip: I18n.t("close")
                onClicked: root.close()
            }
        }
        Rectangle {
            id: divider
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.topMargin: 10
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Neon.alpha(Neon.primary, 0.6) }
                GradientStop { position: 1.0; color: Neon.alpha(Neon.secondary, 0.0) }
            }
        }
        Item {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: divider.bottom
            anchors.bottom: parent.bottom
            anchors.margins: 24
        }
    }
}
