#pragma once
#include <QObject>
#include <QString>
#include <QSet>
#include <QQueue>
#include <QHash>
#include <QNetworkAccessManager>

class AudioCache : public QObject {
    Q_OBJECT
public:
    explicit AudioCache(QNetworkAccessManager *sharedManager,
                        QObject *parent = nullptr);

    Q_INVOKABLE QString getLocalPath(const QString &cid) const;
    Q_INVOKABLE bool hasCache(const QString &cid) const;
    Q_INVOKABLE void download(const QString &cid, const QString &url);
    Q_INVOKABLE void clearAll();
    Q_INVOKABLE qint64 totalSize() const;

    Q_INVOKABLE bool ffmpegAvailable() const { return !m_ffmpegPath.isEmpty(); }
    Q_INVOKABLE QString ffmpegPath() const { return m_ffmpegPath; }
    Q_INVOKABLE int activeDownloads() const { return m_activeDownloads; }

    // ★ 限制下载速度（字节/秒），-1 表示不限速
    Q_INVOKABLE void setSpeedLimit(qint64 bytesPerSec);
    Q_INVOKABLE qint64 speedLimit() const { return m_speedLimitBytes; }

    Q_INVOKABLE bool downloadToLibrary(const QString &cid,
                                        const QString &songName,
                                        const QString &artist,
                                        const QString &album,
                                        const QString &coverUrl,
                                        const QString &url);

signals:
    void downloadStarted(const QString &cid);
    void downloadFinished(const QString &cid, const QString &localPath);
    void downloadFailed(const QString &cid);
    void transcodeStarted(const QString &cid);
    void transcodeFinished(const QString &cid, const QString &mp3Path);
    void downloadProgress(const QString &cid, qint64 received, qint64 total);

    void libraryDownloadFinished(const QString &cid, const QString &savedPath);
    void libraryDownloadFailed(const QString &cid, const QString &error);

private:
    struct PendingDownload {
        QString cid;
        QString url;
    };

    struct LibraryTarget {
        QString songName;
        QString artist;
        QString album;
        QString coverUrl;
    };

    // ★ 每个下载的限速窗口状态
    struct SpeedState {
        qint64 bytesThisSecond = 0;
        qint64 windowStart = 0;
    };

    QString m_cacheDir;
    QString m_ffmpegPath;
    QSet<QString> m_downloading;
    QSet<QString> m_transcoding;
    QQueue<PendingDownload> m_queue;
    int m_activeDownloads = 0;

    QHash<QString, LibraryTarget> m_libraryTargets;
    QHash<QString, SpeedState> m_speedStates;

    qint64 m_maxCacheSize = 2LL * 1024 * 1024 * 1024;
    static constexpr int MAX_CONCURRENT_DOWNLOADS = 2;

    // ★ 下载限速（默认 512 KB/s），-1 = 不限速
    qint64 m_speedLimitBytes = 512 * 1024;

    QNetworkAccessManager *m_manager;

    QString basePathFor(const QString &cid) const;
    QString wavPathFor(const QString &cid) const;
    QString mp3PathFor(const QString &cid) const;

    void ensureCacheDir();
    void cleanupPartFiles();
    void detectFfmpeg();
    void transcodeToMp3(const QString &cid, const QString &wavPath);

    void processQueue();
    void startActualDownload(const QString &cid, const QString &url);
    void finishDownload(const QString &cid);

    void enforceCacheLimit();

    QString downloadDir() const;

    void writeMetadataAndSave(const QString &cid,
                               const QString &srcPath,
                               const QString &title,
                               const QString &artist,
                               const QString &album,
                               const QString &coverUrl);

    void encodeWithFfmpeg(const QString &cid,
                           const QString &srcPath,
                           const QString &dstPath,
                           const QString &title,
                           const QString &artist,
                           const QString &album,
                           const QString &coverPath);

    void onCacheDownloadFinished(const QString &cid, const QString &localPath);
};