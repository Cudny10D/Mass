#include "PlaylistManager.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDateTime>
#include <QFile>
#include <QFileInfo>
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
        for (const auto &v : songs) {
            if (v.toMap()["cid"].toString() == cid) return false;
        }

        QVariantMap song;
        song["cid"] = cid;
        song["name"] = name;
        song["artist"] = artist;
        song["cover"] = cover;
        songs.append(song);
        pl["songs"] = songs;

        bool customCover = pl.value("customCover", false).toBool();
        if (!customCover && !cover.isEmpty()) pl["cover"] = cover;

        m_playlists[i] = pl;
        save();
        emit playlistsChanged();
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

        bool customCover = pl.value("customCover", false).toBool();
        if (!customCover) {
            if (songs.isEmpty()) pl["cover"] = "";
            else pl["cover"] = songs.first().toMap()["cover"].toString();
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

int PlaylistManager::playlistCount(const QString &playlistId) const {
    return getPlaylistSongs(playlistId).size();
}

// ============================================================
// 导出 / 导入
// ============================================================
bool PlaylistManager::exportPlaylist(const QString &id, const QString &filePath) {
    if (id.isEmpty() || filePath.isEmpty()) return false;

    QVariantMap target;
    for (const auto &v : m_playlists) {
        QVariantMap pl = v.toMap();
        if (pl["id"].toString() == id) {
            target = pl;
            break;
        }
    }
    if (target.isEmpty()) return false;

    QJsonObject root;
    root["version"]     = 1;
    root["type"]        = "mass-playlist";
    root["name"]        = target["name"].toString();
    root["cover"]       = target["cover"].toString();
    root["exportedAt"]  = QDateTime::currentDateTime().toString(Qt::ISODate);

    QJsonArray songsArr;
    for (const auto &v : target["songs"].toList()) {
        QVariantMap s = v.toMap();
        QJsonObject so;
        so["cid"]    = s["cid"].toString();
        so["name"]   = s["name"].toString();
        so["artist"] = s["artist"].toString();
        so["cover"]  = s["cover"].toString();
        songsArr.append(so);
    }
    root["songs"] = songsArr;

    QJsonDocument doc(root);
    QFile f(filePath);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "[Playlist] export failed:" << filePath;
        return false;
    }
    f.write(doc.toJson(QJsonDocument::Indented));
    f.close();

    qDebug() << "[Playlist] exported" << target["name"].toString()
             << "with" << songsArr.size() << "songs to" << filePath;
    return true;
}

int PlaylistManager::importPlaylist(const QString &filePath) {
    QFile f(filePath);
    if (!f.open(QIODevice::ReadOnly)) {
        qWarning() << "[Playlist] import failed:" << filePath;
        return 0;
    }

    QByteArray data = f.readAll();
    f.close();

    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(data, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "[Playlist] import parse error:" << err.errorString();
        return 0;
    }

    QJsonObject root = doc.object();
    if (root["type"].toString() != "mass-playlist") {
        qWarning() << "[Playlist] not a mass-playlist file";
        return 0;
    }

    QString name = root["name"].toString();
    if (name.isEmpty()) name = "导入的歌单";

    // 避免重名
    QString finalName = name;
    int suffix = 1;
    bool nameConflict = true;
    while (nameConflict) {
        nameConflict = false;
        for (const auto &v : m_playlists) {
            if (v.toMap()["name"].toString() == finalName) {
                nameConflict = true;
                break;
            }
        }
        if (nameConflict) {
            finalName = name + " (" + QString::number(++suffix) + ")";
        }
    }

    QVariantList songs;
    int songCount = 0;
    for (const auto &v : root["songs"].toArray()) {
        QJsonObject so = v.toObject();
        QVariantMap song;
        song["cid"]    = so["cid"].toString();
        song["name"]   = so["name"].toString();
        song["artist"] = so["artist"].toString();
        song["cover"]  = so["cover"].toString();
        if (!song["cid"].toString().isEmpty()) {
            songs.append(song);
            ++songCount;
        }
    }

    QVariantMap pl;
    pl["id"] = QString::number(QDateTime::currentMSecsSinceEpoch());
    pl["name"] = finalName;
    pl["cover"] = root["cover"].toString();
    pl["customCover"] = false;
    pl["createdAt"] = QDateTime::currentMSecsSinceEpoch();
    pl["songs"] = songs;
    pl["imported"] = true;

    m_playlists.prepend(pl);
    save();
    emit playlistsChanged();

    qDebug() << "[Playlist] imported" << finalName
             << "with" << songCount << "songs";

    return 1;   // 返回 1 表示成功导入 1 个歌单
}