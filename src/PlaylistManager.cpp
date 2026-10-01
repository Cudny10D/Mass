#include "PlaylistManager.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDateTime>
#include <QDebug>

PlaylistManager::PlaylistManager(QObject *parent)
    : QObject(parent),
      m_settings("ArknightsMusicPlayer", "playlists") {
    load();
    qDebug() << "[Playlist] loaded" << m_playlists.size() << "playlists";
}

void PlaylistManager::load() {
    QString json = m_settings.value("items").toString();
    m_playlists.clear();
    if (json.isEmpty()) return;

    QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    if (!doc.isArray()) return;

    for (const auto &v : doc.array()) {
        m_playlists.append(v.toObject().toVariantMap());
    }
}

void PlaylistManager::save() {
    QJsonArray arr;
    for (const auto &v : m_playlists) {
        arr.append(QJsonObject::fromVariantMap(v.toMap()));
    }
    QJsonDocument doc(arr);
    m_settings.setValue("items",
        QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));
}

QString PlaylistManager::createPlaylist(const QString &name) {
    QString id = QString::number(QDateTime::currentMSecsSinceEpoch());

    QVariantMap pl;
    pl["id"] = id;
    pl["name"] = name;
    pl["cover"] = "";
    pl["customCover"] = false;
    pl["createdAt"] = QDateTime::currentMSecsSinceEpoch();
    pl["songs"] = QVariantList();

    m_playlists.prepend(pl);
    save();
    emit playlistsChanged();

    qDebug() << "[Playlist] created:" << name << "id:" << id;
    return id;
}

void PlaylistManager::deletePlaylist(const QString &id) {
    for (int i = m_playlists.size() - 1; i >= 0; --i) {
        if (m_playlists[i].toMap()["id"].toString() == id) {
            m_playlists.removeAt(i);
            save();
            emit playlistsChanged();
            qDebug() << "[Playlist] deleted:" << id;
            return;
        }
    }
}

void PlaylistManager::renamePlaylist(const QString &id, const QString &name) {
    for (int i = 0; i < m_playlists.size(); ++i) {
        QVariantMap pl = m_playlists[i].toMap();
        if (pl["id"].toString() == id) {
            pl["name"] = name;
            m_playlists[i] = pl;
            save();
            emit playlistsChanged();
            return;
        }
    }
}

void PlaylistManager::setPlaylistCover(const QString &id, const QString &coverPath) {
    for (int i = 0; i < m_playlists.size(); ++i) {
        QVariantMap pl = m_playlists[i].toMap();
        if (pl["id"].toString() == id) {
            pl["cover"] = coverPath;
            pl["customCover"] = !coverPath.isEmpty();
            m_playlists[i] = pl;
            save();
            emit playlistsChanged();
            qDebug() << "[Playlist] cover set for" << pl["name"].toString()
                     << "->" << coverPath;
            return;
        }
    }
}

bool PlaylistManager::addSong(const QString &playlistId, const QString &cid,
                              const QString &name, const QString &artist,
                              const QString &cover) {
    for (int i = 0; i < m_playlists.size(); ++i) {
        QVariantMap pl = m_playlists[i].toMap();
        if (pl["id"].toString() != playlistId) continue;

        QVariantList songs = pl["songs"].toList();

        // 去重
        for (const auto &v : songs) {
            if (v.toMap()["cid"].toString() == cid) {
                qDebug() << "[Playlist] song already exists";
                return false;
            }
        }

        QVariantMap song;
        song["cid"] = cid;
        song["name"] = name;
        song["artist"] = artist;
        song["cover"] = cover;
        songs.append(song);

        pl["songs"] = songs;

        // 自动封面：用户没手动设过，就用最新加入的歌曲封面
        bool customCover = pl.value("customCover", false).toBool();
        if (!customCover && !cover.isEmpty()) {
            pl["cover"] = cover;
            qDebug() << "[Playlist] auto cover set from new song:" << name;
        }

        m_playlists[i] = pl;

        save();
        emit playlistsChanged();
        qDebug() << "[Playlist] added to" << pl["name"].toString();
        return true;
    }
    return false;
}

void PlaylistManager::removeSong(const QString &playlistId, const QString &cid) {
    for (int i = 0; i < m_playlists.size(); ++i) {
        QVariantMap pl = m_playlists[i].toMap();
        if (pl["id"].toString() != playlistId) continue;

        QVariantList songs = pl["songs"].toList();
        for (int j = songs.size() - 1; j >= 0; --j) {
            if (songs[j].toMap()["cid"].toString() == cid) {
                songs.removeAt(j);
            }
        }

        pl["songs"] = songs;

        // 用户没手动设过封面 → 用第一首歌的封面；歌单空了 → 清空
        bool customCover = pl.value("customCover", false).toBool();
        if (!customCover) {
            if (songs.isEmpty()) {
                pl["cover"] = "";
            } else {
                pl["cover"] = songs.first().toMap()["cover"].toString();
            }
        }

        m_playlists[i] = pl;

        save();
        emit playlistsChanged();
        return;
    }
}

QVariantList PlaylistManager::getPlaylistSongs(const QString &playlistId) const {
    for (const auto &v : m_playlists) {
        QVariantMap pl = v.toMap();
        if (pl["id"].toString() == playlistId) {
            return pl["songs"].toList();
        }
    }
    return QVariantList();
}

bool PlaylistManager::hasSong(const QString &playlistId, const QString &cid) const {
    QVariantList songs = getPlaylistSongs(playlistId);
    for (const auto &v : songs) {
        if (v.toMap()["cid"].toString() == cid) return true;
    }
    return false;
}

int PlaylistManager::playlistCount(const QString &playlistId) const {
    return getPlaylistSongs(playlistId).size();
}