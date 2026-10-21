#include <QApplication>
#include <QSettings>
#include <QQuickStyle>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlNetworkAccessManagerFactory>
#include <QNetworkAccessManager>
#include <QNetworkDiskCache>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QStandardPaths>
#include <QProcess>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QThread>
#include <QWindow>
#include <QIcon>
#include <QTcpSocket>
#include <QTimer>
#include <QEventLoop>
#include <QUrl>
#include <QDebug>
#include <QDateTime>
#include <QTextStream>
#include <QMutex>
#include <QRegularExpression>
#include <QSet>
#include <QLockFile>
#include <QLocalServer>
#include <QLocalSocket>
#include <cstdio>
#include <cstdlib>

#ifdef Q_OS_WIN
#include <windows.h>
#endif

#include "NetworkManager.h"
#include "AudioEngine.h"
#include "AudioCache.h"
#include "AudioMetadataProbe.h"
#include "CoverCache.h"
#include "TranslationService.h"
#include "Settings.h"
#include "HistoryManager.h"
#include "PlaylistManager.h"
#include "SystemTrayManager.h"

static const char *kSingleInstanceKey = "Mass_SingleInstance_8E5F9A1B";

// ============================================================
// 日志
// ============================================================
static QFile       *g_logFile = nullptr;
static QTextStream *g_logStream = nullptr;
static QMutex       g_logMutex;

static void messageHandler(QtMsgType type,
                           const QMessageLogContext &context,
                           const QString &msg)
{
    Q_UNUSED(context)

    QString level;
    switch (type) {
    case QtDebugMsg:    level = "DEBUG"; break;
    case QtInfoMsg:     level = "INFO "; break;
    case QtWarningMsg:  level = "WARN "; break;
    case QtCriticalMsg: level = "CRIT "; break;
    case QtFatalMsg:    level = "FATAL"; break;
    }

    QString line = QString("[%1] %2 %3\n")
        .arg(QDateTime::currentDateTime().toString("HH:mm:ss.zzz"))
        .arg(level)
        .arg(msg);

    QMutexLocker locker(&g_logMutex);
    if (g_logStream) {
        *g_logStream << line;
        g_logStream->flush();
    }
}

static void setupLogging() {
    QString logDir = QStandardPaths::writableLocation(
        QStandardPaths::AppLocalDataLocation);
    QDir().mkpath(logDir);

    QString logPath = logDir + "/player.log";

    g_logFile = new QFile(logPath);
    if (g_logFile->open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        g_logStream = new QTextStream(g_logFile);
        g_logStream->setEncoding(QStringConverter::Utf8);
        qInstallMessageHandler(messageHandler);
        qDebug() << "[Log] logging to:" << logPath;
    }
}

static QString runHidden(const QString &program,
                         const QStringList &args,
                         int timeoutMs = 3000)
{
    QProcess proc;
    proc.setProgram(program);
    proc.setArguments(args);
    proc.setProcessChannelMode(QProcess::MergedChannels);

#ifdef Q_OS_WIN
    proc.setCreateProcessArgumentsModifier(
        [](QProcess::CreateProcessArguments *args) {
            args->flags |= CREATE_NO_WINDOW;
            args->startupInfo->dwFlags |= STARTF_USESHOWWINDOW;
            args->startupInfo->wShowWindow = SW_HIDE;
        });
#endif

    proc.start();
    if (!proc.waitForStarted(1000)) return QString();
    if (!proc.waitForFinished(timeoutMs)) {
        proc.kill();
        proc.waitForFinished(500);
        return QString();
    }
    return QString::fromLocal8Bit(proc.readAll());
}

class CachedNetworkAccessManagerFactory : public QQmlNetworkAccessManagerFactory {
public:
    explicit CachedNetworkAccessManagerFactory(NetworkManager *manager)
        : m_manager(manager) {}

    QNetworkAccessManager *create(QObject *parent) override {
        QNetworkAccessManager *nam = new QNetworkAccessManager(parent);

        auto *diskCache = new QNetworkDiskCache(nam);
        QString path = QStandardPaths::writableLocation(
            QStandardPaths::CacheLocation) + "/qml-image-cache";

        QDir().mkpath(path);
        diskCache->setCacheDirectory(path);
        diskCache->setMaximumCacheSize(QSettings("ArknightsMusicPlayer", "settings").value("cache/imageMb", 256).toInt() * 1024 * 1024);   // 256 MB

        nam->setCache(diskCache);
        if (m_manager) m_manager->setImageCache(diskCache);
        qDebug() << "[QML] image cache dir:" << path;
        return nam;
    }

private:
    NetworkManager *m_manager = nullptr;
};

// ============================================================
// ★ Windows Job Object
//   把 node.exe 加进 Job，父进程一消失，
//   系统会自动把这些子进程一起杀掉（即使 Mass 崩溃或强杀）。
// ============================================================
#ifdef Q_OS_WIN

static HANDLE g_jobHandle = nullptr;

static void setupJobObject() {
    if (g_jobHandle) return;

    g_jobHandle = CreateJobObjectW(nullptr, nullptr);
    if (!g_jobHandle) {
        qWarning() << "[Job] CreateJobObject failed:" << GetLastError();
        return;
    }

    JOBOBJECT_EXTENDED_LIMIT_INFORMATION jeli = {};
    jeli.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;

    if (!SetInformationJobObject(g_jobHandle,
                                 JobObjectExtendedLimitInformation,
                                 &jeli, sizeof(jeli))) {
        qWarning() << "[Job] SetInformationJobObject failed:" << GetLastError();
        CloseHandle(g_jobHandle);
        g_jobHandle = nullptr;
        return;
    }

    qDebug() << "[Job] job object created (KILL_ON_JOB_CLOSE)";
}

static void assignProcessToJob(QProcess *proc) {
    if (!g_jobHandle || !proc) return;
    if (proc->state() != QProcess::Running) return;

    qint64 pid = proc->processId();
    if (pid <= 0) return;

    HANDLE hProc = OpenProcess(PROCESS_SET_QUOTA | PROCESS_TERMINATE,
                                FALSE, (DWORD)pid);
    if (!hProc) {
        qWarning() << "[Job] OpenProcess failed for pid" << pid
                   << ":" << GetLastError();
        return;
    }

    // 检查是否已在某个 job 中（有些 shell 会给子进程分 job，不能重复分）
    BOOL bInJob = FALSE;
    if (IsProcessInJob(hProc, nullptr, &bInJob) && bInJob) {
        qDebug() << "[Job] pid" << pid << "already in a job, skipping";
        CloseHandle(hProc);
        return;
    }

    if (!AssignProcessToJobObject(g_jobHandle, hProc)) {
        qWarning() << "[Job] AssignProcessToJobObject failed for pid" << pid
                   << ":" << GetLastError();
    } else {
        qDebug() << "[Job] pid" << pid << "assigned to job";
    }

    CloseHandle(hProc);
}

static void closeJobObject() {
    if (g_jobHandle) {
        qDebug() << "[Job] closing job object (will kill children)";
        CloseHandle(g_jobHandle);
        g_jobHandle = nullptr;
    }
}

#endif // Q_OS_WIN

// ============================================================
// 窗口亚克力
// ============================================================
#ifdef Q_OS_WIN

enum AccentState {
    AccentDisabled = 0,
    AccentEnableAcrylicBlurBehind = 4
};

struct AccentPolicy {
    AccentState AccentState;
    DWORD       AccentFlags;
    DWORD       GradientColor;   // 0xAABBGGRR
    DWORD       AnimationId;
};

struct WindowCompositionAttributeData {
    DWORD  Attrib;               // WCA_ACCENT_POLICY
    PVOID  pvData;
    SIZE_T cbData;
};

#define WCA_ACCENT_POLICY 19

typedef BOOL (WINAPI *SetWindowCompositionAttributeFn)(
    HWND, WindowCompositionAttributeData *);

// DWM 系统圆角（Win11）
#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif
#ifndef DWMWCP_ROUND
#define DWMWCP_ROUND 2
#endif

typedef HRESULT (WINAPI *DwmSetWindowAttributeFn)(HWND, DWORD, LPCVOID, DWORD);

static void applySystemRoundedCorners(HWND hwnd) {
    HMODULE dwm = GetModuleHandleW(L"dwmapi.dll");
    if (!dwm) dwm = LoadLibraryW(L"dwmapi.dll");
    if (!dwm) return;

    auto setAttr = reinterpret_cast<DwmSetWindowAttributeFn>(
        GetProcAddress(dwm, "DwmSetWindowAttribute"));
    if (!setAttr) return;

    int pref = DWMWCP_ROUND;
    setAttr(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &pref, sizeof(pref));
}

// enabled=false 用于窗口淡出时立即撤掉模糊
static void applyAcrylic(QWindow *window, bool dark, bool enabled) {
    if (!window) return;

    HWND hwnd = reinterpret_cast<HWND>(window->winId());
    if (!hwnd) return;

    HMODULE user32 = GetModuleHandleW(L"user32.dll");
    if (!user32) user32 = LoadLibraryW(L"user32.dll");
    if (!user32) return;

    auto setAttr = reinterpret_cast<SetWindowCompositionAttributeFn>(
        GetProcAddress(user32, "SetWindowCompositionAttribute"));
    if (!setAttr) {
        qWarning() << "[Acrylic] SetWindowCompositionAttribute unavailable";
        return;
    }

    AccentPolicy accent = {};
    accent.AccentState   = enabled ? AccentEnableAcrylicBlurBehind
                                   : AccentDisabled;
    accent.AccentFlags   = 0;
    accent.GradientColor = dark ? 0x99221C1A : 0x99F4ECE8;
    accent.AnimationId   = 0;

    WindowCompositionAttributeData data = {};
    data.Attrib = WCA_ACCENT_POLICY;
    data.pvData = &accent;
    data.cbData = sizeof(accent);

    if (!setAttr(hwnd, &data)) {
        qWarning() << "[Acrylic] SetWindowCompositionAttribute failed:"
                   << GetLastError();
        return;
    }

    if (enabled) applySystemRoundedCorners(hwnd);
    qDebug() << "[Acrylic]" << (enabled ? "on" : "off");
}

#endif // Q_OS_WIN

static QProcess *g_apiServer = nullptr;

static bool isPortInUse(quint16 port) {
    QTcpSocket sock;
    sock.connectToHost("127.0.0.1", port);
    bool ok = sock.waitForConnected(300);
    if (ok) sock.disconnectFromHost();
    return ok;
}

static int killProcessOnPort(quint16 port) {
    QString output = runHidden("netstat", {"-ano", "-p", "TCP"}, 5000);
    if (output.isEmpty()) return 0;

    QString portStr = QString(":%1").arg(port);
    QSet<qint64> pids;

    for (const QString &line : output.split('\n')) {
        if (!line.contains(portStr)) continue;
        if (!line.contains("LISTENING")) continue;

        QStringList parts = line.split(QRegularExpression("\\s+"),
                                        Qt::SkipEmptyParts);
        if (parts.size() < 5) continue;

        bool ok = false;
        qint64 pid = parts.last().toLongLong(&ok);
        if (ok && pid > 0) pids.insert(pid);
    }

    if (pids.isEmpty()) return 0;

    for (qint64 pid : pids)
        runHidden("taskkill", {"/F", "/T", "/PID", QString::number(pid)}, 3000);

    return pids.size();
}

static void forceReleasePort(quint16 port) {
    if (!isPortInUse(port)) return;
    killProcessOnPort(port);
    for (int i = 0; i < 10; i++) {
        QThread::msleep(100);
        if (!isPortInUse(port)) return;
    }
}

// ============================================================
// API 服务
// ============================================================
static bool startApiServer() {
    forceReleasePort(3000);

    QString appDir = QCoreApplication::applicationDirPath();
    QString nodePath   = appDir + "/server/node.exe";
    QString scriptPath = appDir + "/server/dist/server.js";
    QString workDir    = appDir + "/server";

    QString program;
    QStringList args;

    if (QFile::exists(nodePath) && QFile::exists(scriptPath)) {
        program = nodePath;
        args << scriptPath;
        qDebug() << "[Boot] using portable Node:" << nodePath;
    } else {
        QString serverExe = appDir + "/server.exe";
        if (QFile::exists(serverExe)) {
            program = serverExe;
            workDir = appDir;
            qDebug() << "[Boot] using bundled server.exe:" << serverExe;
        } else {
            qWarning() << "[Boot] no API server found";
            return false;
        }
    }

    g_apiServer = new QProcess();
    g_apiServer->setProgram(program);
    g_apiServer->setArguments(args);
    g_apiServer->setWorkingDirectory(workDir);
    g_apiServer->setProcessChannelMode(QProcess::MergedChannels);

#ifdef Q_OS_WIN
    g_apiServer->setCreateProcessArgumentsModifier(
        [](QProcess::CreateProcessArguments *args) {
            args->flags |= CREATE_NO_WINDOW;
            args->startupInfo->dwFlags |= STARTF_USESHOWWINDOW;
            args->startupInfo->wShowWindow = SW_HIDE;
        });
#endif

    QObject::connect(g_apiServer, &QProcess::readyReadStandardOutput,
                     []() {
        QByteArray out = g_apiServer->readAllStandardOutput();
        if (!out.isEmpty()) {
            for (const QString &line : QString::fromUtf8(out).trimmed()
                                          .split('\n', Qt::SkipEmptyParts))
                qDebug() << "[server]" << line;
        }
    });

    QObject::connect(g_apiServer,
                     QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                     [](int code, QProcess::ExitStatus status) {
        qWarning() << "[server] exited with code:" << code
                   << "status:" << status;
    });

    QObject::connect(g_apiServer, &QProcess::errorOccurred,
                     [](QProcess::ProcessError err) {
        qWarning() << "[server] process error:" << err;
    });

    g_apiServer->start();

    if (!g_apiServer->waitForStarted(5000)) {
        qWarning() << "[Boot] API server failed to start!";
        delete g_apiServer;
        g_apiServer = nullptr;
        return false;
    }

#ifdef Q_OS_WIN
    // ★ 加入 Job，父进程死了它就被系统杀
    assignProcessToJob(g_apiServer);
#endif

    QNetworkAccessManager nam;
    for (int i = 0; i < 10; i++) {
        QThread::msleep(500);

        QNetworkRequest req{QUrl("http://localhost:3000/albums")};
        req.setTransferTimeout(1500);

        auto *reply = nam.get(req);
        QEventLoop loop;
        QObject::connect(reply, &QNetworkReply::finished,
                         &loop, &QEventLoop::quit);
        loop.exec();

        bool ok = (reply->error() == QNetworkReply::NoError);
        reply->deleteLater();

        if (ok) {
            qDebug() << "[Boot] API server is ready";
            return true;
        }
    }

    qWarning() << "[Boot] API server started but not responding after 5s";
    return true;
}

static void shutdownApiServer() {
    if (!g_apiServer) return;
    qDebug() << "[Shutdown] stopping API server...";

    // 无窗口子进程 terminate() 无效，直接 kill（残留由 Job 兜底）
    if (g_apiServer->state() != QProcess::NotRunning) {
        g_apiServer->kill();
        g_apiServer->waitForFinished(500);
    }

    delete g_apiServer;
    g_apiServer = nullptr;
}

// ============================================================
// 单实例
// ============================================================
static bool tryActivateExistingInstance() {
    QLocalSocket socket;
    socket.connectToServer(kSingleInstanceKey);
    if (!socket.waitForConnected(500)) return false;

    qDebug() << "[SingleInstance] another instance detected, activating it";
    socket.write("activate");
    socket.flush();
    socket.waitForBytesWritten(500);
    socket.disconnectFromServer();
    return true;
}

// ============================================================
// main
// ============================================================
int main(int argc, char *argv[]) {
    qputenv("QT_MEDIA_BACKEND", "ffmpeg");
    QQuickStyle::setStyle("Basic");

    QApplication app(argc, argv);
    app.setApplicationName("Mass");

    setupLogging();

#ifdef Q_OS_WIN
    // ★ 最先建 Job，后面所有子进程都塞进去
    setupJobObject();
#endif

    int restartDelay = 0;
    {
        const QStringList args = app.arguments();
        for (const QString &arg : args) {
            if (arg.startsWith("--restart-delay=")) {
                restartDelay = arg.mid(QString("--restart-delay=").length()).toInt();
            }
        }
    }
    if (restartDelay > 0) {
        qDebug() << "[Boot] restart delay:" << restartDelay << "ms";
        QEventLoop loop;
        QTimer::singleShot(restartDelay, &loop, &QEventLoop::quit);
        loop.exec();
    }

    if (tryActivateExistingInstance()) {
        qDebug() << "[SingleInstance] existing instance activated, exiting";
        return 0;
    }

    QString lockPath = QDir::tempPath() + "/Mass.lock";
    QLockFile lockFile(lockPath);
    lockFile.setStaleLockTime(30000);
    if (!lockFile.tryLock(500)) {
        qWarning() << "[SingleInstance] lock file held by another process, exiting";
        return 0;
    }

    QLocalServer::removeServer(kSingleInstanceKey);
    QLocalServer *localServer = new QLocalServer();
    if (!localServer->listen(kSingleInstanceKey)) {
        qWarning() << "[SingleInstance] failed to listen:"
                   << localServer->errorString();
    }

    QIcon appIcon(":/resources/app.ico");
    if (!appIcon.isNull()) app.setWindowIcon(appIcon);

    app.setQuitOnLastWindowClosed(false);

    qDebug() << "[Boot] QT_MEDIA_BACKEND =" << qgetenv("QT_MEDIA_BACKEND");

    startApiServer();

    // atexit 兜底（正常退出时触发；崩溃时靠 Job Object）
    std::atexit([]() {
        if (isPortInUse(3000))  killProcessOnPort(3000);
    });

    NetworkManager networkManager;
    AudioEngine audioEngine;
    AudioCache audioCache(networkManager.manager());
    AudioMetadataProbe audioMetadataProbe(networkManager.manager());
    CoverCache coverCache(&networkManager);
    TranslationService translationService(networkManager.manager());
    Settings settings;
    HistoryManager historyManager;
    PlaylistManager playlistManager;
    SystemTrayManager systemTray;

    systemTray.setAudioEngine(&audioEngine);
    systemTray.setSettings(&settings);

    // ★ 正常退出：先停子服务，再关 Job
    QObject::connect(&app, &QCoreApplication::aboutToQuit,
        [&translationService]() {
        translationService.flushCache();
        shutdownApiServer();
#ifdef Q_OS_WIN
        closeJobObject();
#endif
    });

    QQmlApplicationEngine engine;
    engine.setNetworkAccessManagerFactory(
        new CachedNetworkAccessManagerFactory(&networkManager));

    engine.rootContext()->setContextProperty("networkManager", &networkManager);
    engine.rootContext()->setContextProperty("audioEngine", &audioEngine);
    engine.rootContext()->setContextProperty("audioCache", &audioCache);
    engine.rootContext()->setContextProperty("audioMetadataProbe", &audioMetadataProbe);
    engine.rootContext()->setContextProperty("coverCache", &coverCache);
    engine.rootContext()->setContextProperty("translationService", &translationService);
    engine.rootContext()->setContextProperty("appSettings", &settings);
    engine.rootContext()->setContextProperty("historyManager", &historyManager);
    engine.rootContext()->setContextProperty("playlistManager", &playlistManager);
    engine.rootContext()->setContextProperty("systemTray", &systemTray);

    engine.loadFromModule("ArknightsMusicPlayer", "Main");

    if (engine.rootObjects().isEmpty()) {
        shutdownApiServer();
#ifdef Q_OS_WIN
        closeJobObject();
#endif
        return -1;
    }

    // 提前建好 QML 的 NAM，封面预取才会写进图片缓存
    networkManager.setQmlManager(engine.networkAccessManager());

    QWindow *mainWindow = qobject_cast<QWindow*>(engine.rootObjects().first());
    if (mainWindow) systemTray.setWindow(mainWindow);

#ifdef Q_OS_WIN
    // 主题切换重新上色；淡出时先关掉模糊
    {
        // 只在"窗口在屏 + 内容不透明"时开亚克力：窗口隐藏后若再开启，
        // DWM 会在桌面上留下一块点不动的毛玻璃残影
        auto syncAcrylic = [mainWindow, &settings]() {
            if (!mainWindow) return;
            const bool onScreen = mainWindow->isVisible()
                && mainWindow->visibility() != QWindow::Minimized;
            const bool opaque =
                mainWindow->property("windowOpacity").toReal() > 0.99;
            applyAcrylic(mainWindow, settings.darkMode(), onScreen && opaque);
        };

        bool lastDark = settings.darkMode();
        syncAcrylic();

        QObject::connect(&settings, &Settings::changed, mainWindow,
            [mainWindow, &settings, lastDark, syncAcrylic]() mutable {
                const bool dark = settings.darkMode();
                if (dark == lastDark) return;
                lastDark = dark;
                syncAcrylic();
            });

        if (mainWindow) {
            QObject::connect(mainWindow, SIGNAL(windowOpacityChanged()),
                             &systemTray, SLOT(onWindowOpacityChanged()));
            QObject::connect(&systemTray, &SystemTrayManager::windowFadeChanged,
                             mainWindow, syncAcrylic);
            QObject::connect(mainWindow, &QWindow::visibilityChanged,
                             mainWindow, syncAcrylic);
            // 退出前先撤掉模糊
            QObject::connect(&app, &QCoreApplication::aboutToQuit,
                             mainWindow, [mainWindow]() {
                applyAcrylic(mainWindow, true, false);
            });
        }
    }
#endif

    QObject::connect(&app, &QCoreApplication::aboutToQuit, [&engine]() {
        const auto roots = engine.rootObjects();
        for (QObject *root : roots) {
            const auto children = root->findChildren<QWindow*>();
            for (QWindow *w : children) {
                if (w && w->isVisible()) {
                    w->close();
                }
            }
        }
    });

    QObject::connect(localServer, &QLocalServer::newConnection,
        [localServer, mainWindow]() {
        QLocalSocket *client = localServer->nextPendingConnection();
        if (!client) return;
        client->waitForReadyRead(200);
        client->readAll();
        if (mainWindow) {
            if (!mainWindow->isVisible()) mainWindow->show();
            if (mainWindow->visibility() == QWindow::Minimized)
                mainWindow->showNormal();
            mainWindow->raise();
            mainWindow->requestActivate();
        }
        client->disconnectFromServer();
        client->deleteLater();
    });

    int ret = app.exec();

    // 双重保险
    translationService.flushCache();
    shutdownApiServer();
#ifdef Q_OS_WIN
    closeJobObject();
#endif

    return ret;
}