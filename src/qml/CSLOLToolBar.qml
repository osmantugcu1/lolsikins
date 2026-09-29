import QtQuick 2.15
import QtQuick.Layouts 1.12
import QtQuick.Controls 2.15
import lolsikins.theme 1.0

Item {
    id: cslolToolBar
    implicitHeight: 72

    property bool isBussy: false
    // Profiles are kept for the backend, the UI always uses the selected one.
    property var profilesModel: []
    property int profilesCurrentIndex: 0
    readonly property string profilesCurrentName: profilesModel.length > profilesCurrentIndex
                                                  ? profilesModel[profilesCurrentIndex] : "Default Profile"
    property int modCount: 0
    property int enabledCount: 0

    signal openSideMenu()
    signal openSkinStore()
    signal saveProfileAndRun(bool run)
    signal stopProfile()

    Rectangle {
        anchors.fill: parent
        color: Neon.alpha(Neon.bg, 0.55)
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Neon.alpha(Neon.primary, 0.0) }
            GradientStop { position: 0.3; color: Neon.alpha(Neon.primary, 0.8) }
            GradientStop { position: 0.7; color: Neon.alpha(Neon.secondary, 0.8) }
            GradientStop { position: 1.0; color: Neon.alpha(Neon.secondary, 0.0) }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 12
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Neon.primary }
                GradientStop { position: 1.0; color: Neon.secondary }
            }
            Text {
                anchors.centerIn: parent
                text: ""
                font.family: "FontAwesome"
                font.pixelSize: 20
                color: Neon.textOnNeon
            }
        }
        Column {
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            Row {
                Text {
                    text: "LOL"
                    color: Neon.primary
                    font.pixelSize: 20
                    font.bold: true
                    font.letterSpacing: 3
                }
                Text {
                    text: "SIKINS"
                    color: Neon.secondary
                    font.pixelSize: 20
                    font.bold: true
                    font.letterSpacing: 3
                }
            }
            Text {
                text: window.patcherRunning ? I18n.t("skinsActive")
                                            : I18n.t("modSummary").arg(modCount).arg(enabledCount)
                color: window.patcherRunning ? Neon.success : Neon.textMuted
                font.pixelSize: 11
                font.letterSpacing: 0.5
            }
        }

        Item { Layout.fillWidth: true }

        NeonButton {
            text: I18n.t("store")
            glyph: ""
            outline: true
            onClicked: cslolToolBar.openSkinStore()
        }
        NeonIconButton {
            glyph: ""
            tip: I18n.t("settings")
            size: 40
            onClicked: cslolToolBar.openSideMenu()
        }
        NeonButton {
            Layout.preferredWidth: 150
            implicitHeight: 44
            text: window.patcherRunning ? I18n.t("stop") : I18n.t("start")
            glyph: window.patcherRunning ? "" : ""
            danger: window.patcherRunning
            enabled: !isBussy || window.patcherRunning
            tip: window.patcherRunning ? I18n.t("stopTip") : I18n.t("startTip")
            onClicked: {
                if (window.patcherRunning) {
                    cslolToolBar.stopProfile()
                } else {
                    cslolToolBar.saveProfileAndRun(true)
                }
            }
        }
    }
}
