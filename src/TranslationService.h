#pragma once
#include <QObject>
#include <QString>
#include <QStringList>
#include <QNetworkAccessManager>
#include <QHash>

class TranslationService : public QObject {
    Q_OBJECT
public:
    explicit TranslationService(QNetworkAccessManager *sharedManager,
                                QObject *parent = nullptr);

    // 翻译单行文本（异步）
    Q_INVOKABLE void translate(const QString &cid,
                               const QString &text,
                               const QString &targetLang = "zh-CN");

    // 批量翻译整首歌词（每行独立请求）
    Q_INVOKABLE void translateLyrics(const QString &cid,
                                     const QStringList &lines,
                                     const QString &targetLang = "zh-CN");

    Q_INVOKABLE void clearCache();

signals:
    // 单行翻译完成
    void lineTranslated(const QString &cid, int index, const QString &translated);

    // 整首翻译完成（cid, translatedLines）
    void lyricsTranslated(const QString &cid, const QStringList &translated);

    void translateFailed(const QString &cid, const QString &error);

private:
    QNetworkAccessManager *m_manager;

    // 缓存：cid → 已翻译的行列表
    QHash<QString, QStringList> m_cache;

    // 追踪批量任务
    struct BatchState {
        QString cid;
        QStringList source;
        QStringList result;
        int pending = 0;
    };
    QHash<QString, BatchState*> m_batches;

    void doTranslate(const QString &cid, int index, const QString &text,
                     const QString &targetLang, BatchState *batch);
};