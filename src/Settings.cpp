#include "Settings.h"
#include <QStandardPaths>
#include <QFileDialog>
#include <QDir>
#include <QDesktopServices>
#include <QUrl>
#include <QProcess>
#include <QCoreApplication>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QVersionNumber>
#include <QDebug>
#include <algorithm>

Settings::Settings(QObject *parent)
    : QObject(parent),
      m_s("ArknightsMusicPlayer", "settings") {

    m_nam = new QNetworkAccessManager(this);
}

QString Settings::audioQuality() const {
    return m_s.value("audio/quality", "exhigh").toString();
}
void Settings::setAudioQuality(const QString &v) {
    m_s.setValue("audio/quality", v);
    emit changed();
}

bool Settings::translateLyric() const {
    return m_s.value("lyric/translate", true).toBool();
}
void Settings::setTranslateLyric(bool v) {
    m_s.setValue("lyric/translate", v);
    emit changed();
}

QString Settings::downloadPath() const {
    return m_s.value("download/path",
        QStandardPaths::writableLocation(QStandardPaths::MusicLocation)).toString();
}
void Settings::setDownloadPath(const QString &v) {
    m_s.setValue("download/path", v);
    emit changed();
}

bool Settings::darkMode() const {
    return m_s.value("ui/darkMode", true).toBool();
}
void Settings::setDarkMode(bool v) {
    m_s.setValue("ui/darkMode", v);
    emit changed();
}

double Settings::fontScale() const {
    return m_s.value("ui/fontScale", 1.0).toDouble();
}
void Settings::setFontScale(double v) {
    v = qBound(0.8, v, 1.5);
    m_s.setValue("ui/fontScale", v);
    emit fontScaleChanged();
    emit changed();
}

QString Settings::closeBehavior() const {
    return m_s.value("ui/closeBehavior", "tray").toString();
}
void Settings::setCloseBehavior(const QString &v) {
    if (v != "tray" && v != "quit") return;
    m_s.setValue("ui/closeBehavior", v);
    emit changed();
}

QStringList Settings::getSearchHistory() const {
    return m_s.value("search/history").toStringList();
}

void Settings::addSearchHistory(const QString &kw) {
    if (kw.trimmed().isEmpty()) return;
    QStringList list = m_s.value("search/history").toStringList();
    list.removeAll(kw);
    list.prepend(kw);
    while (list.size() > 20) list.removeLast();
    m_s.setValue("search/history", list);
    emit changed();
}

void Settings::clearSearchHistory() {
    m_s.remove("search/history");
    emit changed();
}

QString Settings::pickFolder(const QString &title, const QString &currentPath) {
    QString startDir = currentPath.trimmed();
    if (startDir.isEmpty() || !QDir(startDir).exists()) {
        startDir = QStandardPaths::writableLocation(QStandardPaths::MusicLocation);
    }

    QString folder = QFileDialog::getExistingDirectory(
        nullptr,
        title.isEmpty() ? "选择文件夹" : title,
        startDir,
        QFileDialog::ShowDirsOnly | QFileDialog::DontResolveSymlinks
    );

    if (!folder.isEmpty()) {
        folder = QDir::toNativeSeparators(folder);
        folder.replace("\\", "/");
    }
    return folder;
}

void Settings::openLogFolder() const {
    QString logDir = QStandardPaths::writableLocation(
        QStandardPaths::AppLocalDataLocation);
    QDir().mkpath(logDir);
    QDesktopServices::openUrl(QUrl::fromLocalFile(logDir));
}

void Settings::openDownloadFolder() const {
    QString dir = downloadPath();
    QDir().mkpath(dir);
    QDesktopServices::openUrl(QUrl::fromLocalFile(dir));
}

// ============================================================
// 重启应用（带延迟参数）
// ============================================================
void Settings::restartApp() {
    QString exePath = QCoreApplication::applicationFilePath();
    QStringList args = QCoreApplication::arguments();
    args.removeFirst();

    args.erase(std::remove_if(args.begin(), args.end(),
        [](const QString &s) { return s.startsWith("--restart-delay="); }),
        args.end());

    args << "--restart-delay=1500";

    qDebug() << "[Settings] restarting app:" << exePath << args;
    QProcess::startDetached(exePath, args);
    QCoreApplication::quit();
}


QString Settings::currentVersion() const {
    return QString::fromLatin1(kCurrentVersion);
}

void Settings::openUrl(const QString &url) const {
    if (url.isEmpty()) return;
    QDesktopServices::openUrl(QUrl(url));
}

void Settings::checkForUpdates() {
    qDebug() << "[Settings] checking for updates from GitHub...";
    qDebug() << "[Settings] current version:" << currentVersion();

    QNetworkRequest req{QUrl(QString::fromLatin1(kGitHubApiUrl))};

    req.setHeader(QNetworkRequest::UserAgentHeader,
                  "Mass/" + currentVersion().toUtf8());

    req.setRawHeader("Accept", "application/vnd.github.v3+json");

    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    req.setTransferTimeout(10000);

    auto *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            QString err = reply->errorString();
            qWarning() << "[Settings] update check failed:" << err;
            emit updateCheckFailed(err);
            return;
        }

        QByteArray data = reply->readAll();
        QJsonParseError err;
        QJsonDocument doc = QJsonDocument::fromJson(data, &err);

        if (err.error != QJsonParseError::NoError || !doc.isObject()) {
            qWarning() << "[Settings] JSON parse error:" << err.errorString();
            emit updateCheckFailed("服务器返回格式错误");
            return;
        }

        QJsonObject obj = doc.object();

        QString remoteVersion = obj["tag_name"].toString();
        QString releasePageUrl = obj["html_url"].toString();
        QString notes = obj["body"].toString();

        if (remoteVersion.isEmpty()) {
            emit updateCheckFailed("响应缺少 tag_name 字段");
            return;
        }

        QString cleanRemoteVersion = remoteVersion;
        if (cleanRemoteVersion.startsWith("v") || cleanRemoteVersion.startsWith("V")) {
            cleanRemoteVersion = cleanRemoteVersion.mid(1);
        }

        qDebug() << "[Settings] remote version:" << cleanRemoteVersion;

        QString downloadUrl;
        QJsonArray assets = obj["assets"].toArray();
        for (const auto &asset : assets) {
            QJsonObject assetObj = asset.toObject();
            QString name = assetObj["name"].toString();
            if (name.endsWith(".exe", Qt::CaseInsensitive)) {
                downloadUrl = assetObj["browser_download_url"].toString();
                break;
            }
        }

        if (downloadUrl.isEmpty()) {
            downloadUrl = releasePageUrl;
        }

        QVersionNumber localVer =
            QVersionNumber::fromString(currentVersion());
        QVersionNumber remoteVer =
            QVersionNumber::fromString(cleanRemoteVersion);

        if (remoteVer > localVer) {
            qDebug() << "[Settings] update available:" << cleanRemoteVersion;
            emit updateAvailable(cleanRemoteVersion, downloadUrl, notes);
        } else {
            qDebug() << "[Settings] already up to date";
            emit updateNotAvailable(currentVersion());
        }
    });
}