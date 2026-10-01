#include "AudioCache.h"
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QCoreApplication>
#include <QSettings>
#include <QRegularExpression>
#include <QDateTime>
#include <QDebug>

static const char *kUserAgent =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36";

static QString sanitizeFileName(QString s) {
    s.replace(QRegularExpression("[/\\\\:*?\"<>|]"), "_");
    return s.trimmed();
}

AudioCache::AudioCache(QNetworkAccessManager *sharedManager, QObject *parent)
    : QObject(parent), m_manager(sharedManager) {

    m_cacheDir = QStandardPaths::writableLocation(
        QStandardPaths::CacheLocation) + "/audio";

    ensureCacheDir();
    cleanupPartFiles();
    detectFfmpeg();

    qDebug() << "[AudioCache] dir =" << m_cacheDir;
    qDebug() << "[AudioCache] speed limit =" << m_speedLimitBytes / 1024 << "KB/s";

    connect(this, &AudioCache::downloadFinished,
            this, &AudioCache::onCacheDownloadFinished);

    connect(this, &AudioCache::downloadFailed,
            this, [this](const QString &cid) {
        if (m_libraryTargets.contains(cid)) {
            m_libraryTargets.remove(cid);
            emit libraryDownloadFailed(cid, "下载音频失败");
        }
    });

    enforceCacheLimit();
}

void AudioCache::setSpeedLimit(qint64 bytesPerSec) {
    m_speedLimitBytes = bytesPerSec;
    qDebug() << "[AudioCache] speed limit set to"
             << bytesPerSec / 1024 << "KB/s";
}

void AudioCache::ensureCacheDir() {
    QDir d(m_cacheDir);
    if (!d.exists()) d.mkpath(".");
}

void AudioCache::cleanupPartFiles() {
    QDir d(m_cacheDir);
    const QStringList parts = d.entryList({"*.part"}, QDir::Files);
    for (const QString &p : parts) d.remove(p);
}

void AudioCache::detectFfmpeg() {
    QString appDir = QCoreApplication::applicationDirPath();
    QStringList candidates = {
        appDir + "/ffmpeg.exe",
        appDir + "/ffmpeg",
        appDir + "/bin/ffmpeg.exe",
        appDir + "/bin/ffmpeg"
    };
    for (const QString &p : candidates) {
        if (QFile::exists(p)) { m_ffmpegPath = p; return; }
    }
    QString found = QStandardPaths::findExecutable("ffmpeg");
    if (!found.isEmpty()) { m_ffmpegPath = found; return; }
    m_ffmpegPath.clear();
}

QString AudioCache::basePathFor(const QString &cid) const {
    return m_cacheDir + "/" + QString::number(qHash(cid), 16);
}
QString AudioCache::wavPathFor(const QString &cid) const {
    return basePathFor(cid) + ".wav";
}
QString AudioCache::mp3PathFor(const QString &cid) const {
    return basePathFor(cid) + ".mp3";
}

QString AudioCache::getLocalPath(const QString &cid) const {
    QString mp3 = mp3PathFor(cid);
    if (QFile::exists(mp3) && QFileInfo(mp3).size() > 0) return mp3;

    QString wav = wavPathFor(cid);
    if (QFile::exists(wav) && QFileInfo(wav).size() > 0) return wav;

    QString oldCache = basePathFor(cid) + ".cache";
    if (QFile::exists(oldCache) && QFileInfo(oldCache).size() > 0) return oldCache;

    return "";
}

bool AudioCache::hasCache(const QString &cid) const {
    return !getLocalPath(cid).isEmpty();
}

void AudioCache::download(const QString &cid, const QString &url) {
    if (cid.isEmpty() || url.isEmpty()) return;

    if (hasCache(cid)) {
        emit downloadFinished(cid, getLocalPath(cid));
        return;
    }

    if (m_downloading.contains(cid)) return;

    for (const auto &p : m_queue) {
        if (p.cid == cid) return;
    }

    m_downloading.insert(cid);
    m_queue.enqueue({cid, url});
    processQueue();
}

void AudioCache::processQueue() {
    while (m_activeDownloads < MAX_CONCURRENT_DOWNLOADS
           && !m_queue.isEmpty()) {
        PendingDownload p = m_queue.dequeue();
        if (hasCache(p.cid)) {
            m_downloading.remove(p.cid);
            emit downloadFinished(p.cid, getLocalPath(p.cid));
            continue;
        }
        m_activeDownloads++;
        emit downloadStarted(p.cid);
        startActualDownload(p.cid, p.url);
    }
}

// ============================================================
// 实际下载 —— ★ 带限速
//
//   限速原理：
//     1. setReadBufferSize 限制 Qt 内部 socket 缓冲
//     2. readyRead 回调里用滑动窗口计数
//        每秒最多读 m_speedLimitBytes 字节
//        超出配额时数据留在缓冲里，TCP 层会自然减速
// ============================================================
void AudioCache::startActualDownload(const QString &cid, const QString &url) {
    QNetworkRequest req{QUrl(url)};
    req.setHeader(QNetworkRequest::UserAgentHeader, kUserAgent);
    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);

    auto *reply = m_manager->get(req);

    // ★ 限制单次 socket 缓冲（64 KB），配合限速使用
    reply->setReadBufferSize(64 * 1024);

    QString finalWav = wavPathFor(cid);
    QString tmpPath  = finalWav + ".part";

    auto *file = new QFile(tmpPath);
    if (!file->open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "[AudioCache] cannot open tmp file:" << tmpPath;
        delete file;
        reply->disconnect(this);
        reply->abort();
        reply->deleteLater();
        m_downloading.remove(cid);
        if (m_activeDownloads > 0) m_activeDownloads--;
        emit downloadFailed(cid);
        processQueue();
        return;
    }

    // ★ readyRead：带限速写入
    connect(reply, &QNetworkReply::readyRead, this,
            [this, reply, file, cid]() {
        if (!file || !file->isOpen()) return;
        if (m_speedLimitBytes < 0) {
            // 不限速：全部读入
            file->write(reply->readAll());
            return;
        }

        // 滑动窗口
        qint64 now = QDateTime::currentMSecsSinceEpoch();
        auto it = m_speedStates.find(cid);
        if (it == m_speedStates.end()) {
            SpeedState st;
            st.windowStart = now;
            st.bytesThisSecond = 0;
            it = m_speedStates.insert(cid, st);
        }

        if (now - it->windowStart >= 1000) {
            it->windowStart = now;
            it->bytesThisSecond = 0;
        }

        qint64 remaining = m_speedLimitBytes - it->bytesThisSecond;
        if (remaining <= 0) {
            // 配额用完 → 不读，让数据留在 socket buffer
            return;
        }

        qint64 avail = reply->bytesAvailable();
        qint64 toRead = qMin(avail, remaining);
        if (toRead > 0) {
            QByteArray chunk = reply->read(toRead);
            file->write(chunk);
            it->bytesThisSecond += chunk.size();
        }
    });

    connect(reply, &QNetworkReply::downloadProgress, this,
            [this, cid](qint64 got, qint64 total) {
        emit downloadProgress(cid, got, total);
    });

    connect(reply, &QNetworkReply::finished, this,
            [this, reply, file, cid, finalWav, tmpPath]() {
        if (file) file->close();

        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "[AudioCache] download failed:" << cid
                       << reply->errorString();
            if (file) { file->remove(); delete file; }
            emit downloadFailed(cid);
            reply->deleteLater();
            finishDownload(cid);
            return;
        }

        qint64 sz = QFileInfo(tmpPath).size();
        if (sz < 10240) {
            qWarning() << "[AudioCache] file too small:" << cid << sz;
            if (file) { file->remove(); delete file; }
            emit downloadFailed(cid);
            reply->deleteLater();
            finishDownload(cid);
            return;
        }

        if (file) delete file;

        QFile::remove(finalWav);
        if (!QFile::rename(tmpPath, finalWav)) {
            qWarning() << "[AudioCache] rename failed:" << tmpPath;
            QFile::remove(tmpPath);
            emit downloadFailed(cid);
            reply->deleteLater();
            finishDownload(cid);
            return;
        }

        qDebug() << "[AudioCache] downloaded:" << cid
                 << sz / 1024 / 1024 << "MB";

        reply->deleteLater();

        if (!m_ffmpegPath.isEmpty()) {
            transcodeToMp3(cid, finalWav);
        } else {
            emit downloadFinished(cid, finalWav);
        }

        finishDownload(cid);
    });
}

void AudioCache::finishDownload(const QString &cid) {
    m_downloading.remove(cid);
    m_speedStates.remove(cid);   // ★ 清理限速状态
    if (m_activeDownloads > 0) m_activeDownloads--;
    processQueue();
}

void AudioCache::enforceCacheLimit() {
    QDir d(m_cacheDir);
    QFileInfoList files = d.entryInfoList(QDir::Files, QDir::Time);
    QFileInfoList realFiles;
    qint64 totalSize = 0;

    for (const auto &fi : files) {
        if (fi.fileName().endsWith(".part")) continue;
        realFiles.append(fi);
        totalSize += fi.size();
    }

    if (totalSize <= m_maxCacheSize) return;

    for (int i = realFiles.size() - 1; i >= 0; --i) {
        if (totalSize <= m_maxCacheSize) break;
        const QFileInfo &fi = realFiles[i];
        totalSize -= fi.size();
        d.remove(fi.fileName());
    }
}

void AudioCache::transcodeToMp3(const QString &cid, const QString &wavPath) {
    if (m_transcoding.contains(cid)) return;
    m_transcoding.insert(cid);
    emit transcodeStarted(cid);

    QString mp3Path = mp3PathFor(cid);
    QString tmpMp3  = mp3Path + ".part";
    QFile::remove(tmpMp3);

    auto *proc = new QProcess(this);
    proc->setProgram(m_ffmpegPath);
    proc->setArguments({
        "-hide_banner", "-nostdin", "-y",
        "-loglevel", "warning",
        "-i", wavPath,
        "-vn", "-sn", "-dn",
        "-map_metadata", "-1",
        "-map_chapters", "-1",
        "-acodec", "libmp3lame",
        "-q:a", "2",
        "-f", "mp3",
        tmpMp3
    });

    proc->setProcessChannelMode(QProcess::MergedChannels);

    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, proc, cid, wavPath, mp3Path, tmpMp3]
            (int exitCode, QProcess::ExitStatus) {
        proc->deleteLater();
        m_transcoding.remove(cid);

        if (exitCode != 0 || QFileInfo(tmpMp3).size() < 10240) {
            QFile::remove(tmpMp3);
            emit downloadFinished(cid, wavPath);
            return;
        }

        QFile::remove(mp3Path);
        if (!QFile::rename(tmpMp3, mp3Path)) {
            QFile::remove(tmpMp3);
            emit downloadFinished(cid, wavPath);
            return;
        }

        QFile::remove(wavPath);
        qDebug() << "[AudioCache] transcode done:" << cid;
        emit transcodeFinished(cid, mp3Path);
        emit downloadFinished(cid, mp3Path);
    });

    connect(proc, &QProcess::errorOccurred, this,
            [this, cid, wavPath](QProcess::ProcessError err) {
        if (err == QProcess::FailedToStart) {
            m_transcoding.remove(cid);
            emit downloadFinished(cid, wavPath);
        }
    });

    proc->start();
}

void AudioCache::clearAll() {
    m_queue.clear();
    m_downloading.clear();
    m_transcoding.clear();
    m_libraryTargets.clear();
    m_speedStates.clear();

    if (m_manager) {
        for (auto *r : m_manager->findChildren<QNetworkReply*>()) {
            if (!r) continue;
            r->disconnect(this);
            r->abort();
        }
    }

    for (auto *p : findChildren<QProcess*>()) {
        if (!p) continue;
        p->disconnect(this);
        p->kill();
        p->waitForFinished(200);
    }

    m_activeDownloads = 0;

    QDir d(m_cacheDir);
    d.removeRecursively();
    ensureCacheDir();
}

qint64 AudioCache::totalSize() const {
    qint64 total = 0;
    QDir d(m_cacheDir);
    for (const auto &f : d.entryInfoList(QDir::Files)) total += f.size();
    return total;
}

QString AudioCache::downloadDir() const {
    QSettings s("ArknightsMusicPlayer", "settings");
    QString path = s.value("download/path",
        QStandardPaths::writableLocation(QStandardPaths::MusicLocation))
        .toString();

    QDir d(path);
    if (!d.exists()) d.mkpath(".");

    return path;
}

void AudioCache::writeMetadataAndSave(const QString &cid,
                                       const QString &srcPath,
                                       const QString &title,
                                       const QString &artist,
                                       const QString &album,
                                       const QString &coverUrl) {

    QString targetDir = downloadDir();

    QString safeTitle = sanitizeFileName(title);
    QString safeArtist = sanitizeFileName(artist);
    if (safeTitle.isEmpty()) safeTitle = cid;

    QString baseName = safeArtist.isEmpty()
                       ? safeTitle
                       : (safeArtist + " - " + safeTitle);

    QString dstPath = targetDir + "/" + baseName + ".mp3";
    if (QFile::exists(dstPath)) {
        int n = 1;
        while (QFile::exists(targetDir + "/" + baseName
                             + " (" + QString::number(n) + ").mp3")) {
            ++n;
        }
        dstPath = targetDir + "/" + baseName
                  + " (" + QString::number(n) + ").mp3";
    }

    if (coverUrl.isEmpty() || m_ffmpegPath.isEmpty()) {
        encodeWithFfmpeg(cid, srcPath, dstPath,
                         title, artist, album, "");
        return;
    }

    QString coverTemp = QDir::tempPath() + "/mass_cover_"
                        + QString::number(qHash(cid), 16) + ".img";

    QNetworkRequest req{QUrl(coverUrl)};
    req.setHeader(QNetworkRequest::UserAgentHeader, kUserAgent);
    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);

    auto *reply = m_manager->get(req);
    auto *coverFile = new QFile(coverTemp);

    connect(reply, &QNetworkReply::readyRead, this, [reply, coverFile]() {
        if (!coverFile->isOpen()) {
            if (!coverFile->open(QIODevice::WriteOnly | QIODevice::Truncate)) {
                return;
            }
        }
        coverFile->write(reply->readAll());
    });

    connect(reply, &QNetworkReply::finished, this,
            [this, reply, coverFile, coverTemp, cid, srcPath, dstPath,
             title, artist, album]() {
        coverFile->close();
        coverFile->deleteLater();
        reply->deleteLater();

        QString coverPath;
        if (reply->error() == QNetworkReply::NoError
                && QFileInfo(coverTemp).size() > 1024) {
            coverPath = coverTemp;
        } else {
            QFile::remove(coverTemp);
        }

        encodeWithFfmpeg(cid, srcPath, dstPath,
                         title, artist, album, coverPath);
    });
}

void AudioCache::encodeWithFfmpeg(const QString &cid,
                                   const QString &srcPath,
                                   const QString &dstPath,
                                   const QString &title,
                                   const QString &artist,
                                   const QString &album,
                                   const QString &coverPath) {
    if (m_ffmpegPath.isEmpty()) {
        if (QFile::copy(srcPath, dstPath)) {
            emit libraryDownloadFinished(cid, dstPath);
        } else {
            emit libraryDownloadFailed(cid, "复制文件失败");
        }
        if (coverPath.startsWith(QDir::tempPath())) QFile::remove(coverPath);
        return;
    }

    QString tmpDst = dstPath + ".part";
    QFile::remove(tmpDst);

    QStringList args;
    args << "-hide_banner" << "-nostdin" << "-y"
         << "-loglevel" << "warning"
         << "-i" << srcPath;

    bool hasCover = !coverPath.isEmpty() && QFile::exists(coverPath);

    if (hasCover) {
        args << "-i" << coverPath;
        args << "-map" << "0:a";
        args << "-map" << "1:v";
        args << "-c:v" << "mjpeg";
        args << "-disposition:v" << "attached_pic";
    } else {
        args << "-vn";
    }

    args << "-acodec" << "libmp3lame";
    args << "-q:a" << "2";

    if (!title.isEmpty())
        args << "-metadata" << ("title=" + title);
    if (!artist.isEmpty())
        args << "-metadata" << ("artist=" + artist);
    if (!album.isEmpty())
        args << "-metadata" << ("album=" + album);

    args << "-id3v2_version" << "3";
    args << "-f" << "mp3";
    args << tmpDst;

    auto *proc = new QProcess(this);
    proc->setProgram(m_ffmpegPath);
    proc->setArguments(args);
    proc->setProcessChannelMode(QProcess::MergedChannels);

    connect(proc, &QProcess::readyReadStandardOutput, this, [proc, cid]() {
        QByteArray out = proc->readAllStandardOutput();
        if (!out.isEmpty()) {
            qDebug() << "[ffmpeg-meta]" << cid << out.trimmed();
        }
    });

    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, proc, cid, srcPath, dstPath, tmpDst, coverPath]
            (int exitCode, QProcess::ExitStatus) {
        proc->deleteLater();

        if (coverPath.startsWith(QDir::tempPath())) {
            QFile::remove(coverPath);
        }

        if (exitCode != 0 || QFileInfo(tmpDst).size() < 10240) {
            qWarning() << "[AudioCache] encode failed:" << cid;
            QFile::remove(tmpDst);
            if (QFile::copy(srcPath, dstPath)) {
                emit libraryDownloadFinished(cid, dstPath);
            } else {
                emit libraryDownloadFailed(cid, "编码失败");
            }
            return;
        }

        QFile::remove(dstPath);
        if (!QFile::rename(tmpDst, dstPath)) {
            QFile::remove(tmpDst);
            emit libraryDownloadFailed(cid, "重命名失败");
            return;
        }

        qDebug() << "[AudioCache] library saved (with metadata):" << dstPath;
        emit libraryDownloadFinished(cid, dstPath);
    });

    connect(proc, &QProcess::errorOccurred, this,
            [this, cid, srcPath, dstPath, coverPath]
            (QProcess::ProcessError err) {
        if (err == QProcess::FailedToStart) {
            if (coverPath.startsWith(QDir::tempPath())) {
                QFile::remove(coverPath);
            }
            if (QFile::copy(srcPath, dstPath)) {
                emit libraryDownloadFinished(cid, dstPath);
            } else {
                emit libraryDownloadFailed(cid, "ffmpeg 启动失败");
            }
        }
    });

    proc->start();
}

bool AudioCache::downloadToLibrary(const QString &cid,
                                    const QString &songName,
                                    const QString &artist,
                                    const QString &album,
                                    const QString &coverUrl,
                                    const QString &url) {
    if (cid.isEmpty()) {
        emit libraryDownloadFailed(cid, "无效的歌曲 ID");
        return false;
    }

    QString localPath = getLocalPath(cid);
    if (!localPath.isEmpty()) {
        writeMetadataAndSave(cid, localPath, songName, artist, album, coverUrl);
        return true;
    }

    if (url.isEmpty()) {
        emit libraryDownloadFailed(cid, "无可用音频源，请先播放一次");
        return false;
    }

    m_libraryTargets.insert(cid, {songName, artist, album, coverUrl});

    if (!m_downloading.contains(cid)) {
        download(cid, url);
    }

    return true;
}

void AudioCache::onCacheDownloadFinished(const QString &cid,
                                          const QString &localPath) {
    if (!m_libraryTargets.contains(cid)) return;

    LibraryTarget t = m_libraryTargets.take(cid);
    writeMetadataAndSave(cid, localPath, t.songName, t.artist,
                         t.album, t.coverUrl);
}