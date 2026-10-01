#pragma once
#include <QObject>
#include <QString>
#include <QSet>
#include <QQueue>
#include <QNetworkAccessManager>

class CoverCache : public QObject {
    Q_OBJECT
public:
    explicit CoverCache(QNetworkAccessManager *sharedManager,
                        QObject *parent = nullptr);

    Q_INVOKABLE void prefetchAll(const QStringList &urls);
    Q_INVOKABLE void prefetch(const QString &url);
    Q_INVOKABLE int activeCount() const { return m_active; }
    Q_INVOKABLE int pendingCount() const { return m_queue.size(); }

signals:
    void progressChanged(int done, int total);

private:
    struct PendingItem {
        QString url;
    };

    QNetworkAccessManager *m_manager = nullptr;

    QSet<QString> m_pending;        // 已入队/下载中的 URL（去重）
    QQueue<PendingItem> m_queue;    // 等待下载
    int m_active = 0;               // 当前并发数
    int m_total = 0;
    int m_done = 0;

    static constexpr int MAX_CONCURRENT = 6;   // ★ 并发上限

    void enqueue(const QString &url);
    void processQueue();
    void startDownload(const QString &url);
    void finishOne(const QString &url);
};