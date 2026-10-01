#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QJsonArray>
#include <QJsonObject>
#include <QHash>
#include <QString>
#include <functional>

class QNetworkDiskCache;

class NetworkManager : public QObject {
    Q_OBJECT
public:
    explicit NetworkManager(QObject *parent = nullptr);

    QNetworkAccessManager *manager() const { return m_manager; }

    // ============================================================
    // HTTP 磁盘缓存（封面 / 歌词 / API 响应）
    // ============================================================
    Q_INVOKABLE qint64 httpCacheSize() const;
    Q_INVOKABLE void clearHttpCache();

    Q_INVOKABLE void getAllAlbums();
    Q_INVOKABLE void searchAlbums(const QString &keyword);
    Q_INVOKABLE void searchAlbumsWithPage(const QString &keyword,
                                           const QString &lastCid = "");
    Q_INVOKABLE void getAlbumDetail(const QString &albumCid);
    Q_INVOKABLE void getSongInfo(const QString &songCid);
    Q_INVOKABLE void prefetchSongInfo(const QString &songCid);
    Q_INVOKABLE void clearCaches();

signals:
    void albumsReady(const QJsonArray &albums);
    void albumDetailReady(const QString &albumCid, const QJsonArray &songs);
    void songUrlReady(const QString &url, const QString &songCid);
    void lyricReady(const QString &lyric, const QString &translated);
    void songUrlPrefetched(const QString &songCid, const QString &url);
    void searchAlbumsReady(const QJsonArray &albums, bool hasMore);
    void searchAlbumsFailed(const QString &error);

private:
    QNetworkAccessManager *m_manager;
    QNetworkDiskCache *m_diskCache = nullptr;

    const QString BASE_URL = "http://localhost:3000";

    QJsonArray m_allAlbums;
    bool m_allAlbumsLoaded = false;

    QHash<QString, QJsonArray> m_albumDetailCache;

    struct SongCache {
        QString url;
        QString lyric;
        QString translated;
        QString lyricUrl;
        QString transUrl;
        qint64  timestamp = 0;
    };
    QHash<QString, SongCache> m_songInfoCache;

    static constexpr qint64 SONG_URL_TTL = 3600 * 1000;

    void getJson(const QString &path,
                 std::function<void(const QJsonObject&)> cb);
    void downloadText(const QString &url,
                      std::function<void(const QString &)> cb);
    void ensureAllAlbums(std::function<void()> done);
    void doLocalSearch(const QString &keyword);
    void fetchSongInfoInternal(const QString &songCid, bool isPrefetch);
    QJsonArray parseAlbumSongs(const QJsonObject &o);
};