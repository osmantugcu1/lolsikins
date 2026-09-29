import QtQuick 2.15
import QtQuick.Layouts 1.12
import QtQuick.Controls 2.15
import lolsikins.theme 1.0

NeonDialog {
    id: cslolDialogError
    title: I18n.t("errorTitle") + " - " + name
    glyph: ""
    maxWidth: 760

    property string name: ""
    property string message: ""
    property string log_data: ""

    onOpened: {
        logScroll.ScrollBar.vertical.position = 0
        window.show()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        Text {
            Layout.fillWidth: true
            text: cslolDialogError.message
            color: Neon.text
            font.pixelSize: 16
            wrapMode: Text.Wrap
        }

        Text {
            Layout.topMargin: 6
            text: I18n.t("details")
            color: Neon.primary
            font.pixelSize: 12
            font.bold: true
            font.letterSpacing: 2
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Neon.radiusSmall
            color: Neon.alpha(Neon.surface, 0.85)
            border.width: 1
            border.color: Neon.border

            ScrollView {
                id: logScroll
                anchors.fill: parent
                anchors.margins: 4
                clip: true
                ScrollBar.vertical: NeonScrollBar { }
                TextArea {
                    id: logTextArea
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.WrapAnywhere
                    text: cslolDialogError.log_data
                    color: Neon.textMuted
                    selectionColor: Neon.alpha(Neon.primary, 0.4)
                    font.family: "monospace"
                    font.pixelSize: 12
                    background: null
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: 12
            Item { Layout.fillWidth: true }
            NeonButton {
                outline: true
                glyph: ""
                text: I18n.t("copyDetails")
                onClicked: {
                    logTextArea.selectAll()
                    logTextArea.copy()
                    logTextArea.deselect()
                }
            }
            NeonButton {
                text: I18n.t("closeUpper")
                onClicked: cslolDialogError.close()
            }
        }
    }
}
