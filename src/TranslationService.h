#pragma once
#include <QObject>
#include <QString>
#include <QStringList>
#include <QNetworkAccessManager>
#include <QHash>
#include <QList>
#include <QTimer>

class QNetworkReply;

class TranslationService : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool useDeepL READ useDeepL WRITE setUseDeepL NOTIFY backendChanged)
    Q_PROPERTY(bool quotaExhausted READ quotaExhausted NOTIFY backendChanged)
    Q_PROPERTY(int cacheCount READ cacheCount NOTIFY cacheCountChanged)
    Q_PROPERTY(bool useLyricsPack READ useLyricsPack WRITE setUseLyricsPack NOTIFY useLyricsPackChanged)

public:
    explicit TranslationService(QNetworkAccessManager *sharedManager,
                                QObject *parent = nullptr);

    Q_INVOKABLE void translate(const QString &cid,
                               const QString &text,
                               const QString &targetLang = "zh-CN");

    Q_INVOKABLE void translateLyrics(const QString &cid,
                                     const QStringList &lines,
                                     const QString &targetLang = "zh-CN");

    Q_INVOKABLE void clearCache();

    // ------------------------------------------------------------
    // 后端
    // ------------------------------------------------------------
    bool useDeepL() const { return m_backend == Backend::DeepL; }
    Q_INVOKABLE void setUseDeepL(bool v);

    Q_INVOKABLE QString activeBackendName() const;

    // ------------------------------------------------------------
    // DeepL
    // ------------------------------------------------------------
    Q_INVOKABLE void setApiKey(const QString &key);
    Q_INVOKABLE bool hasApiKey() const { return !m_apiKey.isEmpty(); }

    // ------------------------------------------------------------
    // 配额
    // ------------------------------------------------------------
    bool quotaExhausted() const { return m_quotaExhausted; }
    Q_INVOKABLE void resetQuotaFlag();

    // ------------------------------------------------------------
    // 歌词缓存包
    // ------------------------------------------------------------
    int cacheCount() const { return m_cache.size(); }

    Q_INVOKABLE bool exportCache(const QString &filePath);
    Q_INVOKABLE int  importCache(const QString &filePath);
    Q_INVOKABLE QString cacheFilePath() const;

    // 删除已导入的歌词包（清空内存缓存 + 删除磁盘文件）
    Q_INVOKABLE void clearLyricsPack();

    // 使用已导入歌词包的开关（关闭后忽略本地歌词包，走在线翻译）
    bool useLyricsPack() const { return m_useLyricsPack; }
    Q_INVOKABLE void setUseLyricsPack(bool v);

    // 供 QML 查询缓存状态 / 源文本，用于按文本对齐翻译
    // 内部会判断 useLyricsPack 开关
    Q_INVOKABLE bool hasCached(const QString &cid) const {
        if (!m_useLyricsPack) return false;
        return m_cache.contains(cid);
    }
    Q_INVOKABLE QStringList getCachedSource(const QString &cid) const {
        return m_sourceCache.value(cid);
    }

    // 退出时立即落盘
    Q_INVOKABLE void flushCache();

signals:
    void lineTranslated(const QString &cid, int index, const QString &translated);
    void lyricsTranslated(const QString &cid, const QStringList &translated);
    void translateFailed(const QString &cid, const QString &error);
    void backendChanged();
    void cacheCountChanged();
    void useLyricsPackChanged();

private:
    enum class Backend { MyMemory, DeepL };

    struct BatchState {
        QString     cid;
        QStringList source;
        QStringList result;
        QList<int>  validIndices;
        int         pending = 0;
    };

    struct Prepared {
        QStringList texts;
        QList<int>  indices;
    };

    QNetworkAccessManager *m_manager = nullptr;

    QHash<QString, QStringList> m_cache;
    QHash<QString, QStringList> m_sourceCache;
    QHash<QString, BatchState*> m_batches;

    Backend m_backend = Backend::MyMemory;

    QString m_apiKey;
    bool    m_quotaExhausted = false;
    bool    m_useLyricsPack = true;

    QTimer  m_saveTimer;

    void loadSettings();
    void saveBackend();

    void loadPersistentCache();
    void scheduleSave();
    void savePersistentCacheNow();

    Prepared prepareBatch(BatchState *batch, int maxLineLength);
    void startTranslate(BatchState *batch, const QString &targetLang);
    void finishBatch(BatchState *batch);
    bool isBatchValid(BatchState *batch) const;

    void doTranslateDeepL(BatchState *batch, const QString &targetLang);
    void doTranslateMyMemory(BatchState *batch);
    void doMyMemoryLine(BatchState *batch, int index, const QString &text);

    void handleDeepLReply(BatchState *batch, QNetworkReply *reply);
};