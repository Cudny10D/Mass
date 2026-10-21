#pragma once
#include <QObject>
#include <QString>
#include <QSet>
#include <QQueue>

class NetworkManager;

class CoverCache : public QObject {
    Q_OBJECT
public:
    explicit CoverCache(NetworkManager *network,
                        QObject *parent = nullptr);

    Q_INVOKABLE void prefetchAll(const QStringList &urls);

signals:
    void progressChanged(int done, int total);

private:
    NetworkManager *m_network = nullptr;

    QSet<QString> m_pending;        // 已入队/下载中的 URL（去重）
    QQueue<QString> m_queue;        // 等待下载
    int m_active = 0;               // 当前并发数
    int m_total = 0;
    int m_done = 0;

    static constexpr int MAX_CONCURRENT = 6;   // ★ 并发上限

    void enqueue(const QString &url);
    void processQueue();
    void startDownload(const QString &url);
    void finishOne(const QString &url);
};