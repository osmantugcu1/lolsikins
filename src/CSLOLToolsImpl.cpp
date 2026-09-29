#include "CSLOLToolsImpl.h"

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QMap>
#include <QMetaEnum>
#include <QNetworkReply>
#include <QStandardPaths>
#include <QThread>
#include <QTimer>
#include <QVersionNumber>
#include <algorithm>
#include <fstream>

#include "CSLOLUtils.h"
#include "CSLOLVersion.h"
#ifdef _WIN32
#    define DIAG_TOOL_EXE "/tools/diag.exe"
#    define MOD_TOOLS_EXE "/tools/mod-tools.exe"
#    define PATCHER_HOST_EXE "/patcher/ltk_patcher_host.exe"
#else
#    define DIAG_TOOL_EXE ""
#    define MOD_TOOLS_EXE "/tools/mod-tools"
#    define PATCHER_HOST_EXE "/patcher/ltk_patcher_host"
#endif

// Patcher errors are sent to QML as translation keys, arguments separated by \x1f.
static QString patcherMessage(QString key, QStringList args = {}) {
    args.prepend(key);
    return args.join(QChar(0x1f));
}

// The patcher is used from the user's own LTK Manager installation when it is present, because that copy is the
// genuine signed release and attaches to the game reliably. A copy bundled next to LolSikins is only a fallback.
static QString findPatcherHost(QString const& prog) {
    QStringList candidates;
#ifdef _WIN32
    for (auto const& base : {qEnvironmentVariable("ProgramFiles"),
                             qEnvironmentVariable("ProgramW6432"),
                             qEnvironmentVariable("LOCALAPPDATA") + "/Programs"}) {
        if (!base.isEmpty() && base != "/Programs") {
            candidates.append(QDir::fromNativeSeparators(base) + "/LTK Manager/ltk_patcher_host.exe");
        }
    }
#endif
    candidates.append(prog + PATCHER_HOST_EXE);
    for (auto const& candidate : candidates) {
        if (QFileInfo::exists(candidate)) {
            return candidate;
        }
    }
    return {};
}

CSLOLToolsImpl::CSLOLToolsImpl(QObject* parent) : QObject(parent), prog_(QCoreApplication::applicationDirPath()) {
    logFile_ = new QFile(prog_ + "/log.txt", this);
    logFile_->open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Unbuffered);
    logFile_->write("Version: " + QByteArray(CSLOL::VERSION) + "\n");
}

CSLOLToolsImpl::~CSLOLToolsImpl() {
    if (hostProcess_ != nullptr) {
        // Let the host detach cleanly; the QProcess destructor kills it if it does not exit in time.
        hostStopping_ = true;
        hostProcess_->write("stop\n");
        hostProcess_->closeWriteChannel();
        hostProcess_->waitForFinished(3000);
    }
    if (lockfile_) {
        delete lockfile_;
    }
}

CSLOLToolsImpl::CSLOLState CSLOLToolsImpl::getState() { return state_; }

void CSLOLToolsImpl::setState(CSLOLState value) {
    if (state_ != value) {
        state_ = value;
        emit stateChanged(value);
    }
}

void CSLOLToolsImpl::setStatus(QString status) {
    if (status_ != status) {
        logFile_->write((status.toUtf8() + "\n"));
        if (!status.startsWith("[WRN] ") && !status.startsWith("[DLL] ")) {
            status_ = status;
            emit statusChanged(status);
        }
    }
}

QString CSLOLToolsImpl::getLeaguePath() { return game_; }

/// util

static QJsonObject modInfoFixup(QString modName, QJsonObject object) {
    if (!object.contains("Name") || !object["Name"].isString() || object["Name"].toString().isEmpty()) {
        object["Name"] = modName;
    }
    if (!object.contains("Version") || !object["Version"].isString()) {
        object["Version"] = "0.0.0";
    }
    if (!object.contains("Author") || !object["Author"].isString()) {
        object["Author"] = "UNKNOWN";
    }
    if (!object.contains("Description") || !object["Description"].isString()) {
        object["Description"] = "";
    }
    if (!object.contains("Home") || !object["Home"].isString()) {
        object["Home"] = "";
    }
    if (!object.contains("Heart") || !object["Heart"].isString()) {
        object["Heart"] = "";
    }
    return object;
}

QStringList CSLOLToolsImpl::modList() {
    auto result = QStringList();
    for (auto it = QDirIterator(prog_ + "/installed", QDir::Dirs); it.hasNext();) {
        auto path = it.next();
        if (path.endsWith(".tmp")) continue;
        auto name = QFileInfo(path).fileName();
        if (name == "." || name == "..") continue;
        if (auto meta = QFileInfo(path + "/META/info.json"); !meta.exists()) continue;
        result.push_back(name);
    }
    result.sort(Qt::CaseInsensitive);
    return result;
}

QStringList CSLOLToolsImpl::modWadsList(QString modName) {
    auto result = QStringList();
    for (QDirIterator it(prog_ + "/installed/" + modName + "/WAD", {"*.wad.client"}, QDir::Files); it.hasNext();) {
        auto path = it.next();
        if (path.endsWith(".tmp")) continue;
        auto name = QFileInfo(path).fileName();
        result.push_back(name);
    }
    result.sort(Qt::CaseInsensitive);
    return result;
}

QJsonObject CSLOLToolsImpl::modInfoRead(QString modName) {
    auto data = QByteArray("{}", 2);
    if (QFile file(prog_ + "/installed/" + modName + "/META/info.json"); file.open(QIODevice::ReadOnly)) {
        data = file.readAll();
    }
    QJsonParseError error;
    auto document = QJsonDocument::fromJson(data, &error);
    if (!document.isObject()) {
        return modInfoFixup(modName, QJsonObject());
    }
    return modInfoFixup(modName, document.object());
}

bool CSLOLToolsImpl::modInfoWrite(QString modName, QJsonObject object) {
    QDir(prog_ + "/installed/" + modName).mkpath("META");
    auto data = QJsonDocument(modInfoFixup(modName, object)).toJson();
    if (QFile file(prog_ + "/installed/" + modName + "/META/info.json"); file.open(QIODevice::WriteOnly)) {
        file.write(data);
        return true;
    }
    return false;
}

QString CSLOLToolsImpl::modImageGet(QString modName) {
    auto path = prog_ + "/installed/" + modName + "/META/image.png";
    if (QFileInfo info(prog_); !info.exists()) {
        return "";
    }
    return path;
}

QString CSLOLToolsImpl::modImageSet(QString modName, QString image) {
    QDir(prog_ + "/installed/" + modName).mkpath("META");
    auto path = prog_ + "/installed/" + modName + "/META/image.png";
    if (image.isEmpty()) {
        QFile::remove(path);
        return "";
    }
    if (path == image) return path;
    if (QFile src(image); src.open(QIODevice::ReadOnly)) {
        if (QFile dst(path); dst.open(QIODevice::WriteOnly)) {
            dst.write(src.readAll());
            return path;
        }
    }
    return "";
}

QStringList CSLOLToolsImpl::listProfiles() {
    if (QDir dir(prog_); !dir.exists()) {
        dir.mkpath("profiles");
    }
    QStringList profiles;
    for (QDirIterator it(prog_ + "/profiles", QDir::Dirs); it.hasNext();) {
        auto info = QFileInfo(it.next());
        auto name = info.fileName();
        if (name == "." || name == "..") continue;
        profiles.push_back(name);
    }
    if (!profiles.contains("Default Profile")) {
        profiles.push_front("Default Profile");
    }
    return profiles;
}

QJsonObject CSLOLToolsImpl::readProfile(QString profileName) {
    QJsonObject profile;
    auto data = QString("");
    if (QFile file(prog_ + "/profiles/" + profileName + ".profile"); file.open(QIODevice::ReadOnly)) {
        data = QString::fromUtf8(file.readAll());
    }
    for (auto line : data.split('\n', Qt::SkipEmptyParts)) {
        profile.insert(line.remove('\n'), true);
    }
    return profile;
}

void CSLOLToolsImpl::writeProfile(QString profileName, QJsonObject profile) {
    QDir profilesDir(prog_);
    profilesDir.mkpath("profiles");
    if (QFile file(prog_ + "/profiles/" + profileName + ".profile"); file.open(QIODevice::WriteOnly)) {
        for (auto mod : profile.keys()) {
            auto data = mod.toUtf8();
            if (data.size() == 0) {
                continue;
            }
            data.push_back('\n');
            file.write(data);
        }
    }
}

QString CSLOLToolsImpl::readCurrentProfile() {
    auto data = QString("");
    if (QFile file(prog_ + "/current.profile"); file.open(QIODevice::ReadOnly)) {
        data = QString::fromUtf8(file.readAll()).remove('\n');
    }
    if (data.isEmpty()) {
        data = "Default Profile";
    }
    return data;
}

void CSLOLToolsImpl::writeCurrentProfile(QString profile) {
    if (QFile file(prog_ + "/current.profile"); file.open(QIODevice::WriteOnly)) {
        auto data = profile.toUtf8();
        data.push_back('\n');
        file.write(data);
    }
}

void CSLOLToolsImpl::doReportError(QString name, QString message, QString trace) {
    if (!name.isEmpty()) {
        logFile_->write("Error while: " + name.toUtf8() + "\n");
    }
    if (!message.isEmpty()) {
        logFile_->write(message.toUtf8() + "\n");
    }
    if (!trace.isEmpty()) {
        logFile_->write(trace.toUtf8() + "\n");
    }
    if (message.contains("OpenProcess: ") || trace.contains("OpenProcess: ")) {
        QFile file(prog_ + "/admin_allowed.txt");
        file.open(QIODevice::WriteOnly);
        file.close();
        trace += '\n';
        trace += ">>Run as administrator<< is now enabled!";
    }
    emit reportError(name, message, trace);
}

/// impl

void CSLOLToolsImpl::changeLeaguePath(QString newLeaguePath) {
    if (state_ == CSLOLState::StateIdle || state_ == CSLOLState::StateUnitialized) {
        if (state_ != CSLOLState::StateUnitialized) {
            setState(CSLOLState::StateBusy);
            setStatus("Change League Path");
        }

        if (auto info = QFileInfo(newLeaguePath + "/League of Legends.exe"); info.exists()) {
            newLeaguePath = info.canonicalPath();
        }
        if (auto info = QFileInfo(newLeaguePath + "/LeagueofLegends.app"); info.exists()) {
            newLeaguePath = info.canonicalPath();
        }
        if (game_ != newLeaguePath) {
            game_ = newLeaguePath;
            emit leaguePathChanged(newLeaguePath);
        }

        if (state_ != CSLOLState::StateUnitialized) {
            setState(CSLOLState::StateIdle);
        }
    }
}

void CSLOLToolsImpl::changeBlacklist(bool blacklist) {
    if (blacklist_ != blacklist) {
        blacklist_ = blacklist;
        emit blacklistChanged(blacklist);
    }
}

void CSLOLToolsImpl::changeIgnorebad(bool ignorebad) {
    if (ignorebad_ != ignorebad) {
        ignorebad_ = ignorebad;
        emit ignorebadChanged(ignorebad);
    }
}

void CSLOLToolsImpl::init() {
    if (state_ == CSLOLState::StateUnitialized) {
        setState(CSLOLState::StateBusy);

        if (QString error = CSLOLUtils::isPlatformUnsuported(); !error.isEmpty()) {
            doReportError("Unsupported platform",
                          error,
                          "Application launched on unsupported machine or configuration.");
            setState(CSLOLState::StateCriticalError);
            return;
        }

        hostProcess_ = nullptr;
        setStatus("Acquire lock");
        lockfile_ = new QLockFile(prog_ + "/lockfile");
        if (!lockfile_->tryLock()) {
            auto lockerror = QString::number((int)lockfile_->error());
            // Permission error (2) on macOS is likely due to App Translocation
            if (lockfile_->error() == QLockFile::PermissionError && CSLOLUtils::isTranslocated()) {
                doReportError("App Translocation Detected",
                              "macOS has placed the app in a read-only quarantine location.",
                              "Please close the app and relaunch it. This only happens on first launch.");
            } else {
                doReportError("Acquire lock", "Can not run multiple instances", lockerror);
            }
            setState(CSLOLState::StateCriticalError);
            return;
        }

        setStatus("Check mod-tools");
        if (QFileInfo modtools(prog_ + MOD_TOOLS_EXE); !modtools.exists()) {
            doReportError("Check mod-tools",
                          "Make sure you installed properly and that anti-virus isn't blocking any executables.",
                          "tools/mod-tools.exe is missing");
            setState(CSLOLState::StateCriticalError);
            return;
        }

        setStatus("Load mods");
        QJsonObject mods;
        for (auto name : modList()) {
            auto info = modInfoRead(name);
            mods.insert(name, info);
        }

        setStatus("Load profiles");
        auto profiles = listProfiles();
        auto profileName = readCurrentProfile();
        if (!profiles.contains(profileName)) {
            profileName = "Default Profile";
            writeCurrentProfile(profileName);
        }

        setStatus("Read profile");
        auto profileMods = readProfile(profileName);

        setStatus("Run diag");
        this->runDiagInternal(true);

        emit initialized(mods, QJsonArray::fromStringList(profiles), profileName, profileMods);

        setState(CSLOLState::StateIdle);
    }
}

void CSLOLToolsImpl::deleteMod(QString name) {
    if (state_ == CSLOLState::StateIdle) {
        setState(CSLOLState::StateBusy);

        setStatus("Delete mod");
        if (QDir dir(prog_ + "/installed/" + name); dir.removeRecursively()) {
            emit modDeleted(name);
        }

        setState(CSLOLState::StateIdle);
    }
}

void CSLOLToolsImpl::exportMod(QString name, QString dest) {
    if (state_ == CSLOLState::StateIdle) {
        setState(CSLOLState::StateBusy);

        setStatus("Export mod");
        runTool(
            {
                "export",
                prog_ + "/installed/" + name,
                dest,
                "--game:" + game_,
                blacklist_ ? "--noTFT" : "",
            },
            [this](int code, QProcess* process) { setState(CSLOLState::StateIdle); });
    }
}

void CSLOLToolsImpl::installFantomeZip(QString path) {
    if (state_ == CSLOLState::StateIdle && !path.isEmpty()) {
        setState(CSLOLState::StateBusy);

        setStatus("Installing Mod");
        auto name = QFileInfo(path)
                        .fileName()
                        .replace(".zip", "")
                        .replace(".fantome", "")
                        .replace(".wad", "")
                        .replace(".client", "");
        auto dst = prog_ + "/installed/" + name;
        if (QDir old(dst); old.exists()) {
            auto info = modInfoRead(name);
            doReportError("Install mod", "Already exists", "");
            setState(CSLOLState::StateIdle);
            return;
        }

        runTool(
            {
                "import",
                path,
                dst,
                "--game:" + game_,
                blacklist_ ? "--noTFT" : "",
            },
            [=, this](int code, QProcess* process) {
                if (code == 0) {
                    auto info = modInfoRead(name);
                    emit installedMod(name, info);
                }
                setState(CSLOLState::StateIdle);
            });
    }
}

void CSLOLToolsImpl::updateFantomeZip(QString path, QString name) {
    if (state_ == CSLOLState::StateIdle && !path.isEmpty() && !name.isEmpty()) {
        setState(CSLOLState::StateBusy);

        setStatus("Updating Mod");
        // import unpacks into a temporary folder and only then replaces the old mod.
        runTool(
            {
                "import",
                path,
                prog_ + "/installed/" + name,
                "--game:" + game_,
                blacklist_ ? "--noTFT" : "",
            },
            [=, this](int code, QProcess* process) {
                if (code == 0) {
                    emit updatedMod(name, modInfoRead(name));
                }
                setState(CSLOLState::StateIdle);
            });
    }
}

void CSLOLToolsImpl::makeMod(QString fileName, QJsonObject infoData, QString image) {
    if (state_ == CSLOLState::StateIdle) {
        setState(CSLOLState::StateBusy);

        setStatus("Make mod");
        if (!modInfoWrite(fileName, infoData)) {
            doReportError("Make mod", "Failed to write mod info", "");
        } else {
            infoData = modInfoFixup(fileName, infoData);
            image = modImageSet(fileName, image);
            emit modCreated(fileName, infoData, image);
        }

        setState(CSLOLState::StateIdle);
    }
}

void CSLOLToolsImpl::refreshMods() {
    if (state_ == CSLOLState::StateIdle) {
        setState(CSLOLState::StateBusy);

        QJsonObject mods;
        for (auto name : modList()) {
            auto info = modInfoRead(name);
            mods.insert(name, info);
        }
        emit refreshed(mods);

        setState(CSLOLState::StateIdle);
    }
}

void CSLOLToolsImpl::runDiag() {
    if (state_ == CSLOLState::StateIdle) {
        setState(CSLOLState::StateBusy);
        runDiagInternal(false);
        setState(CSLOLState::StateIdle);
    }
}

void CSLOLToolsImpl::saveProfile(QString name,
                                 QJsonObject mods,
                                 bool run,
                                 bool skipConflict,
                                 bool debugPatcher,
                                 bool skinhackScan) {
    if (state_ == CSLOLState::StateIdle) {
        setState(CSLOLState::StateBusy);

        setStatus("Save profile");
        if (name.isEmpty() || name.isNull()) {
            name = "Default Profile";
        }
        writeCurrentProfile(name);
        writeProfile(name, mods);
        emit profileSaved(name, mods);

        setStatus("Write profile");
        runTool(
            {
                "mkoverlay",
                prog_ + "/installed",
                prog_ + "/profiles/" + name,
                "--game:" + game_,
                "--mods:" + mods.keys().join('/'),
                blacklist_ ? "--noTFT" : "",
                skipConflict ? "--ignoreConflict" : "",
            },
            [=, this](int code, QProcess* process) {
                if (run && code == 0) {
                    setStatus("Starting patcher...");
                    runPatcher(prog_ + "/profiles/" + name, debugPatcher, skinhackScan);
                } else {
                    setState(CSLOLState::StateIdle);
                }
            });
    }
}

void CSLOLToolsImpl::loadProfile(QString name) {
    if (state_ == CSLOLState::StateIdle) {
        setState(CSLOLState::StateBusy);

        setStatus("Save profile");
        if (name.isEmpty() || name.isNull()) {
            name = "Default Profile";
        }
        auto profileMods = readProfile(name);
        emit profileLoaded(name, profileMods);

        setState(CSLOLState::StateIdle);
    }
}

void CSLOLToolsImpl::deleteProfile(QString name) {
    if (state_ == CSLOLState::StateIdle) {
        setState(CSLOLState::StateBusy);

        setStatus("Delete profile");
        if (QDir dir(prog_ + "/profiles/" + name); dir.removeRecursively()) {
            emit profileDeleted(name);
        }

        setState(CSLOLState::StateIdle);
    }
}

void CSLOLToolsImpl::stopProfile() {
    if (state_ == CSLOLState::StateRunning) {
        stopHost();
    }
}

void CSLOLToolsImpl::startEditMod(QString fileName) {
    if (state_ == CSLOLState::StateIdle) {
        setState(CSLOLState::StateBusy);

        setStatus("Edit mod");
        auto info = modInfoRead(fileName);
        auto image = modImageGet(fileName);
        auto wads = modWadsList(fileName);
        emit modEditStarted(fileName, info, image, QJsonArray::fromStringList(wads));

        setState(CSLOLState::StateIdle);
    }
}

void CSLOLToolsImpl::changeModInfo(QString fileName, QJsonObject infoData, QString image) {
    if (state_ == CSLOLState::StateIdle) {
        setState(CSLOLState::StateBusy);

        setStatus("Change mod info");
        if (!modInfoWrite(fileName, infoData)) {
            doReportError("Change mod info", "Failed to write mod info", "");
        } else {
            infoData = modInfoFixup(fileName, infoData);
            image = modImageSet(fileName, image);
            emit modInfoChanged(fileName, infoData, image);
        }

        setState(CSLOLState::StateIdle);
    }
}

void CSLOLToolsImpl::removeModWads(QString fileName, QJsonArray wads) {
    if (state_ == CSLOLState::StateIdle) {
        setState(CSLOLState::StateBusy);

        setStatus("Remove mod wads");
        auto result = QStringList();
        for (auto wadName : wads) {
            auto name = wadName.toString();
            if (QFile::remove(prog_ + "/installed/" + fileName + "/WAD/" + name)) {
                result.push_back(name);
            }
        }
        emit modWadsRemoved(fileName, QJsonArray::fromStringList(result));

        setState(CSLOLState::StateIdle);
    }
}

void CSLOLToolsImpl::addModWad(QString fileName, QString wad, bool removeUnknownNames) {
    if (state_ == CSLOLState::StateIdle) {
        setState(CSLOLState::StateBusy);

        setStatus("Add mod wads");
        auto before = modWadsList(fileName);
        runTool(
            {
                "addwad",
                wad,
                prog_ + "/installed/" + fileName,
                "--game:" + game_,
                removeUnknownNames ? "--removeUNK" : "",
                blacklist_ ? "--noTFT" : "",
            },
            [=, this](int code, QProcess* process) {
                if (code == 0) {
                    auto after = modWadsList(fileName);
                    auto done = QStringList();
                    for (auto wad : after) {
                        if (!before.contains(wad, Qt::CaseInsensitive)) {
                            done.push_back(wad);
                        }
                    }
                    emit modWadsAdded(fileName, QJsonArray::fromStringList(done));
                }
                setState(CSLOLState::StateIdle);
            });
    }
}

void CSLOLToolsImpl::runTool(QStringList args, std::function<void(int code, QProcess*)> handle) {
    auto process = new QProcess(this);
    connect(process, &QProcess::readyReadStandardOutput, this, [=, this]() {
        process->setReadChannel(QProcess::ProcessChannel::StandardOutput);
        while (process->canReadLine()) {
            auto line = process->readLine();
            setStatus(line.trimmed());
        }
    });
    connect(process,
            static_cast<void (QProcess::*)(int exitCode, QProcess::ExitStatus exitStatus)>(&QProcess::finished),
            this,
            [=, this](int exitCode, QProcess::ExitStatus exitStatus) {
                if (exitCode != 0) {
                    QString trace = process->readAllStandardError().trimmed();
                    doReportError("Run mod-tools", trace.split('\n').last(), trace);
                }
                handle(exitCode, process);
                process->deleteLater();
            });
    connect(process, &QProcess::errorOccurred, this, [=, this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            QString message = process->errorString();
            if (QFileInfo pathInfo(process->program()); !pathInfo.exists()) {
                message = "Make sure to install properly and that anti-virus isn't blocking executable.";
            }
            QString trace = "arguments:\n  " + args.join("\n  ").replace('\\', '/') + "\n";
            doReportError("Run mod-tools", message, trace);
            handle(-1, process);
            process->deleteLater();
        }
    });
    process->start(prog_ + MOD_TOOLS_EXE, args);
}

// Runs the patcher host from the patcher folder against the overlay built by mkoverlay. The host speaks a line
// protocol: we send "config ..." lines and "start scan" on stdin, it answers with "ok", "error",
// "status <ts> <state> <msg>" and "dll <ts> <pid> <tid> <level> <msg>" lines on stdout, and keeps scanning for the
// next game after one exits.
void CSLOLToolsImpl::runPatcher(QString overlayDir, bool debugPatcher, bool skinhackScan) {
    auto exe = findPatcherHost(prog_);
    if (exe.isEmpty()) {
        doReportError("Patcher", patcherMessage("errPatcherMissing"), prog_ + PATCHER_HOST_EXE);
        setState(CSLOLState::StateIdle);
        return;
    }
    logFile_->write("[patcher] host: " + exe.toUtf8() + "\n");

    hostStopping_ = false;
    lastHostError_.clear();
    auto process = hostProcess_ = new QProcess(this);
    process->setWorkingDirectory(QFileInfo(exe).absolutePath());

    connect(process, &QProcess::readyReadStandardOutput, this, [=, this]() {
        process->setReadChannel(QProcess::ProcessChannel::StandardOutput);
        while (process->canReadLine()) {
            handleHostLine(QString::fromUtf8(process->readLine()).trimmed());
        }
    });
    connect(process, &QProcess::readyReadStandardError, this, [=, this]() {
        logFile_->write("[patcher stderr] " + process->readAllStandardError());
    });
    connect(process, &QProcess::started, this, [=, this]() {
        setState(CSLOLState::StateRunning);
        setStatus("Waiting for league match to start");
        // Without the anti-skinhack setting the host gets OPT_OUT_AH_V1 (4): a failed scan is logged as a warning
        // instead of stopping the patcher. Some machines lose a lot of FPS with enforcement on.
        auto flags = skinhackScan ? 0 : 4;
        auto prefix = QDir::toNativeSeparators(QDir(overlayDir).absolutePath() + "/");
        for (auto const& command : {
                 QString("config loglevel %1").arg(debugPatcher ? 0x20 : 0x10),
                 QString("config flags %1").arg(flags),
                 "config prefix " + prefix,
                 QString("start scan"),
             }) {
            logFile_->write("[patcher] >> " + command.toUtf8() + "\n");
            process->write(command.toUtf8() + "\n");
        }
    });
    connect(process,
            static_cast<void (QProcess::*)(int exitCode, QProcess::ExitStatus exitStatus)>(&QProcess::finished),
            this,
            [=, this](int exitCode, QProcess::ExitStatus exitStatus) {
                logFile_->write("[patcher] host exited with " + QByteArray::number(exitCode) + "\n");
                if (!hostStopping_) {
                    doReportError("Patcher", patcherMessage("errPatcherExited", {lastHostError_}), "");
                }
                hostProcess_ = nullptr;
                process->deleteLater();
                setState(CSLOLState::StateIdle);
            });
    connect(process, &QProcess::errorOccurred, this, [=, this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            doReportError("Patcher", patcherMessage("errPatcherExited", {process->errorString()}), exe);
            hostProcess_ = nullptr;
            process->deleteLater();
            setState(CSLOLState::StateIdle);
        }
    });
    process->start(exe, QStringList{});
}

void CSLOLToolsImpl::handleHostLine(QString line) {
    if (line.isEmpty()) {
        return;
    }
    logFile_->write("[patcher] " + line.toUtf8() + "\n");

    auto parts = line.split(' ');
    auto keyword = parts.value(0);
    if (keyword == "status") {
        // status <timestamp> <state> <message...>
        auto state = parts.value(2);
        auto message = parts.mid(3).join(' ');
        if (state == "injecting") {
            setStatus(message == "game found" ? "Found League" : "Waiting for league match to start");
        } else if (state == "injected") {
            setStatus("Found League");
        } else if (state == "exited") {
            setStatus("League exited");
        } else if (state == "failed") {
            doReportError("Patcher", patcherMessage("errPatcherFailed", {message}), line);
            stopHost();
        }
    } else if (keyword == "error") {
        // error <timestamp> <message...>, kept as the reason if the host then dies.
        lastHostError_ = parts.mid(2).join(' ');
    } else if (keyword == "dll") {
        // dll <timestamp> <pid> <tid> <level> <message...>, the message may start with a "module::path: " target.
        auto level = parts.value(4);
        auto message = parts.mid(5).join(' ');
        if (auto split = message.indexOf(": "); split > 0) {
            auto target = message.left(split);
            if (std::all_of(target.begin(), target.end(), [](QChar c) { return c.isLetterOrNumber() || c == '_' || c == ':'; })) {
                message = message.mid(split + 2);
            }
        }
        message = message.trimmed();

        if (message.contains("WAD scan failed") && level.compare("error", Qt::CaseInsensitive) == 0) {
            // The anti-skinhack scan rejected a mod WAD; stop instead of patching around it.
            auto wad = message.section(" for ", -1).trimmed();
            doReportError("Patcher", patcherMessage("errPatcherScan", {wad}), line);
            stopHost();
        } else if (message == "init done") {
            setStatus("Waiting for exit");
        } else if (message == "joined too late, not overlaying") {
            setStatus("Joined too late");
        } else if (message.startsWith("end of life reached, please update: ")) {
            doReportError("Patcher", patcherMessage("errPatcherEol"), line);
            stopHost();
        } else if (auto disabled = QString("overlay verification failed, disabling overlay: ");
                   message.startsWith(disabled)) {
            doReportError("Patcher", patcherMessage("errPatcherOverlay", {message.mid(disabled.size())}), line);
        } else if (auto hook = QString("failed to install "); message.startsWith(hook) && message.endsWith(" hook")) {
            doReportError("Patcher", patcherMessage("errPatcherHook", {message.mid(hook.size()).chopped(5)}), line);
        }
    }
}

void CSLOLToolsImpl::stopHost() {
    if (hostProcess_ == nullptr || hostStopping_) {
        return;
    }
    hostStopping_ = true;
    setStatus("Stopping patcher");
    hostProcess_->write("stop\n");
    hostProcess_->closeWriteChannel();
    // The host may ignore stop while it is parked scanning for the game.
    auto process = hostProcess_;
    QTimer::singleShot(5000, process, [process] {
        if (process->state() != QProcess::NotRunning) {
            process->kill();
        }
    });
}

void CSLOLToolsImpl::runDiagInternal(bool internal_once) {
#ifndef _WIN32
    return;
#endif
    if (!internal_once) {
        QProcess process;
        process.startDetached(prog_ + DIAG_TOOL_EXE, QStringList{"e"});
        return;
    }
    if (QFileInfo info("skip-diag.txt"); info.exists()) {
        return;
    }

    auto process = new QProcess(this);

    connect(process, &QProcess::started, this, [this] {});
    connect(process, &QProcess::readyReadStandardOutput, this, [=, this]() {
        process->setReadChannel(QProcess::ProcessChannel::StandardOutput);
        while (process->canReadLine()) {
            auto line = process->readLine().trimmed();
            logFile_->write(line + "\n");
        }
    });
    connect(process,
            static_cast<void (QProcess::*)(int exitCode, QProcess::ExitStatus exitStatus)>(&QProcess::finished),
            this,
            [=, this](int, QProcess::ExitStatus) { process->deleteLater(); });
    connect(process, &QProcess::errorOccurred, this, [=, this](QProcess::ProcessError error) {
        process->deleteLater();
    });
    process->start(prog_ + DIAG_TOOL_EXE, QStringList{"d"});
}
