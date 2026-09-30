import QtQuick 2.15
import QtQuick.Layouts 1.12
import QtQuick.Controls 2.15
import lolsikins.theme 1.0

NeonDialog {
    id: cslolDialogSettings
    title: I18n.t("settingsTitle")
    glyph: ""
    maxWidth: 720

    property bool isBussy: false
    property string gamePath: ""
    property alias detectGamePath: detectGamePathCheck.checked
    property alias blacklist: blacklistCheck.checked
    property alias ignorebad: ignorebadCheck.checked
    property alias skinhackScan: skinhackScanCheck.checked
    property alias suppressInstallConflicts: suppressInstallConflictsCheck.checked
    property alias enableSystray: enableSystrayCheck.checked
    property alias enableAutoRun: enableAutoRunCheck.checked
    property alias debugPatcher: debugPatcherCheck.checked
    property alias language: languageBox.currentIndex
    property alias neonPreset: themeBox.currentIndex
    property alias voiceLanguage: voiceBox.currentIndex
    // Voice pack build state, driven by main.qml.
    property bool voiceBusy: false
    property string voiceStatus: ""
    property real voiceFraction: 0

    signal changeGamePath()
    signal runDiag()
    signal buildVoice(string locale, string name)
    signal cancelVoice()

    component SectionTitle: Text {
        Layout.fillWidth: true
        Layout.topMargin: 10
        color: Neon.primary
        font.pixelSize: 12
        font.bold: true
        font.letterSpacing: 2
    }

    component SettingRow: Rectangle {
        id: settingRow
        property string label: ""
        default property alias control: slot.data
        Layout.fillWidth: true
        implicitHeight: 56
        radius: Neon.radiusSmall
        color: rowMouse.containsMouse ? Neon.surfaceHover : Neon.alpha(Neon.surface, 0.8)
        border.width: 1
        border.color: Neon.border
        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 12
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: settingRow.label
                color: Neon.text
                font.pixelSize: 14
                elide: Text.ElideRight
            }
            Row {
                id: slot
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: settingsColumn.implicitHeight
        clip: true
        ScrollBar.vertical: NeonScrollBar { }

        ColumnLayout {
            id: settingsColumn
            width: parent.width - 16
            spacing: 10

            SectionTitle { text: I18n.t("sectionApp") }
            SettingRow {
                label: I18n.t("language")
                NeonComboBox {
                    id: languageBox
                    width: 220
                    model: I18n.languages
                    currentIndex: 0
                }
            }
            SettingRow {
                label: I18n.t("theme")
                NeonComboBox {
                    id: themeBox
                    width: 260
                    model: Neon.presets
                    labelOf: function(preset) { return I18n.t(preset.key) }
                    currentIndex: 0
                }
            }
            SettingRow {
                label: I18n.t("systray")
                NeonSwitch { id: enableSystrayCheck; checked: false }
            }
            SettingRow {
                label: I18n.t("autoRun")
                NeonSwitch { id: enableAutoRunCheck; checked: false }
            }

            SectionTitle { text: I18n.t("sectionGame") }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 68
                radius: Neon.radiusSmall
                color: Neon.alpha(Neon.surface, 0.8)
                border.width: 1
                border.color: Neon.border
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: I18n.t("gameFolder")
                            color: Neon.text
                            font.pixelSize: 14
                        }
                        Text {
                            Layout.fillWidth: true
                            text: cslolDialogSettings.gamePath !== "" ? cslolDialogSettings.gamePath : I18n.t("gameFolderNone")
                            color: Neon.textMuted
                            font.pixelSize: 12
                            elide: Text.ElideMiddle
                        }
                    }
                    NeonButton {
                        text: I18n.t("change")
                        outline: true
                        implicitHeight: 34
                        enabled: !isBussy
                        onClicked: cslolDialogSettings.changeGamePath()
                    }
                }
            }
            SettingRow {
                label: I18n.t("detectGame")
                NeonSwitch { id: detectGamePathCheck; checked: true }
            }
            SettingRow {
                label: I18n.t("blacklist")
                NeonSwitch { id: blacklistCheck; checked: true }
            }
            SettingRow {
                label: I18n.t("suppressConflicts")
                NeonSwitch { id: suppressInstallConflictsCheck; checked: false }
            }
            SettingRow {
                label: I18n.t("ignoreBad")
                NeonSwitch { id: ignorebadCheck; checked: false }
            }
            SettingRow {
                label: I18n.t("skinhackScan")
                NeonSwitch { id: skinhackScanCheck; checked: false }
            }

            SectionTitle { text: I18n.t("sectionVoice") }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: voiceContent.implicitHeight + 28
                radius: Neon.radiusSmall
                color: Neon.alpha(Neon.surface, 0.8)
                border.width: 1
                border.color: Neon.border
                Column {
                    id: voiceContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 14
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 10
                    RowLayout {
                        width: parent.width
                        spacing: 12
                        Text {
                            Layout.fillWidth: true
                            text: I18n.t("voiceLanguage")
                            color: Neon.text
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }
                        NeonComboBox {
                            id: voiceBox
                            Layout.preferredWidth: 240
                            model: I18n.voiceLanguages
                            labelOf: function(entry) { return I18n.voiceName(entry) }
                            enabled: !voiceBusy
                            currentIndex: 0
                        }
                        NeonButton {
                            implicitHeight: 34
                            outline: voiceBusy
                            danger: voiceBusy
                            glyph: voiceBusy ? "" : ""
                            text: voiceBusy ? I18n.t("cancel") : I18n.t("voiceDownload")
                            onClicked: {
                                if (voiceBusy) {
                                    cslolDialogSettings.cancelVoice()
                                } else {
                                    let entry = I18n.voiceLanguages[voiceBox.currentIndex]
                                    cslolDialogSettings.buildVoice(entry.code, I18n.voiceName(entry))
                                }
                            }
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: 6
                        visible: voiceBusy
                        radius: 3
                        color: Neon.alpha(Neon.primary, 0.15)
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, voiceFraction))
                            height: parent.height
                            radius: 3
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Neon.primary }
                                GradientStop { position: 1.0; color: Neon.secondary }
                            }
                        }
                    }
                    Text {
                        width: parent.width
                        visible: voiceStatus !== ""
                        text: voiceStatus
                        color: Neon.text
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                    Text {
                        width: parent.width
                        text: I18n.t("voiceHint")
                        color: Neon.textMuted
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                }
            }

            SectionTitle { text: I18n.t("sectionHelp") }
            SettingRow {
                label: I18n.t("verbose")
                NeonSwitch { id: debugPatcherCheck; checked: false }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.bottomMargin: 8
                spacing: 12
                NeonButton {
                    Layout.fillWidth: true
                    outline: true
                    glyph: ""
                    text: I18n.t("logs")
                    onClicked: Qt.openUrlExternally(CSLOLUtils.toFile("./log.txt"))
                }
                NeonButton {
                    Layout.fillWidth: true
                    outline: true
                    glyph: ""
                    text: I18n.t("diag")
                    enabled: !isBussy
                    onClicked: cslolDialogSettings.runDiag()
                }
            }
        }
    }
}
