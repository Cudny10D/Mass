#pragma once
#include <QObject>
#include <QColor>
#include <QSystemTrayIcon>
#include <QMenu>
#include <QWidgetAction>
#include <QWindow>
#include <QAction>

class AudioEngine;
class Settings;

class SystemTrayManager : public QObject {
    Q_OBJECT
public:
    explicit SystemTrayManager(QObject *parent = nullptr);
    ~SystemTrayManager();

    void setWindow(QWindow *window);
    void setAudioEngine(AudioEngine *engine);
    void setSettings(Settings *settings);

    Q_INVOKABLE void hideToTray();
    Q_INVOKABLE void showWindow();
    Q_INVOKABLE void quitApp();

    // 由 QML 调用更新菜单
    Q_INVOKABLE void setCurrentSong(const QString &title, const QString &artist);
    Q_INVOKABLE void setPlayingState(bool playing);

public slots:
    void onWindowOpacityChanged();

signals:
    void windowShown();
    void windowHidden();
    void windowFadeChanged(bool fading);
    void requestTogglePlay();
    void requestPlayPrev();
    void requestPlayNext();

private:
    void onTrayActivated(QSystemTrayIcon::ActivationReason reason);
    void updatePlayPauseText();
    void applyMenuStyle();
    void applyActionIcons(const QColor &color, const QColor &accent);
    void updateHeader(const QString &title, const QString &artist);

    QSystemTrayIcon *m_tray = nullptr;
    QMenu *m_menu = nullptr;
    QWidgetAction *m_headerAction = nullptr;
    QWidget *m_headerWidget = nullptr;
    QWindow *m_window = nullptr;
    AudioEngine *m_audioEngine = nullptr;
    Settings *m_settings = nullptr;

    QAction *m_showAction = nullptr;
    QAction *m_prevAction = nullptr;
    QAction *m_playPauseAction = nullptr;
    QAction *m_nextAction = nullptr;
    QAction *m_desktopLyricAction = nullptr;
    QAction *m_quitAction = nullptr;

    bool m_playing = false;
    bool m_windowFading = false;
};