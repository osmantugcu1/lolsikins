import QtQuick 2.15
import QtQuick.Layouts 1.12
import QtQuick.Controls 2.15
import customskinlol.tools 1.0
import lolsikins.theme 1.0
import "Search.js" as Search

NeonDialog {
    id: cslolDialogSkinStore
    title: I18n.t("storeTitle")
    glyph: "\uf07a"

    property bool isBussy: false
    property alias repoAddress: repoField.text
    property alias repoBranch: branchField.text
    property alias repoToken: tokenField.text
    property alias autoUpdate: autoUpdateCheck.checked
    // JSON object of install name -> git blob sha of the installed copy.
    property string installedShas: "{}"

    // Every skin from the repository, filtered into skinsModel.
    property var allSkins: []
    // Installed mod names, used to mark skins that are already installed.
    property var installedNames: ({})
    // Skin being downloaded or installed: { skin, name, update, stage, localFile }.
    property var pending: null
    // Skins waiting for an automatic update.
    property var updateQueue: []
    property string statusText: ""

    signal installSkin(string localFile)
    signal updateSkin(string localFile, string name)

    function installName(skin) {
        return skin.champion + " - " + skin.name + (skin.chroma ? " (Chroma)" : "")
    }

    function shas() {
        try {
            return JSON.parse(installedShas) || {}
        } catch (e) {
            return {}
        }
    }

    function setSha(name, sha) {
        let result = shas()
        if (sha) {
            result[name] = sha
        } else {
            delete result[name]
        }
        installedShas = JSON.stringify(result)
    }

    function hasUpdate(skin) {
        let name = installName(skin)
        let sha = shas()[name]
        return (name in installedNames) && sha !== undefined && sha !== skin.sha
    }

    function setInstalled(names) {
        let result = {}
        for (let name in names) {
            result[name] = true
        }
        installedNames = result
    }

    function markInstalled(name, installed) {
        let result = Object.assign({}, installedNames)
        if (installed) {
            result[name] = true
        } else {
            delete result[name]
            setSha(name, "")
        }
        installedNames = result
    }

    function loadCatalog() {
        statusText = I18n.t("scanning")
        skinRepo.fetchCatalog(repoField.text, branchField.text, tokenField.text)
    }

    // Called at startup and by the timer, fetches the catalog without opening the dialog.
    function checkForUpdates() {
        if (autoUpdate && repoField.text.trim() !== "" && !skinRepo.busy && pending === null) {
            loadCatalog()
        }
    }

    // keepScroll: the catalog was only refreshed, so stay where the user was instead of jumping to the top.
    function applyFilter(keepScroll) {
        let scroll = skinsView.contentY
        let champion = championBox.currentIndex > 0 ? championBox.currentText : ""
        // Matching skins stay grouped by champion in catalog order, so chromas stay under their skin; the champion
        // with the best match comes first.
        let groups = []
        let groupOf = {}
        for (let i in allSkins) {
            let skin = allSkins[i]
            if (champion !== "" && skin.champion !== champion) {
                continue
            }
            if (!chromaCheck.checked && skin.chroma) {
                continue
            }
            let score = Search.score(searchField.text, skin.champion + " " + skin.name)
            if (score === 0) {
                continue
            }
            let group = groupOf[skin.champion]
            if (group === undefined) {
                group = groupOf[skin.champion] = { "index": groups.length, "best": 0, "skins": [] }
                groups.push(group)
            }
            group.best = Math.max(group.best, score)
            group.skins.push(skin)
        }
        groups.sort((a, b) => b.best - a.best || a.index - b.index)
        skinsModel.clear()
        for (let group of groups) {
            for (let skin of group.skins) {
                skinsModel.append(skin)
            }
        }
        if (keepScroll === true) {
            skinsView.forceLayout()
            skinsView.contentY = Math.max(skinsView.originY,
                                          Math.min(scroll, skinsView.originY + skinsView.contentHeight - skinsView.height))
        }
    }

    function formatSize(bytes) {
        if (bytes >= 1024 * 1024) {
            return (bytes / (1024 * 1024)).toFixed(1) + " MB"
        }
        return Math.max(1, Math.round(bytes / 1024)) + " KB"
    }

    function startDownload(skin, update) {
        pending = { "skin": skin, "name": installName(skin), "update": update, "stage": "download", "localFile": "" }
        skinRepo.download(skin.path, pending.name)
    }

    // Hands a downloaded skin to the mod tools once they are idle.
    function tryInstall() {
        if (pending === null || pending.stage !== "ready" || isBussy) {
            return
        }
        pending = Object.assign({}, pending, { "stage": "install" })
        statusText = I18n.t(pending.update ? "updating" : "installing").arg(pending.name)
        if (pending.update) {
            updateSkin(pending.localFile, pending.name)
        } else {
            installSkin(pending.localFile)
        }
    }

    // Called with the mod name when the tools report success, or with "" when they finished without it.
    function finishPending(name) {
        if (pending === null) {
            return
        }
        if (name === pending.name) {
            setSha(name, pending.skin.sha)
            statusText = I18n.t(pending.update ? "updatedDone" : "installedDone").arg(name)
        } else {
            statusText = I18n.t("failedDone").arg(pending.name)
        }
        // The rows follow installedNames and installedShas by binding, so the list is not rebuilt here: rebuilding
        // it scrolled the store back to the top after every install.
        pending = null
        processQueue()
    }

    function abortPending() {
        pending = null
        updateQueue = []
        statusText = I18n.t("needGame")
    }

    function processQueue() {
        if (pending !== null || skinRepo.busy || updateQueue.length === 0) {
            return
        }
        let queue = updateQueue.slice()
        let skin = queue.shift()
        updateQueue = queue
        statusText = I18n.t("updateDownloading").arg(installName(skin))
        startDownload(skin, true)
    }

    function modInstalled(name) {
        markInstalled(name, true)
        if (pending !== null && pending.stage === "install" && !pending.update) {
            finishPending(name)
        }
    }

    function modUpdated(name) {
        if (pending !== null && pending.stage === "install" && pending.update) {
            finishPending(name)
        }
    }

    onIsBussyChanged: {
        if (!isBussy) {
            // Tools went idle while installing without reporting success: the install failed.
            if (pending !== null && pending.stage === "install") {
                finishPending("")
            }
            Qt.callLater(tryInstall)
            Qt.callLater(processQueue)
        }
    }

    onOpened: {
        if (allSkins.length === 0 && repoField.text.trim() !== "" && !skinRepo.busy) {
            loadCatalog()
        }
    }

    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: autoUpdateCheck.checked
        onTriggered: checkForUpdates()
    }

    CSLOLSkinRepo {
        id: skinRepo
        onCatalogLoaded: function(skins, truncated) {
            // "" is the "all champions" entry, labelled in the current language by championBox.
            let champions = [ "" ]
            for (let i in skins) {
                if (champions.indexOf(skins[i].champion) === -1) {
                    champions.push(skins[i].champion)
                }
            }
            let previous = championBox.currentText
            allSkins = skins
            championBox.model = champions
            championBox.currentIndex = Math.max(0, champions.indexOf(previous))

            // Skins installed before their sha was known are assumed to be current.
            let known = shas()
            let updates = []
            for (let i in skins) {
                let name = installName(skins[i])
                if (!(name in installedNames)) {
                    continue
                }
                if (known[name] === undefined) {
                    setSha(name, skins[i].sha)
                } else if (autoUpdate && known[name] !== skins[i].sha) {
                    updates.push(skins[i])
                }
            }
            applyFilter(true)

            if (skins.length === 0) {
                statusText = I18n.t("noFantome")
            } else {
                statusText = I18n.t("skinsFound").arg(skins.length)
                if (truncated) {
                    statusText += " " + I18n.t("truncated")
                }
            }
            if (updates.length > 0) {
                updateQueue = updateQueue.concat(updates)
                processQueue()
            }
        }
        onCatalogFailed: function(message) {
            statusText = I18n.message(message)
            processQueue()
        }
        onDownloadProgress: function(path, received, total) {
            if (pending === null) {
                return
            }
            let size = total > 0 ? formatSize(received) + " / " + formatSize(total) : formatSize(received)
            statusText = I18n.t("downloading").arg(pending.name).arg(size)
        }
        onDownloaded: function(path, localFile) {
            pending = Object.assign({}, pending, { "stage": "ready", "localFile": localFile })
            statusText = I18n.t("downloadedWaiting").arg(pending.name)
            tryInstall()
        }
        onDownloadFailed: function(path, message) {
            statusText = I18n.message(message)
            pending = null
            processQueue()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: 10
            NeonTextField {
                id: repoField
                Layout.fillWidth: true
                Layout.preferredWidth: 3
                glyph: "\uf09b"
                // Default store; a repository saved in config.ini replaces it.
                text: "bettie9/LeagueSkins"
                placeholderText: I18n.t("repoPlaceholder")
                onAccepted: loadCatalog()
            }
            NeonTextField {
                id: branchField
                Layout.preferredWidth: 120
                glyph: "\uf126"
                placeholderText: "main"
                onAccepted: loadCatalog()
            }
            NeonTextField {
                id: tokenField
                Layout.fillWidth: true
                Layout.preferredWidth: 2
                glyph: "\uf084"
                placeholderText: I18n.t("tokenPlaceholder")
                echoMode: TextInput.Password
                onAccepted: loadCatalog()
            }
            NeonButton {
                text: I18n.t("connect")
                glyph: "\uf0c1"
                enabled: !skinRepo.busy && repoField.text.trim() !== ""
                onClicked: loadCatalog()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: 10
            NeonComboBox {
                id: championBox
                Layout.preferredWidth: 220
                model: [ "" ]
                labelOf: function(champion) { return champion === "" ? I18n.t("allChampions") : champion }
                onActivated: applyFilter()
            }
            NeonTextField {
                id: searchField
                Layout.fillWidth: true
                glyph: "\uf002"
                placeholderText: I18n.t("search")
                onTextChanged: applyFilter()
            }
            Text {
                text: I18n.t("chromas")
                color: Neon.textMuted
                font.pixelSize: 13
            }
            NeonSwitch {
                id: chromaCheck
                checked: true
                onToggled: applyFilter()
            }
            Text {
                Layout.leftMargin: 6
                text: I18n.t("autoUpdate")
                color: Neon.textMuted
                font.pixelSize: 13
            }
            NeonSwitch {
                id: autoUpdateCheck
                checked: true
                onToggled: checkForUpdates()
            }
        }

        ListView {
            id: skinsView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: ListModel {
                id: skinsModel
            }
            ScrollBar.vertical: NeonScrollBar { }

            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: skinsModel.count === 0
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\uf09b"
                    font.family: "FontAwesome"
                    font.pixelSize: 48
                    color: Neon.alpha(Neon.primary, 0.7)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(skinsView.width - 40, 460)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: allSkins.length > 0 ? I18n.t("storeNoMatch") : I18n.t("storeEmpty")
                    color: Neon.textMuted
                    font.pixelSize: 14
                }
            }

            delegate: Rectangle {
                id: skinRow
                property string name: installName(model)
                property bool installed: name in cslolDialogSkinStore.installedNames
                property bool outdated: installed && cslolDialogSkinStore.installedShas !== "" && hasUpdate(model)
                property bool active: pending !== null && pending.name === name

                // Chromas are indented under their skin; the width shrinks with the indent so their button stays
                // inside the list instead of being cut off at the right edge.
                x: model.chroma ? 28 : 0
                width: skinsView.width - 14 - x
                height: 60
                radius: Neon.radiusSmall
                color: rowMouse.containsMouse ? Neon.surfaceHover : Neon.alpha(Neon.surface, 0.85)
                border.width: 1
                border.color: active ? Neon.primary : outdated ? Neon.alpha(Neon.secondary, 0.8)
                            : installed ? Neon.alpha(Neon.primary, 0.45) : Neon.border

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
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: model.chroma ? 10 : 34
                        Layout.preferredHeight: model.chroma ? 10 : 34
                        radius: model.chroma ? 5 : 10
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Neon.alpha(Neon.primary, model.chroma ? 1 : 0.4) }
                            GradientStop { position: 1.0; color: Neon.alpha(Neon.secondary, model.chroma ? 1 : 0.4) }
                        }
                        Text {
                            visible: !model.chroma
                            anchors.centerIn: parent
                            text: model.champion.charAt(0).toUpperCase()
                            color: Neon.text
                            font.pixelSize: 15
                            font.bold: true
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            Layout.fillWidth: true
                            text: model.chroma ? model.variant : model.name
                            color: Neon.text
                            font.pixelSize: 14
                            font.bold: !model.chroma
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: model.champion + (model.chroma ? "  ·  Chroma" : "") + "  ·  " + formatSize(model.size)
                            color: Neon.textMuted
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                    NeonButton {
                        implicitHeight: 34
                        outline: installed && !outdated
                        glyph: active ? "\uf110" : outdated ? "\uf021" : installed ? "\uf00c" : "\uf019"
                        text: active ? I18n.t("working") : outdated ? I18n.t("update")
                                     : installed ? I18n.t("isInstalled") : I18n.t("install")
                        enabled: (!installed || outdated) && pending === null && !skinRepo.busy && !cslolDialogSkinStore.isBussy
                        onClicked: {
                            let skin = allSkins.find(s => s.path === model.path)
                            if (skin !== undefined) {
                                startDownload(skin, outdated)
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: 10
            Text {
                Layout.fillWidth: true
                text: statusText
                color: Neon.textMuted
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
            NeonButton {
                visible: skinRepo.busy
                implicitHeight: 32
                outline: true
                danger: true
                text: I18n.t("cancel")
                onClicked: skinRepo.cancel()
            }
        }
    }
}
