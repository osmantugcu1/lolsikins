#ifndef CSLOLSKINREPO_H
#define CSLOLSKINREPO_H

#include <QFile>
#include <QJsonArray>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QObject>
#include <QPointer>

// Lists and downloads every .fantome file of a GitHub repository, grouped by champion:
//   [skins/]<Champion>/<Skin>.fantome
//   [skins/]<Champion>/<Folder>/<Chroma>.fantome
class CSLOLSkinRepo : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit CSLOLSkinRepo(QObject* parent = nullptr);

    bool busy() const;

    // repo is "owner/name" or a github.com URL, token may be empty for public repos.
    Q_INVOKABLE void fetchCatalog(QString repo, QString branch, QString token);
    // path is the repository path of the skin, installName is used as the local file name.
    Q_INVOKABLE void download(QString path, QString installName);
    Q_INVOKABLE void cancel();

    // Turns a git tree listing into skin entries sorted by champion and skin, each skin followed by its chromas.
    static QJsonArray parseTree(QJsonObject const& root);

signals:
    void busyChanged(bool busy);
    void catalogLoaded(QJsonArray skins, bool truncated);
    void catalogFailed(QString message);
    void downloadProgress(QString path, qint64 received, qint64 total);
    void downloaded(QString path, QString localFile);
    void downloadFailed(QString path, QString message);

private:
    QNetworkAccessManager* network_;
    QPointer<QNetworkReply> reply_;
    QFile* file_ = nullptr;
    QString owner_;
    QString name_;
    QString branch_;
    QString token_;

    QNetworkRequest makeRequest(QString url, QByteArray accept) const;
    void setReply(QNetworkReply* reply);
    static QString replyError(QNetworkReply* reply);
};

#endif  // CSLOLSKINREPO_H
