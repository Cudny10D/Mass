#include "SystemTrayManager.h"
#include "AudioEngine.h"
#include "Settings.h"
#include <QApplication>
#include <QIcon>
#include <QPainter>
#include <QPainterPath>
#include <QPolygonF>
#include <QPixmap>
#include <QLabel>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QFrame>
#include <QFontMetrics>
#include <QDebug>
#include <QVariant>
#include <QTimer>

// ============================================================
// 菜单图标：用 QPainter 画单色矢量图标
// 不用 Unicode 符号（⏮ ▶ ⏻ 之类）—— Windows 会把它们渲染成彩色 emoji，
// 在菜单里显得又花又不齐。自己画可以跟随主题上色。
// ============================================================
static QIcon makeVectorIcon(const QString &kind, const QColor &color) {
    constexpr int px = 32;      // 实际位图尺寸（菜单里缩到 ~16）
    constexpr qreal unit = 24.0; // 逻辑绘制栅格
    QPixmap pm(px, px);
    pm.fill(Qt::transparent);

    QPainter p(&pm);
    p.setRenderHint(QPainter::Antialiasing, true);
    p.scale(px / unit, px / unit);

    // 终端风：直角、细线，不用圆头圆角
    QPen pen(color, 1.5, Qt::SolidLine, Qt::SquareCap, Qt::MiterJoin);
    p.setPen(pen);
    p.setBrush(Qt::NoBrush);

    if (kind == QLatin1String("window")) {
        p.drawRect(QRectF(4, 5, 16, 14));
        p.drawLine(QPointF(4, 9.5), QPointF(20, 9.5));
        p.drawLine(QPointF(14, 5), QPointF(14, 9.5));
    } else if (kind == QLatin1String("prev")) {
        p.setBrush(color);
        QPolygonF t;
        t << QPointF(17, 6) << QPointF(8, 12) << QPointF(17, 18);
        p.drawPolygon(t);
        p.drawLine(QPointF(19.5, 6), QPointF(19.5, 18));
    } else if (kind == QLatin1String("next")) {
        p.setBrush(color);
        QPolygonF t;
        t << QPointF(7, 6) << QPointF(16, 12) << QPointF(7, 18);
        p.drawPolygon(t);
        p.drawLine(QPointF(4.5, 6), QPointF(4.5, 18));
    } else if (kind == QLatin1String("play")) {
        p.setBrush(color);
        QPolygonF t;
        t << QPointF(8, 5) << QPointF(19.5, 12) << QPointF(8, 19);
        p.drawPolygon(t);
    } else if (kind == QLatin1String("pause")) {
        p.setBrush(color);
        p.drawRect(QRectF(6.5, 5, 4, 14));
        p.drawRect(QRectF(13.5, 5, 4, 14));
    } else if (kind == QLatin1String("lyric")) {
        p.setBrush(color);
        p.drawEllipse(QPointF(9, 17), 3.4, 2.7);
        p.setBrush(Qt::NoBrush);
        p.drawLine(QPointF(12.2, 17), QPointF(12.2, 6.5));
        qreal ys[] = { 6.5, 7.6, 8.7, 9.8 };
        for (int i = 0; i < 4; ++i)
            p.drawLine(QPointF(12.2, ys[i]), QPointF(17.8, ys[i] + 1.2));
    } else if (kind == QLatin1String("power")) {
        p.drawArc(QRectF(5.5, 6.5, 13, 13), 120 * 16, 300 * 16);
        p.drawLine(QPointF(12, 4.5), QPointF(12, 12));
    }

    p.end();
    return QIcon(pm);
}

// 强调色：亮色用原色，暗色适当提亮，避免压在墨底上发闷
static QColor trayAccent(const Settings *settings, bool dark) {
    QColor c;
    if (settings) {
        const QString v = settings->accentColor();
        if (!v.isEmpty() && QColor::isValidColorName(v)) c = QColor(v);
    }
    if (!c.isValid()) c = QColor("#6E744C");
    return dark ? c.lighter(155) : c;
}


// ============================================================
// 备用图标
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

// ============================================================
// 菜单顶部的「正在播放」区块
// 用 QWidgetAction 承载，QAction 没法单独设字体/两行排版
// ============================================================
namespace {

class TrayHeader : public QWidget {
public:
    explicit TrayHeader(QWidget *parent = nullptr) : QWidget(parent) {
        setObjectName("trayHeader");

        auto *outer = new QHBoxLayout(this);
        outer->setContentsMargins(12, 10, 16, 10);
        outer->setSpacing(10);

        // 左侧 2px 强调色信号条
        m_bar = new QFrame(this);
        m_bar->setObjectName("trayAccentBar");
        m_bar->setFixedWidth(2);
        m_bar->setFrameShape(QFrame::NoFrame);
        outer->addWidget(m_bar);

        auto *col = new QVBoxLayout();
        col->setContentsMargins(0, 0, 0, 0);
        col->setSpacing(2);

        m_kicker = new QLabel(QStringLiteral("NOW PLAYING"), this);
        m_kicker->setObjectName("trayKicker");

        m_title = new QLabel(this);
        m_title->setObjectName("trayTitle");
        m_artist = new QLabel(this);
        m_artist->setObjectName("trayArtist");

        // 等宽小号大写标签，撑起「终端」气质
        QFont fk(QStringLiteral("Consolas"));
        fk.setPixelSize(9);
        fk.setLetterSpacing(QFont::AbsoluteSpacing, 1.8);
        m_kicker->setFont(fk);

        QFont ft(QStringLiteral("Microsoft YaHei"));
        ft.setPixelSize(13);
        ft.setBold(true);
        m_title->setFont(ft);

        QFont fa(QStringLiteral("Microsoft YaHei"));
        fa.setPixelSize(11);
        m_artist->setFont(fa);

        col->addWidget(m_kicker);
        col->addWidget(m_title);
        col->addWidget(m_artist);
        outer->addLayout(col, 1);
    }

    void setContent(const QString &title, const QString &artist, int maxWidth) {
        QFontMetrics tm(m_title->font());
        m_title->setText(tm.elidedText(title, Qt::ElideRight, maxWidth));

        QFontMetrics am(m_artist->font());
        m_artist->setText(am.elidedText(artist, Qt::ElideRight, maxWidth));
        m_artist->setVisible(!artist.isEmpty());
    }

    void setAccent(const QColor &accent) {
        m_bar->setStyleSheet(QStringLiteral("background-color: %1;")
                                 .arg(accent.name(QColor::HexRgb)));
        m_kicker->setStyleSheet(QStringLiteral("color: %1;")
                                    .arg(accent.name(QColor::HexRgb)));
    }

    QLabel *m_kicker = nullptr;
    QLabel *m_title = nullptr;
    QLabel *m_artist = nullptr;
    QFrame *m_bar = nullptr;
};

} // namespace

// ============================================================
// 构造
// ============================================================
SystemTrayManager::SystemTrayManager(QObject *parent)
    : QObject(parent) {

    QIcon icon(":/resources/app.ico");
    if (icon.isNull()) {
        qWarning() << "[Tray] app.ico not found, using generated icon";
        icon = generateFallbackIcon();
    }

    m_tray = new QSystemTrayIcon(icon, this);

    // -------- 菜单外观：直角面板 + 1px 细线 --------
    // 无边框 + 透明背景，圆角/直角由样式表负责；
    // 去掉系统投影，否则透明窗口的边角会露出黑块。
    m_menu = new QMenu();
    m_menu->setWindowFlags(m_menu->windowFlags()
                           | Qt::FramelessWindowHint
                           | Qt::NoDropShadowWindowHint);
    m_menu->setAttribute(Qt::WA_TranslucentBackground);
    m_menu->setMinimumWidth(260);

    QFont menuFont(QStringLiteral("Microsoft YaHei"));
    menuFont.setPixelSize(12);
    m_menu->setFont(menuFont);

    // -------- 正在播放（两行，标题 + 艺人） --------
    m_headerWidget = new TrayHeader();
    m_headerAction = new QWidgetAction(m_menu);
    m_headerAction->setDefaultWidget(m_headerWidget);
    m_menu->addAction(m_headerAction);

    m_menu->addSeparator();

    // -------- 显示窗口 --------
    m_showAction = m_menu->addAction(QStringLiteral("显示主窗口"));
    connect(m_showAction, &QAction::triggered,
            this, &SystemTrayManager::showWindow);

    m_menu->addSeparator();

    // -------- 播放控制 --------
    m_prevAction = m_menu->addAction(QStringLiteral("上一首"));
    m_playPauseAction = m_menu->addAction(QStringLiteral("播放"));
    m_nextAction = m_menu->addAction(QStringLiteral("下一首"));

    connect(m_prevAction, &QAction::triggered,
            this, &SystemTrayManager::requestPlayPrev);
    connect(m_playPauseAction, &QAction::triggered,
            this, &SystemTrayManager::requestTogglePlay);
    connect(m_nextAction, &QAction::triggered,
            this, &SystemTrayManager::requestPlayNext);

    m_menu->addSeparator();

    // -------- 桌面歌词（状态用文字后缀表示，隐藏原生勾选指示器） --------
    m_desktopLyricAction = m_menu->addAction(QStringLiteral("桌面歌词"));
    m_desktopLyricAction->setCheckable(true);
    connect(m_desktopLyricAction, &QAction::triggered, this, [this]() {
        if (m_settings) {
            m_settings->setDesktopLyricEnabled(
                !m_settings->desktopLyricEnabled());
        }
    });

    m_menu->addSeparator();

    // -------- 退出 --------
    m_quitAction = m_menu->addAction(QStringLiteral("退出"));
    connect(m_quitAction, &QAction::triggered,
            this, &SystemTrayManager::quitApp);

    // 每次弹出时按当前主题重新上色
    connect(m_menu, &QMenu::aboutToShow, this, [this]() {
        applyMenuStyle();
    });

    updateHeader(QStringLiteral("未播放"), QStringLiteral("Mass 音乐播放器"));
    applyMenuStyle();

    m_tray->setContextMenu(m_menu);
    m_tray->setToolTip("Mass 音乐播放器");
    m_tray->show();

    connect(m_tray, &QSystemTrayIcon::activated, this,
            [this](QSystemTrayIcon::ActivationReason r) {
        onTrayActivated(r);
    });

    // 仅用于截图核对菜单外观：
    //   MASS_TRAY_MENU_PREVIEW=1      → 自动弹出
    //   MASS_TRAY_MENU_PREVIEW=<png>  → 弹出后抓图保存再收起
    if (qEnvironmentVariableIsSet("MASS_TRAY_MENU_PREVIEW")) {
        const QString path = qEnvironmentVariable("MASS_TRAY_MENU_PREVIEW");
        QTimer::singleShot(2600, this, [this, path]() {
            m_menu->popup(QPoint(1400, 620));
            if (path.isEmpty() || path == QStringLiteral("1")) return;
            QTimer::singleShot(600, this, [this, path]() {
                m_menu->grab().save(path);
                qDebug() << "[Tray] menu snapshot saved to" << path;
                m_menu->hide();
            });
        });
    }

    qDebug() << "[Tray] initialized";
}

SystemTrayManager::~SystemTrayManager() {
    if (m_menu) {
        delete m_menu;
        m_menu = nullptr;
    }
}

// ============================================================
// 菜单外观
// 颜色与 qml/Theme.qml 的 token 保持一致：暖纸底 + 墨黑字 + 直角细线，
// 强调色跟随设置里的「主题色」。
// ============================================================
void SystemTrayManager::applyMenuStyle() {
    const bool dark = m_settings ? m_settings->darkMode() : false;
    const QColor accent = trayAccent(m_settings, dark);

    const QString bg     = dark ? "#232420" : "#F4F2EC";
    const QString border = dark ? "#3A3B33" : "#C7C3B8";
    const QString fg     = dark ? "#E7E5DC" : "#1B1C19";
    const QString dim    = dark ? "#A6A497" : "#5B5C55";
    const QString hover  = dark ? "#2A2B25" : "#E2DFD6";
    const QString sep    = dark ? "#2E2F29" : "#D9D5CB";

    m_menu->setStyleSheet(QStringLiteral(
        "QMenu {"
        "  background-color: %1;"
        "  border: 1px solid %2;"
        "  border-radius: 0px;"
        "  padding: 4px;"
        "  color: %3;"
        "  font-size: 12px;"
        "}"
        "QMenu::item {"
        "  background: transparent;"
        "  padding: 8px 20px 8px 32px;"
        "  margin: 0px;"
        "  border-radius: 0px;"
        "}"
        "QMenu::item:selected { background-color: %4; }"
        "QMenu::item:disabled { color: %5; }"
        "QMenu::separator { height: 1px; background: %6; margin: 5px 10px; }"
        "QMenu::indicator { width: 0px; height: 0px; }"
    ).arg(bg).arg(border).arg(fg).arg(hover).arg(dim).arg(sep));

    if (m_headerWidget) {
        m_headerWidget->setStyleSheet(QStringLiteral(
            "QLabel#trayTitle { color: %1; }"
            "QLabel#trayArtist { color: %2; }"
        ).arg(fg, dim));
        if (auto *header = static_cast<TrayHeader *>(m_headerWidget))
            header->setAccent(accent);
    }

    applyActionIcons(QColor(fg), accent);
    if (m_desktopLyricAction) {
        const bool lyricOn = m_desktopLyricAction->isChecked();
        m_desktopLyricAction->setText(lyricOn ? QStringLiteral("桌面歌词    ON")
                                              : QStringLiteral("桌面歌词"));
    }
}

void SystemTrayManager::applyActionIcons(const QColor &color, const QColor &accent) {
    if (m_showAction)
        m_showAction->setIcon(makeVectorIcon(QStringLiteral("window"), color));
    if (m_prevAction)
        m_prevAction->setIcon(makeVectorIcon(QStringLiteral("prev"), color));
    if (m_playPauseAction)
        m_playPauseAction->setIcon(makeVectorIcon(
            m_playing ? QStringLiteral("pause") : QStringLiteral("play"), accent));
    if (m_nextAction)
        m_nextAction->setIcon(makeVectorIcon(QStringLiteral("next"), color));
    if (m_desktopLyricAction)
        m_desktopLyricAction->setIcon(makeVectorIcon(
            QStringLiteral("lyric"),
            m_desktopLyricAction->isChecked() ? accent : color));
    if (m_quitAction)
        m_quitAction->setIcon(makeVectorIcon(QStringLiteral("power"), color));
}

void SystemTrayManager::updateHeader(const QString &title, const QString &artist) {
    auto *header = static_cast<TrayHeader *>(m_headerWidget);
    if (header) header->setContent(title, artist, 210);
}

// ============================================================
// 依赖注入
// ============================================================
void SystemTrayManager::setWindow(QWindow *window) {
    m_window = window;
}

void SystemTrayManager::onWindowOpacityChanged() {
    if (!m_window) return;
    const bool fading = m_window->property("windowOpacity").toReal() < 0.99;
    if (fading == m_windowFading) return;
    m_windowFading = fading;
    emit windowFadeChanged(fading);
}

void SystemTrayManager::setAudioEngine(AudioEngine *engine) {
    m_audioEngine = engine;
    if (m_audioEngine) {
        connect(m_audioEngine, &AudioEngine::playbackStateChanged,
                this, [this](bool playing) {
            m_playing = playing;
            updatePlayPauseText();
        });
    }
}

void SystemTrayManager::setSettings(Settings *settings) {
    m_settings = settings;
    if (m_settings) {
        m_desktopLyricAction->setChecked(m_settings->desktopLyricEnabled());
        applyMenuStyle();

        connect(m_settings, &Settings::changed, this, [this]() {
            const bool on = m_settings->desktopLyricEnabled();
            if (m_desktopLyricAction->isChecked() != on)
                m_desktopLyricAction->setChecked(on);
            // 主题 / 主题色 / 桌面歌词状态都可能变，统一重上一次色
            applyMenuStyle();
        });
    }
}

// ============================================================
// 更新菜单
// ============================================================
void SystemTrayManager::setCurrentSong(const QString &title,
                                        const QString &artist) {
    const QString headerTitle = title.isEmpty() ? QStringLiteral("未播放") : title;
    const QString headerArtist = title.isEmpty()
        ? QStringLiteral("Mass 音乐播放器")
        : (artist.isEmpty() ? QStringLiteral("未知艺术家") : artist);

    updateHeader(headerTitle, headerArtist);

    if (title.isEmpty()) {
        m_tray->setToolTip("Mass 音乐播放器");
    } else if (artist.isEmpty()) {
        m_tray->setToolTip("Mass 音乐播放器\n" + title);
    } else {
        m_tray->setToolTip("Mass 音乐播放器\n" + title + "\n" + artist);
    }
}

void SystemTrayManager::setPlayingState(bool playing) {
    m_playing = playing;
    updatePlayPauseText();
}

void SystemTrayManager::updatePlayPauseText() {
    if (!m_playPauseAction) return;

    m_playPauseAction->setText(m_playing ? QStringLiteral("暂停")
                                         : QStringLiteral("播放"));

    // 图标要跟着播放状态换（播放/暂停），用强调色强调当前可执行的动作
    const bool dark = m_settings ? m_settings->darkMode() : false;
    m_playPauseAction->setIcon(makeVectorIcon(
        m_playing ? QStringLiteral("pause") : QStringLiteral("play"),
        trayAccent(m_settings, dark)));
}

// ============================================================
// 窗口控制
// ============================================================
void SystemTrayManager::hideToTray() {
    if (!m_window) return;
    m_window->hide();
    emit windowHidden();
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
}

void SystemTrayManager::quitApp() {
    qDebug() << "[Tray] quitting app";
    QApplication::quit();
}

void SystemTrayManager::onTrayActivated(QSystemTrayIcon::ActivationReason reason) {
    if (reason == QSystemTrayIcon::Trigger ||
        reason == QSystemTrayIcon::DoubleClick) {
        if (m_window && m_window->isVisible()) {
            hideToTray();
        } else {
            showWindow();
        }
    }
}
