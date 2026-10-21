#include "Settings.h"
#include <QStandardPaths>
#include <QFileDialog>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTextStream>
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
#include <QColor>
#include <QRegularExpression>
#include <QDebug>
#include <algorithm>

Settings::Settings(QObject *parent)
    : QObject(parent),
      m_s("ArknightsMusicPlayer", "settings") {
    m_nam = new QNetworkAccessManager(this);

    // 跟随系统时轮询 Windows 应用主题，变了再通知界面
    m_lastSystemDark = systemPrefersDark();
    m_themeTimer.setInterval(2000);
    connect(&m_themeTimer, &QTimer::timeout, this, [this]() {
        if (themeMode() != "system") return;
        const bool dark = systemPrefersDark();
        if (dark == m_lastSystemDark) return;
        m_lastSystemDark = dark;
        emit changed();
    });
    m_themeTimer.start();
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

bool Settings::apiTranslate() const {
    return m_s.value("lyric/apiTranslate", true).toBool();
}
void Settings::setApiTranslate(bool v) {
    m_s.setValue("lyric/apiTranslate", v);
    emit changed();
}

// 启动音量（0~1）
double Settings::volumeDefault() const {
    return m_s.value("audio/volumeDefault", 0.8).toDouble();
}
void Settings::setVolumeDefault(double v) {
    m_s.setValue("audio/volumeDefault", v);
    emit changed();
}

// 播放模式 0顺序/1单曲/2列表/3随机
int Settings::loopMode() const {
    return m_s.value("audio/loopMode", 0).toInt();
}
void Settings::setLoopMode(int v) {
    m_s.setValue("audio/loopMode", v);
    emit changed();
}

// 拖动进度条时实时预览
bool Settings::seekPreview() const {
    return m_s.value("audio/seekPreview", false).toBool();
}
void Settings::setSeekPreview(bool v) {
    m_s.setValue("audio/seekPreview", v);
    emit changed();
}

// 切歌淡入淡出
bool Settings::crossfade() const {
    return m_s.value("audio/crossfade", true).toBool();
}
void Settings::setCrossfade(bool v) {
    m_s.setValue("audio/crossfade", v);
    emit changed();
}

// HTTP 缓存上限（MB）
int Settings::httpCacheMb() const {
    return m_s.value("cache/httpMb", 128).toInt();
}
void Settings::setHttpCacheMb(int v) {
    m_s.setValue("cache/httpMb", v);
    emit changed();
}

// 封面图片缓存上限（MB）
int Settings::imageCacheMb() const {
    return m_s.value("cache/imageMb", 256).toInt();
}
void Settings::setImageCacheMb(int v) {
    m_s.setValue("cache/imageMb", v);
    emit changed();
}

// 预取下一首（省流量可关）
bool Settings::prefetchNext() const {
    return m_s.value("cache/prefetchNext", true).toBool();
}
void Settings::setPrefetchNext(bool v) {
    m_s.setValue("cache/prefetchNext", v);
    emit changed();
}

// Dock 自动隐藏触发宽度（px）
int Settings::dockTriggerWidth() const {
    return m_s.value("ui/dockTriggerWidth", 180).toInt();
}
void Settings::setDockTriggerWidth(int v) {
    m_s.setValue("ui/dockTriggerWidth", v);
    emit changed();
}

// 播放条自动隐藏触发高度（px）
int Settings::playerTriggerHeight() const {
    return m_s.value("ui/playerTriggerHeight", 160).toInt();
}
void Settings::setPlayerTriggerHeight(int v) {
    m_s.setValue("ui/playerTriggerHeight", v);
    emit changed();
}

// 毛玻璃噪点强度
double Settings::glassNoise() const {
    return m_s.value("ui/glassNoise", 0.06).toDouble();
}
void Settings::setGlassNoise(double v) {
    m_s.setValue("ui/glassNoise", v);
    emit changed();
}

// 亚克力着色浓度
double Settings::glassTint() const {
    return m_s.value("ui/glassTint", 0.42).toDouble();
}
void Settings::setGlassTint(double v) {
    m_s.setValue("ui/glassTint", v);
    emit changed();
}

// 启动时检查更新
bool Settings::checkUpdate() const {
    return m_s.value("ui/checkUpdate", true).toBool();
}
void Settings::setCheckUpdate(bool v) {
    m_s.setValue("ui/checkUpdate", v);
    emit changed();
}

// 记住窗口位置与大小
bool Settings::rememberGeometry() const {
    return m_s.value("ui/rememberGeometry", false).toBool();
}
void Settings::setRememberGeometry(bool v) {
    m_s.setValue("ui/rememberGeometry", v);
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

bool Settings::systemPrefersDark() const {
#ifdef Q_OS_WIN
    QSettings reg("HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\"
                  "CurrentVersion\\Themes\\Personalize",
                  QSettings::NativeFormat);
    const QVariant v = reg.value("AppsUseLightTheme");
    if (v.isValid()) return v.toInt() == 0;      // 0 = 深色
#endif
    return true;
}

QString Settings::themeMode() const {
    return m_s.value("ui/themeMode", "system").toString();
}
void Settings::setThemeMode(const QString &v) {
    QString mode = v;
    if (mode != "light" && mode != "dark") mode = "system";
    if (themeMode() == mode) return;
    m_s.setValue("ui/themeMode", mode);
    emit changed();
}

QString Settings::accentColor() const {
    return m_s.value("ui/accentColor").toString();
}
void Settings::setAccentColor(const QString &v) {
    QString c = v.trimmed();

    // 只接受 #RGB / #RRGGBB；空串表示恢复默认色
    if (!c.isEmpty()) {
        if (!c.startsWith('#')) c.prepend('#');
        c = c.toUpper();
        static const QRegularExpression re("^#([0-9A-F]{3}|[0-9A-F]{6})$");
        if (!re.match(c).hasMatch() || !QColor::isValidColorName(c)) return;
        if (c.length() == 4) {
            c = QString("#%1%1%2%2%3%3")
                    .arg(c.at(1)).arg(c.at(2)).arg(c.at(3));
        }
    }

    if (accentColor() == c) return;
    m_s.setValue("ui/accentColor", c);
    emit changed();
}

bool Settings::darkMode() const {
    const QString mode = themeMode();
    if (mode == "dark")  return true;
    if (mode == "light") return false;
    return systemPrefersDark();
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

bool Settings::desktopLyricEnabled() const {
    return m_s.value("lyric/desktop", false).toBool();
}
void Settings::setDesktopLyricEnabled(bool v) {
    m_s.setValue("lyric/desktop", v);
    emit changed();
}

QString Settings::backgroundImage() const {
    return m_s.value("ui/background").toString();
}
void Settings::setBackgroundImage(const QString &v) {
    m_s.setValue("ui/background", v);
    emit changed();
}

int Settings::localSongCount() const {
    return loadLocalSongs().size();
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
        QFileDialog::ShowDirsOnly | QFileDialog::DontResolveSymlinks);
    if (!folder.isEmpty()) {
        folder = QDir::toNativeSeparators(folder);
        folder.replace("\\", "/");
    }
    return folder;
}

QString Settings::pickSaveFile(const QString &title, const QString &defaultName) {
    QString dir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    QString path = QFileDialog::getSaveFileName(
        nullptr,
        title.isEmpty() ? "保存文件" : title,
        dir + "/" + (defaultName.isEmpty() ? "export.json" : defaultName),
        "JSON (*.json)");
    if (!path.isEmpty()) {
        path = QDir::toNativeSeparators(path);
        path.replace("\\", "/");
    }
    return path;
}

QString Settings::pickOpenFile(const QString &title, const QString &filter) {
    QString dir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    QString path = QFileDialog::getOpenFileName(
        nullptr,
        title.isEmpty() ? "选择文件" : title,
        dir,
        filter.isEmpty() ? "All Files (*.*)" : filter);
    if (!path.isEmpty()) {
        path = QDir::toNativeSeparators(path);
        path.replace("\\", "/");
    }
    return path;
}

QStringList Settings::pickOpenFiles(const QString &title, const QString &filter) {
    QString dir = QStandardPaths::writableLocation(QStandardPaths::MusicLocation);
    QStringList paths = QFileDialog::getOpenFileNames(
        nullptr,
        title.isEmpty() ? "选择文件" : title,
        dir,
        filter.isEmpty() ? "All Files (*.*)" : filter);
    QStringList out;
    for (const QString &p : paths) {
        QString n = QDir::toNativeSeparators(p);
        n.replace("\\", "/");
        out << n;
    }
    return out;
}

// ============================================================
// 本地库
// ============================================================
QVariantList Settings::loadLocalSongs() const {
    QString json = m_s.value("local/songs").toString();
    if (json.isEmpty()) return {};
    QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    if (!doc.isArray()) return {};
    QVariantList out;
    for (const auto &v : doc.array()) {
        out.append(v.toObject().toVariantMap());
    }
    return out;
}

void Settings::saveLocalSongs(const QVariantList &list) {
    QJsonArray arr;
    for (const auto &v : list) {
        arr.append(QJsonObject::fromVariantMap(v.toMap()));
    }
    QJsonDocument doc(arr);
    m_s.setValue("local/songs",
        QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));
    emit localSongsChanged();
}

QVariantList Settings::getLocalSongs() const {
    return loadLocalSongs();
}

void Settings::addLocalSong(const QString &filePath,
                             const QString &title,
                             const QString &artist,
                             const QString &coverPath,
                             const QString &lyricPath) {
    if (filePath.isEmpty()) return;

    QVariantList list = loadLocalSongs();

    // 去重
    for (const auto &v : list) {
        if (v.toMap()["filePath"].toString() == filePath) return;
    }

    QVariantMap item;
    item["filePath"]  = filePath;
    item["title"]     = title.isEmpty() ? baseNameOf(filePath) : title;
    item["artist"]    = artist.isEmpty() ? "本地歌曲" : artist;
    item["coverPath"] = coverPath;
    item["lyricPath"] = lyricPath;
    item["addedAt"]   = QDateTime::currentMSecsSinceEpoch();

    list.append(item);
    saveLocalSongs(list);
}

void Settings::removeLocalSong(const QString &filePath) {
    QVariantList list = loadLocalSongs();
    for (int i = list.size() - 1; i >= 0; --i) {
        if (list[i].toMap()["filePath"].toString() == filePath) {
            list.removeAt(i);
        }
    }
    saveLocalSongs(list);
}

void Settings::clearLocalSongs() {
    saveLocalSongs({});
}

void Settings::updateLocalSong(const QString &filePath,
                                const QString &title,
                                const QString &artist,
                                const QString &coverPath,
                                const QString &lyricPath) {
    QVariantList list = loadLocalSongs();
    for (int i = 0; i < list.size(); ++i) {
        QVariantMap m = list[i].toMap();
        if (m["filePath"].toString() == filePath) {
            if (!title.isEmpty())     m["title"] = title;
            if (!artist.isEmpty())    m["artist"] = artist;
            m["coverPath"] = coverPath;
            m["lyricPath"] = lyricPath;
            list[i] = m;
            break;
        }
    }
    saveLocalSongs(list);
}

// ============================================================
// 文件工具
// ============================================================
QString Settings::readTextFile(const QString &path) const {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return "";
    QTextStream ts(&f);
    ts.setEncoding(QStringConverter::Utf8);
    return ts.readAll();
}

QString Settings::findSidecarFile(const QString &audioPath,
                                   const QStringList &extensions) const {
    QFileInfo info(audioPath);
    QDir dir = info.absoluteDir();
    QString base = info.completeBaseName();

    for (const QString &ext : extensions) {
        QString candidate = dir.absoluteFilePath(base + "." + ext);
        if (QFile::exists(candidate)) {
            QString n = QDir::toNativeSeparators(candidate);
            n.replace("\\", "/");
            return n;
        }
        // 也尝试大写扩展名
        candidate = dir.absoluteFilePath(base + "." + ext.toUpper());
        if (QFile::exists(candidate)) {
            QString n = QDir::toNativeSeparators(candidate);
            n.replace("\\", "/");
            return n;
        }
    }
    return "";
}

QString Settings::baseNameOf(const QString &path) const {
    return QFileInfo(path).completeBaseName();
}

// ============================================================
// 系统集成
// ============================================================
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

QString Settings::backgroundsDir() const {
    QString dir = QStandardPaths::writableLocation(
        QStandardPaths::AppLocalDataLocation) + "/backgrounds";
    QDir().mkpath(dir);
    return dir;
}

QVariantList Settings::getBackgrounds() const {
    QVariantList out;
    const QStringList filters = {"*.png", "*.jpg", "*.jpeg",
                                 "*.webp", "*.bmp"};
    const QFileInfoList files = QDir(backgroundsDir())
        .entryInfoList(filters, QDir::Files, QDir::Name);
    for (const QFileInfo &fi : files) {
        QVariantMap m;
        m["url"]  = QUrl::fromLocalFile(fi.absoluteFilePath()).toString();
        m["name"] = fi.fileName();
        out.append(m);
    }
    return out;
}

void Settings::openBackgroundsFolder() const {
    QDesktopServices::openUrl(QUrl::fromLocalFile(backgroundsDir()));
}

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
        if (downloadUrl.isEmpty()) downloadUrl = releasePageUrl;

        QVersionNumber localVer = QVersionNumber::fromString(currentVersion());
        QVersionNumber remoteVer = QVersionNumber::fromString(cleanRemoteVersion);

        if (remoteVer > localVer) {
            emit updateAvailable(cleanRemoteVersion, downloadUrl, notes);
        } else {
            emit updateNotAvailable(currentVersion());
        }
    });
}

// 窗口几何
int Settings::winX() const {
    return m_s.value("ui/winX", 0).toInt();
}
void Settings::setWinX(int v) {
    m_s.setValue("ui/winX", v);
    emit changed();
}
// 窗口几何
int Settings::winY() const {
    return m_s.value("ui/winY", 0).toInt();
}
void Settings::setWinY(int v) {
    m_s.setValue("ui/winY", v);
    emit changed();
}
// 窗口几何
int Settings::winW() const {
    return m_s.value("ui/winW", 0).toInt();
}
void Settings::setWinW(int v) {
    m_s.setValue("ui/winW", v);
    emit changed();
}
// 窗口几何
int Settings::winH() const {
    return m_s.value("ui/winH", 0).toInt();
}
void Settings::setWinH(int v) {
    m_s.setValue("ui/winH", v);
    emit changed();
}
