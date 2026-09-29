#include "CSLOLSkinRepo.h"

#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkRequest>
#include <QStandardPaths>
#include <QUrl>
#include <algorithm>

static constexpr char const* GITHUB_API = "https://api.github.com";

CSLOLSkinRepo::CSLOLSkinRepo(QObject* parent) : QObject(parent), network_(new QNetworkAccessManager(this)) {}

bool CSLOLSkinRepo::busy() const { return !reply_.isNull(); }

QNetworkRequest CSLOLSkinRepo::makeRequest(QString url, QByteArray accept) const {
    QNetworkRequest request{QUrl(url)};
    request.setRawHeader("Accept", accept);
    request.setRawHeader("User-Agent", "LolSikins");
    request.setRawHeader("X-GitHub-Api-Version", "2022-11-28");
    if (!token_.isEmpty()) {
        request.setRawHeader("Authorization", "Bearer " + token_.toUtf8());
    }
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    return request;
}

void CSLOLSkinRepo::setReply(QNetworkReply* reply) {
    reply_ = reply;
    emit busyChanged(reply != nullptr);
}

// Errors are sent to QML as translation keys, arguments separated by \x1f.
static QString errorMessage(QString key, QStringList args = {}) {
    args.prepend(key);
    return args.join(QChar(0x1f));
}

QString CSLOLSkinRepo::replyError(QNetworkReply* reply) {
    auto status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    switch (status) {
        case 401:
            return errorMessage("errToken");
        case 403:
        case 429:
            return errorMessage("errForbidden");
        case 404:
            return errorMessage("errNotFound");
        default:
            break;
    }
    if (status != 0) {
        return errorMessage("errHttp", {QString::number(status), reply->errorString()});
    }
    return errorMessage("errNetwork", {reply->errorString()});
}

QJsonArray CSLOLSkinRepo::parseTree(QJsonObject const& root) {
    QList<QJsonObject> skins;
    for (auto const& value : root["tree"].toArray()) {
        auto entry = value.toObject();
        auto path = entry["path"].toString();
        if (entry["type"].toString() != "blob" || !path.endsWith(".fantome", Qt::CaseInsensitive)) {
            continue;
        }

        // [skins/]<Champion>/[<Folders>/]<Name>.fantome, anything deeper than the champion folder is a chroma.
        auto parts = path.split('/');
        auto fileName = parts.takeLast();
        parts.append(fileName.left(fileName.size() - QString(".fantome").size()));
        if (parts.size() > 1 && parts[0].compare("skins", Qt::CaseInsensitive) == 0) {
            parts.removeFirst();
        }
        auto champion = parts.size() > 1 ? parts.takeFirst() : QStringLiteral("Diğer");
        bool chroma = parts.size() > 1;
        parts.erase(std::remove_if(parts.begin(),
                                   parts.end(),
                                   [](QString const& part) { return part.compare("chromas", Qt::CaseInsensitive) == 0; }),
                    parts.end());

        // The first folder under the champion names the skin a chroma belongs to.
        skins.append(QJsonObject{
            {"champion", champion},
            {"name", parts.join(" - ")},
            {"skin", parts.first()},
            {"variant", parts.size() > 1 ? QStringList(parts.mid(1)).join(" - ") : parts.first()},
            {"chroma", chroma},
            {"path", path},
            {"sha", entry["sha"].toString()},
            {"size", entry["size"].toDouble()},
        });
    }

    std::sort(skins.begin(), skins.end(), [](QJsonObject const& a, QJsonObject const& b) {
        auto champion = a["champion"].toString().compare(b["champion"].toString(), Qt::CaseInsensitive);
        if (champion != 0) {
            return champion < 0;
        }
        auto skin = a["skin"].toString().compare(b["skin"].toString(), Qt::CaseInsensitive);
        if (skin != 0) {
            return skin < 0;
        }
        if (a["chroma"].toBool() != b["chroma"].toBool()) {
            return !a["chroma"].toBool();
        }
        return a["variant"].toString().compare(b["variant"].toString(), Qt::CaseInsensitive) < 0;
    });

    QJsonArray result;
    for (auto const& skin : skins) {
        result.append(skin);
    }
    return result;
}

void CSLOLSkinRepo::fetchCatalog(QString repo, QString branch, QString token) {
    if (busy()) {
        return;
    }

    repo = repo.trimmed();
    for (auto prefix : {"https://", "http://", "www.", "github.com/"}) {
        if (repo.startsWith(prefix, Qt::CaseInsensitive)) {
            repo = repo.mid(QString(prefix).size());
        }
    }
    if (repo.endsWith(".git", Qt::CaseInsensitive)) {
        repo.chop(4);
    }
    auto parts = repo.split('/', Qt::SkipEmptyParts);
    if (parts.size() < 2) {
        emit catalogFailed(errorMessage("errRepoFormat"));
        return;
    }
    owner_ = parts[0];
    name_ = parts[1];
    branch_ = branch.trimmed().isEmpty() ? QStringLiteral("main") : branch.trimmed();
    token_ = token.trimmed();

    auto url = QString("%1/repos/%2/%3/git/trees/%4?recursive=1")
                   .arg(GITHUB_API, owner_, name_, QString(QUrl::toPercentEncoding(branch_)));
    auto reply = network_->get(makeRequest(url, "application/vnd.github+json"));
    setReply(reply);

    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        setReply(nullptr);
        if (reply->error() != QNetworkReply::NoError) {
            emit catalogFailed(replyError(reply));
            return;
        }

        auto root = QJsonDocument::fromJson(reply->readAll()).object();
        emit catalogLoaded(parseTree(root), root["truncated"].toBool());
    });
}

void CSLOLSkinRepo::download(QString path, QString installName) {
    if (busy() || owner_.isEmpty()) {
        return;
    }

    for (auto c : QStringLiteral("<>:\"/\\|?*")) {
        installName.replace(c, '_');
    }
    installName = installName.trimmed();
    auto extension = path.mid(path.lastIndexOf('.')).toLower();

    auto dir = QDir(QStandardPaths::writableLocation(QStandardPaths::TempLocation) + "/lolsikins");
    dir.mkpath(".");
    auto localFile = dir.filePath(installName + extension);
    QFile::remove(localFile);

    file_ = new QFile(localFile, this);
    if (!file_->open(QIODevice::WriteOnly)) {
        emit downloadFailed(path, errorMessage("errTempFile", {localFile}));
        file_->deleteLater();
        file_ = nullptr;
        return;
    }

    QStringList segments;
    for (auto const& segment : path.split('/')) {
        segments.append(QUrl::toPercentEncoding(segment));
    }
    auto url = QString("%1/repos/%2/%3/contents/%4?ref=%5")
                   .arg(GITHUB_API, owner_, name_, segments.join('/'), QString(QUrl::toPercentEncoding(branch_)));
    auto reply = network_->get(makeRequest(url, "application/vnd.github.raw"));
    setReply(reply);

    connect(reply, &QNetworkReply::readyRead, this, [this, reply] {
        if (file_) {
            file_->write(reply->readAll());
        }
    });
    connect(reply, &QNetworkReply::downloadProgress, this, [this, path](qint64 received, qint64 total) {
        emit downloadProgress(path, received, total);
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, path, localFile] {
        reply->deleteLater();
        setReply(nullptr);
        auto file = file_;
        file_ = nullptr;
        file->write(reply->readAll());
        file->close();
        file->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            QFile::remove(localFile);
            emit downloadFailed(path,
                                reply->error() == QNetworkReply::OperationCanceledError ? errorMessage("errCanceled")
                                                                                        : replyError(reply));
            return;
        }
        emit downloaded(path, localFile);
    });
}

void CSLOLSkinRepo::cancel() {
    if (reply_) {
        reply_->abort();
    }
}
