#pragma once
#include <QObject>
#include <QVariantList>
#include <QSettings>

class PlaylistManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList playlists READ playlists NOTIFY playlistsChanged)
public:
    explicit PlaylistManager(QObject *parent = nullptr);

    QVariantList playlists() const { return m_playlists; }

    Q_INVOKABLE QString createPlaylist(const QString &name);
    Q_INVOKABLE void deletePlaylist(const QString &id);
    Q_INVOKABLE void renamePlaylist(const QString &id, const QString &name);
    Q_INVOKABLE void setPlaylistCover(const QString &id, const QString &coverPath);

    Q_INVOKABLE bool addSong(const QString &playlistId, const QString &cid,
                             const QString &name, const QString &artist,
                             const QString &cover);
    Q_INVOKABLE void removeSong(const QString &playlistId, const QString &cid);

    Q_INVOKABLE QVariantList getPlaylistSongs(const QString &playlistId) const;
    Q_INVOKABLE bool hasSong(const QString &playlistId, const QString &cid) const;
    Q_INVOKABLE int playlistCount(const QString &playlistId) const;

signals:
    void playlistsChanged();

private:
    void save();
    void load();
    QVariantList m_playlists;
    QSettings m_settings;
};