import QtQuick 2.15
import QtQuick.Controls 2.15
import lolsikins.theme 1.0

// Rounded drop-down matching the neon text fields.
ComboBox {
    id: control

    // Optional function turning a model entry into its label. Use it for translated labels: changing
    // the model itself would reset currentIndex.
    property var labelOf: null
    implicitHeight: 40
    topInset: 0
    bottomInset: 0
    font.pixelSize: 13

    contentItem: Text {
        leftPadding: 16
        rightPadding: 36
        text: control.labelOf && control.currentIndex >= 0 ? control.labelOf(control.model[control.currentIndex])
                                                            : control.displayText
        font: control.font
        color: Neon.text
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        x: control.width - width - 16
        y: (control.height - height) / 2
        text: ""
        font.family: "FontAwesome"
        font.pixelSize: 16
        color: control.hovered || control.popup.visible ? Neon.primary : Neon.textMuted
    }

    background: Rectangle {
        radius: height / 2
        color: Neon.alpha(Neon.surface, 0.85)
        border.width: control.popup.visible ? 1.5 : 1
        border.color: control.popup.visible ? Neon.primary : control.hovered ? Neon.alpha(Neon.primary, 0.45) : Neon.border
    }

    delegate: ItemDelegate {
        width: control.width - 8
        highlighted: control.highlightedIndex === index
        contentItem: Text {
            text: control.labelOf ? control.labelOf(modelData)
                                  : control.textRole ? (Array.isArray(control.model) ? modelData[control.textRole] : model[control.textRole])
                                                     : modelData
            color: index === control.currentIndex ? Neon.primary : Neon.text
            font.pixelSize: 13
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 8
            color: highlighted ? Neon.alpha(Neon.primary, 0.14) : "transparent"
        }
    }

    popup: Popup {
        y: control.height + 6
        width: control.width
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 320)
        padding: 4
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollBar.vertical: NeonScrollBar { }
        }
        background: Rectangle {
            radius: 12
            color: Neon.surfaceRaised
            border.width: 1
            border.color: Neon.alpha(Neon.primary, 0.5)
        }
    }
}
