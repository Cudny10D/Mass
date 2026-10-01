#include "SystemTrayManager.h"
#include <QApplication>
#include <QIcon>
#include <QPainter>
#include <QPixmap>
#include <QDebug>

// ============================================================
// 代码生成的备用图标（资源加载失败时用）
// ============================================================
static QIcon generateFallbackIcon() {
    QPixmap pix(64, 64);
    pix.fill(Qt::transparent);

    QPainter p(&pix);
    p.setRenderHint(QPainter::Antialiasing);
    p.setBrush(QColor("#007ACC"));
    p.setPen(Qt::NoPen);
    p.drawEllipse(4, 4, 56, 56);

    p.setPen(Qt::white);
    QFont font = p.font();
    font.setPixelSize(34);
    font.setBold(true);
    p.setFont(font);
    p.drawText(pix.rect(), Qt::AlignCenter, "♪");
    p.end();

    return QIcon(pix);
}

SystemTrayManager::SystemTrayManager(QObject *parent)
    : QObject(parent) {

    // ============================================================
    // ★ 加载图标：优先资源，失败回退代码生成
    // ============================================================
    QIcon icon(":/resources/app.ico");

    if (icon.isNull()) {
        qWarning() << "[Tray] app.ico not found in resources, "
                   << "using generated fallback icon";
        icon = generateFallbackIcon();
    } else {
        qDebug() << "[Tray] loaded icon from resources";
    }

    m_tray = new QSystemTrayIcon(icon, this);

    m_menu = new QMenu();

    m_showAction = m_menu->addAction("显示主窗口");
    m_menu->addSeparator();
    m_quitAction = m_menu->addAction("退出");

    connect(m_showAction, &QAction::triggered,
            this, &SystemTrayManager::showWindow);
    connect(m_quitAction, &QAction::triggered,
            this, &SystemTrayManager::quitApp);

    m_tray->setContextMenu(m_menu);
    m_tray->setToolTip("Monster Siren Records");
    m_tray->show();

    connect(m_tray, &QSystemTrayIcon::activated, this,
            [this](QSystemTrayIcon::ActivationReason reason) {
        if (reason == QSystemTrayIcon::Trigger ||
            reason == QSystemTrayIcon::DoubleClick) {
            if (m_window && m_window->isVisible()) {
                hideToTray();
            } else {
                showWindow();
            }
        }
    });

    qDebug() << "[Tray] initialized";
}

SystemTrayManager::~SystemTrayManager() {
    if (m_menu) {
        delete m_menu;
        m_menu = nullptr;
    }
}

void SystemTrayManager::setWindow(QWindow *window) {
    m_window = window;
}

void SystemTrayManager::hideToTray() {
    if (!m_window) return;
    m_window->hide();
    emit windowHidden();
    qDebug() << "[Tray] window hidden to tray";
}

void SystemTrayManager::showWindow() {
    if (!m_window) return;
    m_window->show();
    m_window->raise();
    m_window->requestActivate();

    if (m_window->visibility() == QWindow::Minimized) {
        m_window->showNormal();
    }

    emit windowShown();
    qDebug() << "[Tray] window shown";
}

void SystemTrayManager::quitApp() {
    qDebug() << "[Tray] quitting app";
    QApplication::quit();
}