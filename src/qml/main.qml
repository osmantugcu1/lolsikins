import QtQuick 2.15
import QtQuick.Layouts 1.12
import QtQuick.Controls 2.15
import Qt.labs.settings 1.0
import Qt.labs.platform 1.0
import customskinlol.tools 1.0
import QtQuick.Controls.Material 2.15
import lolsikins.theme 1.0

ApplicationWindow {
    id: window
    visible: true
    width: 1120
    height: 720
    minimumHeight: 560
    minimumWidth: 820
    title: "LolSikins"
    font.pixelSize: 13

    Settings {
        id: settings
        property alias leaguePath: cslolTools.leaguePath

        property alias detectGamePath: cslolDialogSettings.detectGamePath
        property alias blacklist: cslolDialogSettings.blacklist
        property alias ignorebad: cslolDialogSettings.ignorebad
        property alias suppressInstallConflicts: cslolDialogSettings.suppressInstallConflicts
        property alias enableAutoRun: cslolDialogSettings.enableAutoRun
        property alias enableSystray: cslolDialogSettings.enableSystray
        property alias language: cslolDialogSettings.language
        property alias neonPreset: cslolDialogSettings.neonPreset
        property alias verbosePatcher: cslolDialogSettings.debugPatcher
        property alias skinhackScan: cslolDialogSettings.skinhackScan
        property alias voiceLanguage: cslolDialogSettings.voiceLanguage

        property alias removeUnknownNames: cslolDialogEditMod.removeUnknownNames
        property alias lastZipDirectory: cslolDialogOpenZipFantome.folder

        property alias skinRepoAddress: cslolDialogSkinStore.repoAddress
        property alias skinRepoBranch: cslolDialogSkinStore.repoBranch
        property alias skinRepoToken: cslolDialogSkinStore.repoToken
        property alias skinRepoAutoUpdate: cslolDialogSkinStore.autoUpdate
        property alias skinRepoShas: cslolDialogSkinStore.installedShas

        // Only the windowed size is remembered, a maximized size would reopen as an oversized window.
        property int windowHeight: 0
        property int windowWidth: 0
        property bool windowMaximised

        fileName: "config.ini"
    }

    property bool patcherRunning: cslolTools.state === CSLOLTools.StateRunning
    property bool isBussy: cslolTools.state !== CSLOLTools.StateIdle
    // A voice pack finished while the tools were busy; show it once they are idle again.
    property bool voicePending: false
    onIsBussyChanged: {
        if (!isBussy && voicePending) {
            cslolTools.refreshMods()
        }
    }
    property var validName: new RegExp(/[\p{L}\p{M}\p{Pd}\p{Z}\p{N}\w]{3,50}/u)
    property var validVersion: new RegExp(/([0-9]{1,3})(\.[0-9]{1,3}){0,3}/)
    property var validUrl: new RegExp(/^(http(s)?:\/\/).+$/u)
    property bool firstTick: false

    function showUserError(name, message) {
        cslolDialogUserError.text = message
        cslolDialogUserError.open()
    }

    function checkGamePath() {
        let detected = settings.detectGamePath ? CSLOLUtils.detectGamePath() : "";
        if (detected === "" && cslolTools.leaguePath === "") {
            cslolDialogGame.open();
            return false;
        }
        if (detected !== "") {
            cslolTools.leaguePath = detected;
        }
        return true;
    }

    onWidthChanged: {
        if (firstTick && window.visibility === ApplicationWindow.Windowed) {
            settings.windowWidth = width
        }
    }
    onHeightChanged: {
        if (firstTick && window.visibility === ApplicationWindow.Windowed) {
            settings.windowHeight = height
        }
    }

    onVisibilityChanged: {
        if (firstTick) {
            if (window.visibility === ApplicationWindow.Maximized) {
                if (settings.windowMaximised !== true) {
                    settings.windowMaximised = true;
                }
            }
            if (window.visibility === ApplicationWindow.Windowed) {
                if (settings.windowMaximised !== false) {
                    settings.windowMaximised = false;
                }
            }
        }
    }
    Binding {
        target: I18n
        property: "language"
        value: cslolDialogSettings.language
    }
    Binding {
        target: Neon
        property: "preset"
        value: cslolDialogSettings.neonPreset
    }

    // Leftover Material dialogs (errors, game folder) follow the neon palette too.
    Material.theme: Material.Dark
    Material.primary: Neon.primary
    Material.accent: Neon.primary
    Material.background: Neon.bg2
    Material.foreground: Neon.text

    background: NeonBackground { }

    header: CSLOLToolBar {
        id: cslolToolBar
        isBussy: window.isBussy
        modCount: cslolModsView.modCount
        enabledCount: cslolModsView.enabledCount

        profilesModel: [ "Default Profile" ]

        onOpenSideMenu: cslolDialogSettings.open()

        onSaveProfileAndRun: function(run) {
            if (run && cslolModsView.enabledCount === 0) {
                toast.show(I18n.t("noSkinEnabled"))
                return
            }
            let name = cslolToolBar.profilesCurrentName
            let mods = cslolModsView.saveProfile()
            if (checkGamePath()) {
                if (CSLOLUtils.checkGamePathAsia(cslolTools.leaguePath)) {
                    window.showUserError("Asian servers not supported", "因封禁，亚洲服不支持!")
                    return;
                }
                cslolTools.saveProfile(name, mods, run, settings.suppressInstallConflicts, settings.verbosePatcher,
                                       settings.skinhackScan)
            }
        }

        onStopProfile: function() {
            cslolTools.stopProfile()
        }

        onOpenSkinStore: cslolDialogSkinStore.open()
    }

    onClosing: {
        if (cslolTrayIcon.available && settings.enableSystray) {
            close.accepted = false
            window.hide()
        }
    }

    SystemTrayIcon {
        id: cslolTrayIcon
        visible: settings.enableSystray
        iconSource: "qrc:/icon.png"
        tooltip: "LolSikins"
        menu: Menu {
            MenuItem {
                text: !window.visible ? I18n.t("trayShow") : I18n.t("trayHide")
                onTriggered: window.visible ? window.hide() : window.show()
            }
            MenuItem {
                text: window.patcherRunning ? I18n.t("stop") : I18n.t("start")
                onTriggered: {
                    if (window.patcherRunning) {
                        cslolToolBar.stopProfile()
                    } else if (!window.isBussy) {
                        cslolToolBar.saveProfileAndRun(true)
                    }
                }
            }
            MenuItem {
                text: I18n.t("logs")
                onTriggered: Qt.openUrlExternally(CSLOLUtils.toFile("./log.txt"))
            }
            MenuItem {
                text: I18n.t("trayExit")
                onTriggered: Qt.quit()
            }
        }
        onActivated: {
            if (reason === SystemTrayIcon.Context) {
                menu.open()
            } else if(reason === SystemTrayIcon.DoubleClick) {
                window.show()
            }
        }
    }

    CSLOLDialogSettings {
        id: cslolDialogSettings
        isBussy: window.isBussy
        gamePath: cslolTools.leaguePath

        onRunDiag: cslolTools.runDiag()

        onChangeGamePath: function() {
            cslolDialogGame.open()
        }

        onBlacklistChanged: function() {
            cslolTools.changeBlacklist(blacklist)
        }

        onIgnorebadChanged: function() {
            cslolTools.changeIgnorebad(ignorebad)
        }

        onBuildVoice: function(locale, name) {
            voiceBusy = true
            voiceFraction = 0
            voiceStatus = I18n.t("voicePreparing")
            cslolTools.buildVoice(locale, I18n.t("voiceModName").arg(name))
        }

        onCancelVoice: cslolTools.cancelVoice()
    }

    CSLOLModsView {
        id: cslolModsView
        anchors.fill: parent
        isBussy: window.isBussy
        columnCount: Math.max(1, Math.floor(window.width / 520))

        onOpenStore: cslolDialogSkinStore.open()

        onModRemoved: function(fileName) {
            cslolTools.deleteMod(fileName)
        }
        onImportFile: function(file) {
            if (checkGamePath()) {
                cslolTools.installFantomeZip(file)
            }
        }
        onInstallFantomeZip: function() {
            if (checkGamePath()) {
                cslolDialogOpenZipFantome.open()
            }
        }
        onTryRefresh: cslolTools.refreshMods()
    }

    // Short notice above the bottom bar.
    Rectangle {
        id: toast
        function show(message) {
            toastText.text = message
            opacity = 1
            toastTimer.restart()
        }
        z: 100
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 96
        width: toastText.implicitWidth + 48
        height: 44
        radius: height / 2
        color: Neon.surfaceRaised
        border.width: 1
        border.color: Neon.primary
        opacity: 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Text {
            id: toastText
            anchors.centerIn: parent
            color: Neon.text
            font.pixelSize: 13
            font.bold: true
        }
        Timer {
            id: toastTimer
            interval: 2800
            onTriggered: toast.opacity = 0
        }
    }

    footer: CSLOLStatusBar {
        id: cslolStatusBar
        statusMessage: I18n.status(cslolTools.status)
        visible: window.isBussy
    }

    CSLOLDialogOpenZipFantome {
        id: cslolDialogOpenZipFantome
        onAccepted: function() {
            cslolTools.installFantomeZip(CSLOLUtils.fromFile(file))
        }
    }

    CSLOLDialogEditMod {
        id: cslolDialogEditMod
        visible: false
        enabled: !isBussy

        onChangeInfoData: function(infoData, image) {
            cslolTools.changeModInfo(fileName, infoData, image)
        }
        onRemoveWads: function(wads) {
            cslolTools.removeModWads(fileName, wads)
        }
        onAddWad: function(wad, removeUnknownNames) {
            if (checkGamePath()) {
                cslolTools.addModWad(fileName, wad, removeUnknownNames)
            }
        }
    }

    CSLOLDialogGame {
        id: cslolDialogGame
        onSelected: function(orgPath) {
            let path = CSLOLUtils.checkGamePath(orgPath)
            if (path === "") {
                window.showUserError("Bad game directory",  "There is no \"League of Legends.exe\" in " + orgPath)
            } else {
                cslolTools.leaguePath = path
                cslolDialogGame.close()
            }
        }
    }

    CSLOLDialogSkinStore {
        id: cslolDialogSkinStore
        isBussy: window.isBussy
        onInstallSkin: function(localFile) {
            if (checkGamePath()) {
                cslolTools.installFantomeZip(localFile)
            } else {
                cslolDialogSkinStore.abortPending()
            }
        }
        onUpdateSkin: function(localFile, name) {
            if (checkGamePath()) {
                cslolTools.updateFantomeZip(localFile, name)
            } else {
                cslolDialogSkinStore.abortPending()
            }
        }
    }

    CSLOLDialogError {
        id: cslolDialogError
    }

    CSLOLDialogErrorUser {
        id: cslolDialogUserError
    }

    CSLOLTools {
        id: cslolTools
        onInitialized: function(mods, profiles, profileName, profileMods) {
            cslolToolBar.profilesModel = profiles
            cslolToolBar.profilesCurrentIndex = 0
            for(let i in profiles) {
                if (profiles[i] === profileName) {
                    cslolToolBar.profilesCurrentIndex = i
                    break
                }
            }
            for(let fileName in mods) {
                cslolModsView.addMod(fileName, mods[fileName], fileName in profileMods)
            }
            cslolDialogSkinStore.setInstalled(mods)
            cslolDialogSkinStore.checkForUpdates()
            if(checkGamePath() && settings.enableAutoRun) {
                cslolToolBar.saveProfileAndRun(true)
            }
        }
        onModDeleted: function(name) {
            cslolDialogSkinStore.markInstalled(name, false)
        }
        onInstalledMod: function(fileName, infoData) {
            cslolModsView.addMod(fileName, infoData, false)
            cslolDialogSkinStore.modInstalled(fileName)
        }
        onUpdatedMod: function(fileName, infoData) {
            cslolModsView.updateModInfo(fileName, infoData)
            cslolDialogSkinStore.modUpdated(fileName)
        }
        onProfileSaved: {}
        onProfileLoaded: function(name, profileMods) {
            cslolModsView.loadProfile(profileMods)
        }
        onProfileDeleted: {
            let index = cslolToolBar.profilesCurrentIndex
            if (cslolToolBar.profilesModel.length > 1) {
                cslolToolBar.profilesModel.splice(index, 1)
                cslolToolBar.profilesModel = cslolToolBar.profilesModel
            } else {
                cslolToolBar.profilesModel = [ "Default Profile" ]
            }
            if (index > 0) {
                cslolToolBar.profilesCurrentIndex = index - 1
            } else {
                cslolToolBar.profilesCurrentIndex = 0
            }
        }
        onModCreated: function(fileName, infoData, image) {
            cslolModsView.addMod(fileName, infoData, false)
            cslolDialogEditMod.load(fileName, infoData, image, [], true)
            cslolDialogEditMod.open()
        }
        onModEditStarted: function(fileName, infoData, image, wads) {
            cslolDialogEditMod.load(fileName, infoData, image, wads, false)
            cslolDialogEditMod.open()
        }
        onModInfoChanged: function(fileName, infoData, image) {
            cslolModsView.updateModInfo(fileName, infoData)
            cslolDialogEditMod.infoDataChanged(infoData, image)
        }
        onModWadsAdded: function(fileName, wads) {
            cslolDialogEditMod.wadsAdded(wads)
        }
        onModWadsRemoved: function(fileName, wads) {
            cslolDialogEditMod.wadsRemoved(wads)
        }
        onRefreshed: function(mods) {
            cslolModsView.refreshedMods(mods)
            cslolDialogSkinStore.setInstalled(mods)
            if (voicePending && "LolSikins Voice" in mods) {
                voicePending = false
                cslolModsView.enableMod("LolSikins Voice")
            }
        }
        onVoiceProgress: function(line) {
            let progress = line.match(/^Voice progress: (\d+)\/(\d+) MB, (\d+)\/(\d+) files/)
            if (progress) {
                cslolDialogSettings.voiceFraction = progress[2] > 0 ? progress[1] / progress[2] : 0
                cslolDialogSettings.voiceStatus = I18n.t("voiceProgress")
                    .arg(progress[1]).arg(progress[2]).arg(progress[3]).arg(progress[4])
            }
        }
        onVoiceFinished: function(ok, message) {
            cslolDialogSettings.voiceBusy = false
            if (ok) {
                cslolDialogSettings.voiceStatus = I18n.t("voiceDone")
                voicePending = true
                if (!isBussy) {
                    cslolTools.refreshMods()
                }
            } else if (message.indexOf("already uses") !== -1) {
                cslolDialogSettings.voiceStatus = I18n.t("voiceSame")
            } else if (message === "voiceCanceled" || message === "voiceNeedGame") {
                cslolDialogSettings.voiceStatus = I18n.t(message)
            } else {
                cslolDialogSettings.voiceStatus = I18n.t("voiceFailed").arg(message)
            }
        }
        onUpdatedMods: function(mods) {
            cslolDialogUpdateMods.updatedMods = mods
            cslolDialogUpdateMods.open()
        }
        onReportError: function(name, message, trace) {
            // Patcher errors arrive as translation keys, anything else passes through unchanged.
            let text = I18n.message(message).trim()
            let log_data = "";
            if (trace) {
                log_data += trace.trim() + "\n"
            } else {
                log_data += text + "\n"
            }
            log_data += "name: " + name + "\n"
            log_data += "version: " + CSLOL_VERSION + "\n"
            cslolDialogError.name = name
            cslolDialogError.message = text
            cslolDialogError.log_data = log_data
            cslolDialogError.open()
        }
    }

    Component.onCompleted: {
        if (settings.windowWidth > 0 && settings.windowHeight > 0) {
            window.width = settings.windowWidth
            window.height = settings.windowHeight
        }
        if (settings.windowMaximised) {
            if (window.visibility !== ApplicationWindow.Maximized) {
                window.visibility = ApplicationWindow.Maximized;
            }
        }
        firstTick = true;
        cslolTools.init()
    }
}
