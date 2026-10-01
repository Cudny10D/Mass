#pragma once
#include <QObject>
#include <QSettings>
#include <QStringList>
#include <QNetworkAccessManager>

class Settings : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString audioQuality READ audioQuality WRITE setAudioQuality NOTIFY changed)
    Q_PROPERTY(bool translateLyric READ translateLyric WRITE setTranslateLyric NOTIFY changed)
    Q_PROPERTY(QString downloadPath READ downloadPath WRITE setDownloadPath NOTIFY changed)
    Q_PROPERTY(bool darkMode READ darkMode WRITE setDarkMode NOTIFY changed)
    Q_PROPERTY(double fontScale READ fontScale WRITE setFontScale NOTIFY fontScaleChanged)
    Q_PROPERTY(QString closeBehavior READ closeBehavior WRITE setCloseBehavior NOTIFY changed)
public:
    explicit Settings(QObject *parent = nullptr);

    QString audioQuality() const;
    void setAudioQuality(const QString &v);

    bool translateLyric() const;
    void setTranslateLyric(bool v);

    QString downloadPath() const;
    void setDownloadPath(const QString &v);

    bool darkMode() const;
    void setDarkMode(bool v);

    double fontScale() const;
    void setFontScale(double v);

    QString closeBehavior() const;
    void setCloseBehavior(const QString &v);

    Q_INVOKABLE QStringList getSearchHistory() const;
    Q_INVOKABLE void addSearchHistory(const QString &kw);
    Q_INVOKABLE void clearSearchHistory();

    Q_INVOKABLE QString pickFolder(const QString &title,
                                    const QString &currentPath);

    Q_INVOKABLE void openLogFolder() const;
    Q_INVOKABLE void openDownloadFolder() const;

    Q_INVOKABLE void restartApp();

    Q_INVOKABLE void checkForUpdates();
    Q_INVOKABLE QString currentVersion() const;
    Q_INVOKABLE void openUrl(const QString &url) const;

signals:
    void changed();
    void fontScaleChanged();

    void updateAvailable(const QString &version,
                         const QString &url,
                         const QString &notes);
    void updateNotAvailable(const QString &version);
    void updateCheckFailed(const QString &error);

private:
    QSettings m_s;
    QNetworkAccessManager *m_nam = nullptr;

    // ★ GitHub Releases API
    static constexpr const char *kGitHubApiUrl =
        "https://api.github.com/repos/Cudny10D/Mass/releases/latest";

    static constexpr const char *kCurrentVersion = "1.1.3";
};