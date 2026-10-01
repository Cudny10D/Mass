#pragma once
#include <QObject>
#include <QSystemTrayIcon>
#include <QMenu>
#include <QWindow>

class SystemTrayManager : public QObject {
    Q_OBJECT
public:
    explicit SystemTrayManager(QObject *parent = nullptr);
    ~SystemTrayManager();

    void setWindow(QWindow *window);

    Q_INVOKABLE void hideToTray();
    Q_INVOKABLE void showWindow();
    Q_INVOKABLE void quitApp();

signals:
    void windowShown();
    void windowHidden();

private:
    QSystemTrayIcon *m_tray;
    QMenu *m_menu;
    QWindow *m_window = nullptr;
    QAction *m_showAction;
    QAction *m_quitAction;
};