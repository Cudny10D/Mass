#include "CoverCache.h"
#include "NetworkManager.h"
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QNetworkDiskCache>
#include <QDebug>

static const char *kUserAgent =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36";

CoverCache::CoverCache(NetworkManager *network, QObject *parent)
    : QObject(parent), m_network(network) {}

// ============================================================
// 批量预取
// ============================================================
void CoverCache::prefetchAll(const QStringList &urls) {
    m_total = urls.size();
    m_done = 0;

    qDebug() << "[CoverCache] prefetch" << m_total
             << "covers, concurrency =" << MAX_CONCURRENT;

    for (const QString &url : urls) {
        if (url.isEmpty()) continue;
        enqueue(url);
    }

    processQueue();
}

// ============================================================
// 入队（去重）
// ============================================================
void CoverCache::enqueue(const QString &url) {
    if (m_pending.contains(url)) return;
    m_pending.insert(url);
    m_queue.enqueue(url);
}

// ============================================================
// 调度：最多 MAX_CONCURRENT 个并发
// ============================================================
void CoverCache::processQueue() {
    while (m_active < MAX_CONCURRENT && !m_queue.isEmpty()) {
        m_active++;
        startDownload(m_queue.dequeue());
    }
}

// ============================================================
// 实际下载
// ============================================================
void CoverCache::startDownload(const QString &url) {
    // 走 QML 的 NAM，写进图片缓存（Image 读的也是它）
    QNetworkAccessManager *nam = m_network ? m_network->coverManager() : nullptr;
    if (!nam) {
        finishOne(url);   // 避免卡住并发槽
        return;
    }

    QNetworkRequest req{QUrl(url)};
    req.setHeader(QNetworkRequest::UserAgentHeader, kUserAgent);
    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    req.setAttribute(QNetworkRequest::CacheLoadControlAttribute,
                     QNetworkRequest::PreferCache);
    req.setAttribute(QNetworkRequest::CacheSaveControlAttribute, true);

    auto *reply = nam->get(req);

    connect(reply, &QNetworkReply::finished, this,
            [this, reply, url]() {
        reply->deleteLater();
        finishOne(url);
    });
}

// ============================================================
// 单个完成 → 释放并发槽 → 调度下一个
// ============================================================
void CoverCache::finishOne(const QString &url) {
    m_pending.remove(url);
    m_done++;
    if (m_active > 0) m_active--;

    emit progressChanged(m_done, m_total);

    if (m_done % 20 == 0 || m_done == m_total) {
        qDebug() << "[CoverCache] progress:" << m_done << "/" << m_total
                 << "(active:" << m_active
                 << "queue:" << m_queue.size() << ")";
    }

    processQueue();
}