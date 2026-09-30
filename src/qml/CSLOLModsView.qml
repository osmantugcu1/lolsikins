import QtQuick 2.15
import QtQuick.Layouts 1.12
import QtQuick.Controls 2.15
import lolsikins.theme 1.0

ColumnLayout {
    id: cslolModsView
    spacing: 0

    property bool showImage: true

    property int columnCount: 1

    property bool isBussy: false

    property real rowHeight: 0

    property string search: ""

    signal modRemoved(string fileName)

    signal modExport(string fileName)

    signal modEdit(string fileName)

    signal importFile(string file)

    signal installFantomeZip()

    signal createNewMod()

    signal tryRefresh()

    signal openStore()

    // Tri-state of the "all mods" toggle, and counters for the header.
    property int allState: Qt.PartiallyChecked
    property int modCount: cslolModsViewModel.count + cslolModsViewModel2.count
    property int enabledCount: 0

    function addMod(fileName, info, enabled) {
        let infoData = {
            "FileName": fileName,
            "Name": info["Name"],
            "Version": info["Version"],
            "Description": info["Description"],
            "Author": info["Author"],
            "Home": info["Home"],
            "Heart": info["Heart"],
            "Image": CSLOLUtils.toFile("./installed/" + fileName + "/META/image.png"),
            "Enabled": enabled === true
        }
        if (searchMatches(infoData)) {
            cslolModsViewModel.append(infoData)
            resortMod_model(cslolModsViewModel.count - 1, cslolModsViewModel)
        } else {
            cslolModsViewModel2.append(infoData)
        }
        checkedUpdate()
    }

    function loadProfile(mods) {
        loadProfile_model(mods, cslolModsViewModel)
        loadProfile_model(mods, cslolModsViewModel2)
    }

    function updateModInfo(fileName, info) {
        let i0 = updateModInfo_model(fileName, info, cslolModsViewModel);
        if (i0 !== -1) {
            if (!searchMatches(info)) {
                cslolModsViewModel2.append(cslolModsViewModel.get(i0))
                cslolModsViewModel.remove(i0)
            } else {
                resortMod_model(i0, cslolModsViewModel)
            }
        }

        let i1 = updateModInfo_model(fileName, info, cslolModsViewModel2);
        if (i1 !== -1) {
            if (searchMatches(info)) {
                cslolModsViewModel.append(cslolModsViewModel2.get(i1))
                cslolModsViewModel2.remove(i1)
                resortMod_model(cslolModsViewModel.count - 1, cslolModsViewModel)
            }
        }
    }

    function saveProfile() {
        let mods = {}
        saveProfile_model(mods, cslolModsViewModel)
        saveProfile_model(mods, cslolModsViewModel2)
        return mods
    }

    function searchMatches(info) {
        return search == "" || info["Name"].toLowerCase().search(search) !== -1 || info["Description"].toLowerCase().search(search) !== -1
    }

    function searchUpdate() {
        let i = 0;
        while (i < cslolModsViewModel2.count) {
            let obj = cslolModsViewModel2.get(i)
            if (searchMatches(obj)) {
                cslolModsViewModel.append(obj);
                cslolModsViewModel2.remove(i, 1)
                resortMod_model(cslolModsViewModel.count - 1, cslolModsViewModel)
            } else {
                i++;
            }
        }
        let j = 0;
        while (j < cslolModsViewModel.count) {
            let obj2 = cslolModsViewModel.get(j)
            if (!searchMatches(obj2)) {
                cslolModsViewModel2.append(obj2)
                cslolModsViewModel.remove(j, 1)
            } else {
                j++;
            }
        }
    }

    function resortMod_model(index, model) {
        let info = model.get(index)
        for (let i = 0; i < index; i++) {
            if (model.get(i)["Name"].toLowerCase() >= info["Name"].toLowerCase()) {
                model.move(index, i, 1);
                return i;
            }
        }
        for (let j = model.count - 1; j > index; j--) {
            if (model.get(j)["Name"].toLowerCase() <= info["Name"].toLowerCase()) {
                model.move(index, j, 1);
                return j;
            }
        }
        return index;
    }

    function saveProfile_model(mods, model) {
        let modsCount = model.count
        for (let i = 0; i < modsCount; i++) {
            let obj = model.get(i)
            if(obj["Enabled"] === true) {
                mods[obj["FileName"]] = true
            }
        }
    }

    function loadProfile_model(mods, model) {
        let modsCount = model.count
        for(let i = 0; i < modsCount; i++) {
            let obj = model.get(i)
            model.setProperty(i, "Enabled", mods[obj["FileName"]] === true)
        }
        checkedUpdate()
    }

    function updateModInfo_model(fileName, info, model) {
        let modsCount = model.count
        for(let i = 0; i < modsCount; i++) {
            let obj = model.get(i)
            if (obj["FileName"] === fileName) {
                if (obj["Name"] !== info["Name"]) {
                    model.setProperty(i, "Name", info["Name"])
                }
                if (obj["Version"] !== info["Version"]) {
                    model.setProperty(i, "Version", info["Version"])
                }
                if (obj["Description"] !== info["Description"]) {
                    model.setProperty(i, "Description", info["Description"])
                }
                if (obj["Author"] !== info["Author"]) {
                    model.setProperty(i, "Author", info["Author"])
                }
                if (obj["Home"] !== info["Home"]) {
                    model.setProperty(i, "Home", info["Home"])
                }
                if (obj["Heart"] !== info["Heart"]) {
                    model.setProperty(i, "Heart", info["Heart"])
                }
                return i;
            }
        }
        return -1;
    }

    // Turns one mod on, used when a freshly built voice pack is installed.
    function enableMod(fileName) {
        for (let model of [cslolModsViewModel, cslolModsViewModel2]) {
            for (let i = 0; i < model.count; i++) {
                if (model.get(i)["FileName"] === fileName && !model.get(i)["Enabled"]) {
                    model.setProperty(i, "Enabled", true)
                }
            }
        }
        checkedUpdate()
    }

    function checkAll(doEnable) {
        checkAllInternal(doEnable)
        checkedUpdate()
    }

    function checkAllInternal(doEnable) {
        for(let i = 0; i < cslolModsViewModel.count; i++) {
            let obj = cslolModsViewModel.get(i)
            if (obj["Enabled"] !== doEnable) {
                cslolModsViewModel.setProperty(i, "Enabled", doEnable)
            }
        }
        for(let j = 0; j < cslolModsViewModel2.count; j++) {
            let obj = cslolModsViewModel2.get(j)
            if (obj["Enabled"] !== doEnable) {
                cslolModsViewModel2.setProperty(j, "Enabled", doEnable)
            }
        }
    }

    function checkedUpdate() {
        let enabled = 0
        for(let i = 0; i < cslolModsViewModel.count; i++) {
            if (cslolModsViewModel.get(i)["Enabled"]) {
                enabled++
            }
        }
        for(let j = 0; j < cslolModsViewModel2.count; j++) {
            if (cslolModsViewModel2.get(j)["Enabled"]) {
                enabled++
            }
        }
        enabledCount = enabled
        let total = cslolModsViewModel.count + cslolModsViewModel2.count
        allState = enabled === 0 ? Qt.Unchecked : enabled === total ? Qt.Checked : Qt.PartiallyChecked
    }

    function refreshedMods(mods) {
        for (let fileName in mods) {
            if (updateModInfo_model(fileName, mods[fileName], cslolModsViewModel) === -1) {
                if (updateModInfo_model(fileName, mods[fileName], cslolModsViewModel2) === -1) {
                    addMod(fileName, mods[fileName], false)
                }
            }
        }
        let i = 0;
        while (i < cslolModsViewModel2.count) {
            let obj = cslolModsViewModel2.get(i)
            if (!(obj["FileName"] in mods)) {
                cslolModsViewModel2.remove(i, 1)
            } else {
                i++;
            }
        }
        let j = 0;
        while (j < cslolModsViewModel.count) {
            let obj2 = cslolModsViewModel.get(j)
            if (!(obj2["FileName"] in mods)) {
                cslolModsViewModel.remove(j, 1)
            } else {
                j++;
            }
        }
        checkedUpdate()
    }

    ListModel {
        id: cslolModsViewModel
    }

    ListModel {
        id: cslolModsViewModel2
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        DropArea {
            id: fileDropArea
            anchors.fill: parent
            enabled: !isBussy
            onDropped: function(drop) {
                if (drop.hasUrls && drop.urls.length > 0) {
                    cslolModsView.importFile(CSLOLUtils.fromFile(drop.urls[0]))
                }
            }
        }

        // Shown while a file is dragged over the window.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 16
            z: 2
            visible: fileDropArea.containsDrag
            radius: Neon.radius
            color: Neon.alpha(Neon.primary, 0.08)
            border.width: 2
            border.color: Neon.primary
            Text {
                anchors.centerIn: parent
                text: I18n.t("dropHere")
                color: Neon.primary
                font.pixelSize: 18
                font.bold: true
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 14
            visible: cslolModsView.modCount === 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\uf1b2"
                font.family: "FontAwesome"
                font.pixelSize: 56
                color: Neon.alpha(Neon.primary, 0.8)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.t("emptyTitle")
                color: Neon.text
                font.pixelSize: 20
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.t("emptyHint")
                color: Neon.textMuted
                font.pixelSize: 13
            }
            NeonButton {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.t("openStore")
                glyph: "\uf07a"
                enabled: !isBussy
                onClicked: cslolModsView.openStore()
            }
        }

        GridView {
            id: cslolModsViewView
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.topMargin: 16
            clip: true
            visible: cslolModsView.modCount > 0
            cellWidth: (width - 4) / cslolModsView.columnCount
            cellHeight: 112
            model: cslolModsViewModel
            ScrollBar.vertical: NeonScrollBar { }

            delegate: Item {
                width: cslolModsViewView.cellWidth
                height: cslolModsViewView.cellHeight

                Rectangle {
                    id: card
                    anchors.fill: parent
                    anchors.rightMargin: 16
                    anchors.bottomMargin: 14
                    radius: Neon.radius
                    color: cardMouse.containsMouse ? Neon.surfaceHover : Neon.alpha(Neon.surface, 0.9)
                    border.width: model.Enabled ? 1.5 : 1
                    border.color: model.Enabled ? Neon.alpha(Neon.primary, 0.9) : cardMouse.containsMouse ? Neon.alpha(Neon.primary, 0.35) : Neon.border
                    opacity: isBussy ? 0.6 : 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    // Halo for enabled mods.
                    Rectangle {
                        visible: model.Enabled
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: Neon.radius + 4
                        color: "transparent"
                        border.width: 4
                        border.color: Neon.alpha(Neon.primary, 0.12)
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !isBussy
                        onClicked: {
                            cslolModsViewModel.setProperty(index, "Enabled", !model.Enabled)
                            cslolModsView.checkedUpdate()
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 14

                        Rectangle {
                            Layout.preferredWidth: 74
                            Layout.preferredHeight: 74
                            radius: Neon.radiusSmall
                            clip: true
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Neon.alpha(Neon.primary, 0.35) }
                                GradientStop { position: 1.0; color: Neon.alpha(Neon.secondary, 0.35) }
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: thumb.status !== Image.Ready
                                text: model.Name ? model.Name.charAt(0).toUpperCase() : "?"
                                color: Neon.text
                                font.pixelSize: 30
                                font.bold: true
                            }
                            Image {
                                id: thumb
                                anchors.fill: parent
                                source: model.Image
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                sourceSize.width: 148
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 3
                            Text {
                                Layout.fillWidth: true
                                text: model.Name ? model.Name : model.FileName
                                color: Neon.text
                                font.pixelSize: 15
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                // Store installs are named "<Champion> - <Skin>".
                                text: (model.FileName.indexOf(" - ") > 0 ? model.FileName.split(" - ")[0] + "  ·  " : "")
                                      + "v" + model.Version + (model.Author ? "  ·  " + model.Author : "")
                                color: model.Enabled ? Neon.primary : Neon.textMuted
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: model.Description ? model.Description : ""
                                color: Neon.textMuted
                                font.pixelSize: 12
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 8
                            NeonSwitch {
                                Layout.alignment: Qt.AlignHCenter
                                checked: model.Enabled
                                enabled: !isBussy
                                tip: I18n.t("enableMod")
                                onToggled: {
                                    cslolModsViewModel.setProperty(index, "Enabled", checked)
                                    cslolModsView.checkedUpdate()
                                }
                            }
                            NeonIconButton {
                                Layout.alignment: Qt.AlignHCenter
                                glyph: "\uf1f8"
                                size: 30
                                danger: true
                                tip: I18n.t("removeMod")
                                enabled: !isBussy
                                opacity: cardMouse.containsMouse || hovered ? 1 : 0.35
                                onClicked: {
                                    let modName = model.FileName
                                    cslolModsViewModel.remove(index, 1)
                                    cslolModsView.modRemoved(modName)
                                    cslolModsView.checkedUpdate()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Neon.border
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.margins: 16
        spacing: 12

        NeonTextField {
            Layout.fillWidth: true
            glyph: "\uf002"
            enabled: !isBussy || window.patcherRunning
            placeholderText: I18n.t("search")
            onTextEdited: {
                search = text.toLowerCase()
                searchUpdate()
            }
        }
        NeonButton {
            outline: true
            enabled: !isBussy && cslolModsView.modCount > 0
            glyph: cslolModsView.allState === Qt.Checked ? "\uf204" : "\uf205"
            text: cslolModsView.allState === Qt.Checked ? I18n.t("disableAll") : I18n.t("enableAll")
            onClicked: cslolModsView.checkAll(cslolModsView.allState !== Qt.Checked)
        }
        NeonIconButton {
            glyph: "\uf093"
            tip: I18n.t("importFile")
            enabled: !isBussy
            onClicked: cslolModsView.installFantomeZip()
        }
        NeonIconButton {
            glyph: "\uf021"
            tip: I18n.t("refresh")
            enabled: !isBussy
            onClicked: cslolModsView.tryRefresh()
        }
    }
}
