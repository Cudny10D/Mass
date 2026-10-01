#include "NetworkManager.h"
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QNetworkDiskCache>
#include <QStandardPaths>
#include <QUrlQuery>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include <QDebug>
#include <QRegularExpression>
#include <QStringList>
#include <memory>

static const char *kUserAgent =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36";

// ============================================================
// 从专辑对象抽艺术家字符串
// ============================================================
static QString albumArtistString(const QJsonObject &a) {
    auto extractArray = [](const QJsonArray &arr) -> QString {
        QStringList tmp;
        for (const auto &x : arr) {
            if (x.isString())      tmp << x.toString();
            else if (x.isObject()) tmp << x.toObject()["name"].toString();
        }
        return tmp.join(" / ");
    };

    if (a["artistes"].isArray())  return extractArray(a["artistes"].toArray());
    if (a["artistes"].isString()) return a["artistes"].toString();
    if (a["artists"].isArray())   return extractArray(a["artists"].toArray());
    if (a["artists"].isString())  return a["artists"].toString();
    if (a["artist"].isString())   return a["artist"].toString();

    return "";
}

// ============================================================
// 通用：从任意响应里提取专辑数组
// ============================================================
static QJsonArray extractAlbumsFromAny(const QJsonObject &o, bool *hasMore = nullptr) {
    QJsonArray result;
    bool more = false;

    QJsonObject data = o["data"].toObject();

    if (data["list"].isArray()) {
        result = data["list"].toArray();
        if (data.contains("end")) more = !data["end"].toBool();
    }
    else if (o["data"].isArray()) {
        result = o["data"].toArray();
    }
    else if (data["albums"].isArray()) {
        result = data["albums"].toArray();
    }
    else if (data["items"].isArray()) {
        result = data["items"].toArray();
    }
    else if (o["albums"].isArray()) {
        result = o["albums"].toArray();
    }
    else if (o["list"].isArray()) {
        result = o["list"].toArray();
    }

    if (hasMore) *hasMore = more;
    return result;
}

// ============================================================
// 构造
// ============================================================
NetworkManager::NetworkManager(QObject *parent)
    : QObject(parent), m_manager(new QNetworkAccessManager(this)) {

    // 保存指针方便后续查询大小 / 清空
    m_diskCache = new QNetworkDiskCache(this);
    QString cachePath = QStandardPaths::writableLocation(
        QStandardPaths::CacheLocation) + "/http";
    m_diskCache->setCacheDirectory(cachePath);
    m_diskCache->setMaximumCacheSize(1024 * 1024 * 1024);  // 1 GB
    m_manager->setCache(m_diskCache);

    qDebug() << "[Network] HTTP disk cache at:" << cachePath;
    qDebug() << "[Network] HTTP cache size limit: 1024 MB";
    qDebug() << "[Network] API base URL:" << BASE_URL;
}

// ============================================================
// HTTP 缓存：查询大小
// ============================================================
qint64 NetworkManager::httpCacheSize() const {
    return m_diskCache ? m_diskCache->cacheSize() : 0;
}

// ============================================================
// HTTP 缓存：清空（同时清内存缓存）
// ============================================================
void NetworkManager::clearHttpCache() {
    if (m_diskCache) {
        m_diskCache->clear();
    }
    clearCaches();   // 清内存级
    qDebug() << "[Network] HTTP + memory caches cleared";
}

// ============================================================
// 通用 GET JSON
// ============================================================
void NetworkManager::getJson(const QString &path,
                             std::function<void(const QJsonObject&)> cb) {
    QUrl url(BASE_URL + path);
    QNetworkRequest req{url};
    req.setHeader(QNetworkRequest::UserAgentHeader, kUserAgent);
    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    req.setAttribute(QNetworkRequest::CacheLoadControlAttribute,
                     QNetworkRequest::PreferCache);
    req.setAttribute(QNetworkRequest::CacheSaveControlAttribute, true);

    qDebug() << "[Network] GET" << url.toString();

    auto *reply = m_manager->get(req);
    connect(reply, &QNetworkReply::finished, this, [reply, cb, path]() {
        if (reply->error() == QNetworkReply::NoError) {
            QByteArray raw = reply->readAll();
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(raw, &err);
            if (err.error != QJsonParseError::NoError) {
                qWarning() << "[Network] JSON parse error on" << path
                           << ":" << err.errorString();
                cb(QJsonObject());
                reply->deleteLater();
                return;
            }
            cb(doc.object());
        } else {
            qWarning() << "[Network] error on" << path
                       << ":" << reply->errorString();
            cb(QJsonObject());
        }
        reply->deleteLater();
    });
}

// ============================================================
// 下载纯文本
// ============================================================
void NetworkManager::downloadText(const QString &url,
                                  std::function<void(const QString &)> cb) {
    QNetworkRequest req{QUrl(url)};
    req.setHeader(QNetworkRequest::UserAgentHeader, kUserAgent);
    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    req.setAttribute(QNetworkRequest::CacheLoadControlAttribute,
                     QNetworkRequest::PreferCache);
    req.setAttribute(QNetworkRequest::CacheSaveControlAttribute, true);

    auto *reply = m_manager->get(req);
    connect(reply, &QNetworkReply::finished, this, [reply, cb, url]() {
        QString text;
        if (reply->error() == QNetworkReply::NoError) {
            text = QString::fromUtf8(reply->readAll());
        } else {
            qWarning() << "[Network] download failed:" << url
                       << reply->errorString();
        }
        cb(text);
        reply->deleteLater();
    });
}

// ============================================================
// 确保 m_allAlbums 已加载
// ============================================================
void NetworkManager::ensureAllAlbums(std::function<void()> done) {
    if (m_allAlbumsLoaded) {
        done();
        return;
    }

    getJson("/albums", [this, done](const QJsonObject &o) {
        m_allAlbums = extractAlbumsFromAny(o);
        m_allAlbumsLoaded = true;
        qDebug() << "[Siren] cached" << m_allAlbums.size()
                 << "albums for local search";
        done();
    });
}

void NetworkManager::getAllAlbums() {
    ensureAllAlbums([this]() {
        qDebug() << "[Siren] emit" << m_allAlbums.size() << "albums";
        emit albumsReady(m_allAlbums);
    });
}

// ============================================================
// 本地搜索
// ============================================================
void NetworkManager::doLocalSearch(const QString &keyword) {
    QString kw = keyword.trimmed();

    if (kw.isEmpty()) {
        emit albumsReady(m_allAlbums);
        return;
    }

    QRegularExpression re(QRegularExpression::escape(kw),
                          QRegularExpression::CaseInsensitiveOption);

    QJsonArray hit;
    for (const auto &v : m_allAlbums) {
        QJsonObject a = v.toObject();
        QString name = a["name"].toString();
        QString artistStr = albumArtistString(a);

        bool matchName = re.match(name).hasMatch();
        bool matchArtist = !artistStr.isEmpty() && re.match(artistStr).hasMatch();

        if (matchName || matchArtist) hit.append(a);
    }

    qDebug() << "[Siren] local search" << kw << "→" << hit.size()
             << "hits (total" << m_allAlbums.size() << ")";
    emit albumsReady(hit);
}

// ============================================================
// 搜索专辑
// ============================================================
void NetworkManager::searchAlbums(const QString &keyword) {
    searchAlbumsWithPage(keyword, "");
}

void NetworkManager::searchAlbumsWithPage(const QString &keyword,
                                           const QString &lastCid) {
    QString kw = keyword.trimmed();
    if (kw.isEmpty()) {
        emit searchAlbumsFailed("关键词不能为空");
        return;
    }

    QUrlQuery q;
    q.addQueryItem("keyword", kw);
    if (!lastCid.isEmpty()) {
        q.addQueryItem("lastCid", lastCid);
    }

    QString path = "/search/album?" + q.toString();
    qDebug() << "[Search] remote:" << path;

    getJson(path, [this, kw](const QJsonObject &o) {
        bool hasMore = false;
        QJsonArray albums = extractAlbumsFromAny(o, &hasMore);

        qDebug() << "[Search] remote returned" << albums.size()
                 << "albums, hasMore:" << hasMore;

        if (albums.isEmpty()) {
            qDebug() << "[Search] remote empty, falling back to local";
            ensureAllAlbums([this, kw]() {
                doLocalSearch(kw);
                emit searchAlbumsReady(QJsonArray(), false);
            });
            return;
        }

        emit searchAlbumsReady(albums, hasMore);
    });
}

// ============================================================
// 解析专辑详情
// ============================================================
QJsonArray NetworkManager::parseAlbumSongs(const QJsonObject &o) {
    QJsonObject data = o["data"].toObject();

    if (data["songs"].isArray()) return data["songs"].toArray();
    if (data["list"].isArray())  return data["list"].toArray();
    if (o["songs"].isArray())    return o["songs"].toArray();

    return QJsonArray();
}

// ============================================================
// 专辑详情
// ============================================================
void NetworkManager::getAlbumDetail(const QString &albumCid) {
    auto it = m_albumDetailCache.find(albumCid);
    if (it != m_albumDetailCache.end()) {
        qDebug() << "[Cache] album detail hit:" << albumCid
                 << "(" << it->size() << "songs )";
        emit albumDetailReady(albumCid, *it);
        return;
    }

    getJson("/album/" + albumCid + "/detail",
            [this, albumCid](const QJsonObject &o) {
        QJsonArray songs = parseAlbumSongs(o);
        m_albumDetailCache.insert(albumCid, songs);
        qDebug() << "[Siren] album" << albumCid << "has"
                 << songs.size() << "songs (cached)";
        emit albumDetailReady(albumCid, songs);
    });
}

// ============================================================
// 歌曲信息
// ============================================================
void NetworkManager::fetchSongInfoInternal(const QString &songCid,
                                           bool isPrefetch) {
    auto it = m_songInfoCache.find(songCid);
    if (it != m_songInfoCache.end()) {
        qint64 age = QDateTime::currentMSecsSinceEpoch() - it->timestamp;
        if (age < SONG_URL_TTL) {
            qDebug() << "[Cache] song info hit:" << songCid
                     << "age:" << age << "ms";

            if (isPrefetch) {
                if (!it->url.isEmpty()) {
                    emit songUrlPrefetched(songCid, it->url);
                }
                return;
            }

            emit songUrlReady(it->url, songCid);

            if (!it->lyric.isEmpty() || !it->translated.isEmpty()) {
                emit lyricReady(it->lyric, it->translated);
                return;
            }

            if (!it->lyricUrl.isEmpty() || !it->transUrl.isEmpty()) {
                QString lUrl = it->lyricUrl;
                QString tUrl = it->transUrl;

                struct State {
                    QString lyric;
                    QString trans;
                    int pending = 0;
                    bool done = false;
                };
                auto st = std::make_shared<State>();
                if (!lUrl.isEmpty()) st->pending++;
                if (!tUrl.isEmpty()) st->pending++;

                if (st->pending == 0) {
                    emit lyricReady("", "");
                    return;
                }

                auto finishIfDone = [this, st, songCid]() {
                    if (st->done || st->pending > 0) return;
                    st->done = true;

                    if (m_songInfoCache.contains(songCid)) {
                        m_songInfoCache[songCid].lyric = st->lyric;
                        m_songInfoCache[songCid].translated = st->trans;
                    }
                    emit lyricReady(st->lyric, st->trans);
                };

                if (!lUrl.isEmpty()) {
                    downloadText(lUrl, [st, finishIfDone](const QString &s) {
                        st->lyric = s;
                        st->pending--;
                        finishIfDone();
                    });
                }
                if (!tUrl.isEmpty()) {
                    downloadText(tUrl, [st, finishIfDone](const QString &s) {
                        st->trans = s;
                        st->pending--;
                        finishIfDone();
                    });
                }
                return;
            }

            emit lyricReady("", "");
            return;
        } else {
            qDebug() << "[Cache] song url expired:" << songCid;
            m_songInfoCache.erase(it);
        }
    }

    getJson("/song/" + songCid, [this, songCid, isPrefetch](const QJsonObject &o) {
        QJsonObject data = o["data"].toObject();

        QString sourceUrl = data["sourceUrl"].toString();
        if (sourceUrl.isEmpty()) sourceUrl = data["url"].toString();

        QString inlineLyric = data["lyric"].toString();
        QString lyricUrl    = data["lyricUrl"].toString();
        QString inlineTrans = data["translatedLyric"].toString();
        QString transUrl    = data["translatedLyricUrl"].toString();

        SongCache sc;
        sc.url         = sourceUrl;
        sc.lyric       = inlineLyric;
        sc.translated  = inlineTrans;
        sc.lyricUrl    = lyricUrl;
        sc.transUrl    = transUrl;
        sc.timestamp   = QDateTime::currentMSecsSinceEpoch();
        m_songInfoCache.insert(songCid, sc);

        qDebug() << "[Siren] song" << songCid
                 << "sourceUrl:" << (sourceUrl.isEmpty() ? "(empty)" : "(ok)")
                 << "lyric:" << (inlineLyric.isEmpty() ? "(need fetch)" : "(inline)")
                 << "trans:" << (inlineTrans.isEmpty() ? "(need fetch)" : "(inline)");

        if (isPrefetch) {
            if (!sourceUrl.isEmpty()) {
                emit songUrlPrefetched(songCid, sourceUrl);
            }
            qDebug() << "[Prefetch] done:" << songCid;
            return;
        }

        emit songUrlReady(sourceUrl, songCid);

        bool needLyricFetch = inlineLyric.isEmpty() && !lyricUrl.isEmpty();
        bool needTransFetch = inlineTrans.isEmpty() && !transUrl.isEmpty();

        if (!needLyricFetch && !needTransFetch) {
            emit lyricReady(inlineLyric, inlineTrans);
            return;
        }

        struct State {
            QString lyric;
            QString trans;
            int pending = 0;
            bool done = false;
        };
        auto st = std::make_shared<State>();
        st->lyric = inlineLyric;
        st->trans = inlineTrans;
        if (needLyricFetch) st->pending++;
        if (needTransFetch) st->pending++;

        auto finishIfDone = [this, st, songCid]() {
            if (st->done || st->pending > 0) return;
            st->done = true;

            if (m_songInfoCache.contains(songCid)) {
                m_songInfoCache[songCid].lyric = st->lyric;
                m_songInfoCache[songCid].translated = st->trans;
            }

            qDebug() << "[Siren] lyric ready (async). lyric len:"
                     << st->lyric.length()
                     << "trans len:" << st->trans.length();
            emit lyricReady(st->lyric, st->trans);
        };

        if (needLyricFetch) {
            qDebug() << "[Siren] fetching lyric:" << lyricUrl;
            downloadText(lyricUrl, [st, finishIfDone](const QString &s) {
                st->lyric = s;
                st->pending--;
                finishIfDone();
            });
        }
        if (needTransFetch) {
            qDebug() << "[Siren] fetching translation:" << transUrl;
            downloadText(transUrl, [st, finishIfDone](const QString &s) {
                st->trans = s;
                st->pending--;
                finishIfDone();
            });
        }
    });
}

void NetworkManager::getSongInfo(const QString &songCid) {
    fetchSongInfoInternal(songCid, false);
}

void NetworkManager::prefetchSongInfo(const QString &songCid) {
    auto it = m_songInfoCache.find(songCid);
    if (it != m_songInfoCache.end()) {
        qint64 age = QDateTime::currentMSecsSinceEpoch() - it->timestamp;
        if (age < SONG_URL_TTL) {
            qDebug() << "[Prefetch] skip (cached):" << songCid;
            if (!it->url.isEmpty()) {
                emit songUrlPrefetched(songCid, it->url);
            }
            return;
        }
    }

    qDebug() << "[Prefetch] fetching:" << songCid;
    fetchSongInfoInternal(songCid, true);
}

void NetworkManager::clearCaches() {
    m_albumDetailCache.clear();
    m_songInfoCache.clear();
    m_allAlbums = QJsonArray();
    m_allAlbumsLoaded = false;
    qDebug() << "[Cache] memory caches cleared";
}