#pragma once
#include <QObject>
#include <QSettings>
#include <QTimer>
#include <QStringList>
#include <QVariantList>
#include <QNetworkAccessManager>

class Settings : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString audioQuality READ audioQuality WRITE setAudioQuality NOTIFY changed)
    Q_PROPERTY(bool translateLyric READ translateLyric WRITE setTranslateLyric NOTIFY changed)
    Q_PROPERTY(bool apiTranslate READ apiTranslate WRITE setApiTranslate NOTIFY changed)
    Q_PROPERTY(double volumeDefault READ volumeDefault WRITE setVolumeDefault NOTIFY changed)
    Q_PROPERTY(int loopMode READ loopMode WRITE setLoopMode NOTIFY changed)
    Q_PROPERTY(bool seekPreview READ seekPreview WRITE setSeekPreview NOTIFY changed)
    Q_PROPERTY(bool crossfade READ crossfade WRITE setCrossfade NOTIFY changed)
    Q_PROPERTY(int httpCacheMb READ httpCacheMb WRITE setHttpCacheMb NOTIFY changed)
    Q_PROPERTY(int imageCacheMb READ imageCacheMb WRITE setImageCacheMb NOTIFY changed)
    Q_PROPERTY(bool prefetchNext READ prefetchNext WRITE setPrefetchNext NOTIFY changed)
    Q_PROPERTY(int dockTriggerWidth READ dockTriggerWidth WRITE setDockTriggerWidth NOTIFY changed)
    Q_PROPERTY(int playerTriggerHeight READ playerTriggerHeight WRITE setPlayerTriggerHeight NOTIFY changed)
    Q_PROPERTY(double glassNoise READ glassNoise WRITE setGlassNoise NOTIFY changed)
    Q_PROPERTY(double glassTint READ glassTint WRITE setGlassTint NOTIFY changed)
    Q_PROPERTY(bool checkUpdate READ checkUpdate WRITE setCheckUpdate NOTIFY changed)
    Q_PROPERTY(bool rememberGeometry READ rememberGeometry WRITE setRememberGeometry NOTIFY changed)
    Q_PROPERTY(int winX READ winX WRITE setWinX NOTIFY changed)
    Q_PROPERTY(int winY READ winY WRITE setWinY NOTIFY changed)
    Q_PROPERTY(int winW READ winW WRITE setWinW NOTIFY changed)
    Q_PROPERTY(int winH READ winH WRITE setWinH NOTIFY changed)
    Q_PROPERTY(QString downloadPath READ downloadPath WRITE setDownloadPath NOTIFY changed)
    Q_PROPERTY(bool darkMode READ darkMode NOTIFY changed)
    Q_PROPERTY(QString themeMode READ themeMode WRITE setThemeMode NOTIFY changed)
    Q_PROPERTY(QString accentColor READ accentColor WRITE setAccentColor NOTIFY changed)
    Q_PROPERTY(double fontScale READ fontScale WRITE setFontScale NOTIFY fontScaleChanged)
    Q_PROPERTY(QString closeBehavior READ closeBehavior WRITE setCloseBehavior NOTIFY changed)
    Q_PROPERTY(bool desktopLyricEnabled READ desktopLyricEnabled WRITE setDesktopLyricEnabled NOTIFY changed)
    Q_PROPERTY(QString backgroundImage READ backgroundImage WRITE setBackgroundImage NOTIFY changed)
    Q_PROPERTY(int localSongCount READ localSongCount NOTIFY localSongsChanged)

public:
    explicit Settings(QObject *parent = nullptr);

    QString audioQuality() const;
    void setAudioQuality(const QString &v);

    bool translateLyric() const;
    void setTranslateLyric(bool v);

    bool apiTranslate() const;

    // ---- 可调设置 ----
    double volumeDefault() const;
    void setVolumeDefault(double v);
    int loopMode() const;
    void setLoopMode(int v);
    bool seekPreview() const;
    void setSeekPreview(bool v);
    bool crossfade() const;
    void setCrossfade(bool v);
    int httpCacheMb() const;
    void setHttpCacheMb(int v);
    int imageCacheMb() const;
    void setImageCacheMb(int v);
    bool prefetchNext() const;
    void setPrefetchNext(bool v);
    int dockTriggerWidth() const;
    void setDockTriggerWidth(int v);
    int playerTriggerHeight() const;
    void setPlayerTriggerHeight(int v);
    double glassNoise() const;
    void setGlassNoise(double v);
    double glassTint() const;
    void setGlassTint(double v);
    bool checkUpdate() const;
    void setCheckUpdate(bool v);
    bool rememberGeometry() const;

    // ---- 窗口几何 ----
    int winX() const;
    void setWinX(int v);
    int winY() const;
    void setWinY(int v);
    int winW() const;
    void setWinW(int v);
    int winH() const;
    void setWinH(int v);
    void setRememberGeometry(bool v);
    void setApiTranslate(bool v);

    QString downloadPath() const;
    void setDownloadPath(const QString &v);

    bool darkMode() const;                 // 由 themeMode 推导
    QString themeMode() const;
    void setThemeMode(const QString &v);

    // 强调色：#RRGGBB；空串表示使用内置默认（橄榄绿）
    QString accentColor() const;
    void setAccentColor(const QString &v);

    double fontScale() const;
    void setFontScale(double v);

    QString closeBehavior() const;
    void setCloseBehavior(const QString &v);

    bool desktopLyricEnabled() const;
    void setDesktopLyricEnabled(bool v);

    QString backgroundImage() const;
    void setBackgroundImage(const QString &v);

    int localSongCount() const;

    Q_INVOKABLE QStringList getSearchHistory() const;
    Q_INVOKABLE void addSearchHistory(const QString &kw);
    Q_INVOKABLE void clearSearchHistory();

    Q_INVOKABLE QString pickFolder(const QString &title, const QString &currentPath);
    Q_INVOKABLE QString pickSaveFile(const QString &title, const QString &defaultName);
    Q_INVOKABLE QString pickOpenFile(const QString &title, const QString &filter);
    Q_INVOKABLE QStringList pickOpenFiles(const QString &title, const QString &filter);

    // 本地库
    Q_INVOKABLE QVariantList getLocalSongs() const;
    Q_INVOKABLE void addLocalSong(const QString &filePath,
                                  const QString &title,
                                  const QString &artist,
                                  const QString &coverPath,
                                  const QString &lyricPath);
    Q_INVOKABLE void removeLocalSong(const QString &filePath);
    Q_INVOKABLE void clearLocalSongs();
    Q_INVOKABLE void updateLocalSong(const QString &filePath,
                                     const QString &title,
                                     const QString &artist,
                                     const QString &coverPath,
                                     const QString &lyricPath);

    // 文件工具
    Q_INVOKABLE QString readTextFile(const QString &path) const;
    Q_INVOKABLE QString findSidecarFile(const QString &audioPath,
                                        const QStringList &extensions) const;
    Q_INVOKABLE QString baseNameOf(const QString &path) const;

    Q_INVOKABLE void openLogFolder() const;
    Q_INVOKABLE void openDownloadFolder() const;

    Q_INVOKABLE QString backgroundsDir() const;
    Q_INVOKABLE QVariantList getBackgrounds() const;
    Q_INVOKABLE void openBackgroundsFolder() const;

    Q_INVOKABLE void restartApp();

    Q_INVOKABLE void checkForUpdates();
    Q_INVOKABLE QString currentVersion() const;
    Q_INVOKABLE void openUrl(const QString &url) const;

signals:
    void changed();
    void fontScaleChanged();
    void localSongsChanged();

    void updateAvailable(const QString &version,
                         const QString &url,
                         const QString &notes);
    void updateNotAvailable(const QString &version);
    void updateCheckFailed(const QString &error);

private:
    QSettings m_s;
    QNetworkAccessManager *m_nam = nullptr;
    QTimer m_themeTimer;
    bool   m_lastSystemDark = true;

    bool systemPrefersDark() const;

    QVariantList loadLocalSongs() const;
    void saveLocalSongs(const QVariantList &list);

    static constexpr const char *kGitHubApiUrl =
        "https://api.github.com/repos/Cudny10D/Mass/releases/latest";
    static constexpr const char *kCurrentVersion = "1.3.0";
};