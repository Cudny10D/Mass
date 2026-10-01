#include "TranslationService.h"
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QUrlQuery>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDebug>

// ============================================================
// 语言检测辅助函数
// ============================================================

// 是否含日文假名（平假名 U+3040-309F / 片假名 U+30A0-30FF）
static bool hasJapanese(const QString &text) {
    for (const QChar &c : text) {
        ushort u = c.unicode();
        if ((u >= 0x3040 && u <= 0x309F) ||
            (u >= 0x30A0 && u <= 0x30FF)) {
            return true;
        }
    }
    return false;
}

// 是否基本是中文（汉字占比 > 50%，且没有日文假名）
static bool isChinese(const QString &text) {
    int letters = 0;
    int cjk = 0;
    for (const QChar &c : text) {
        if (c.isLetter()) {
            letters++;
            ushort u = c.unicode();
            // CJK 统一表意文字
            if ((u >= 0x4E00 && u <= 0x9FFF) ||
                (u >= 0x3400 && u <= 0x4DBF)) {
                cjk++;
            }
        }
    }
    if (letters == 0) return false;
    return (double)cjk / letters > 0.5;
}

// 根据文本内容返回 MyMemory 的 langpair
//   日文 → "ja|zh-CN"
//   其它 → "en|zh-CN"
static QString detectLangPair(const QString &text) {
    if (hasJapanese(text)) return "ja|zh-CN";
    return "en|zh-CN";
}

// ============================================================
// 构造
// ============================================================
TranslationService::TranslationService(QNetworkAccessManager *sharedManager,
                                        QObject *parent)
    : QObject(parent), m_manager(sharedManager) {}

// ============================================================
// 翻译单行
// ============================================================
void TranslationService::translate(const QString &cid,
                                    const QString &text,
                                    const QString &targetLang) {
    Q_UNUSED(targetLang)
    if (text.trimmed().isEmpty()) return;

    BatchState *st = new BatchState;
    st->cid = cid;
    st->source << text;
    st->result << QString();
    st->pending = 1;
    m_batches.insert(cid, st);

    doTranslate(cid, 0, text, "", st);
}

// ============================================================
// 翻译整首歌词
// ============================================================
void TranslationService::translateLyrics(const QString &cid,
                                          const QStringList &lines,
                                          const QString &targetLang) {
    Q_UNUSED(targetLang)
    if (lines.isEmpty()) return;

    // 缓存命中
    if (m_cache.contains(cid)) {
        emit lyricsTranslated(cid, m_cache[cid]);
        return;
    }

    // 已有进行中的任务
    if (m_batches.contains(cid)) {
        return;
    }

    BatchState *st = new BatchState;
    st->cid = cid;
    st->source = lines;
    st->result = QStringList();
    for (int i = 0; i < lines.size(); i++) st->result << QString();
    st->pending = lines.size();
    m_batches.insert(cid, st);

    qDebug() << "[Translate] MyMemory batch start,"
             << lines.size() << "lines for cid" << cid;

    for (int i = 0; i < lines.size(); i++) {
        doTranslate(cid, i, lines[i], "", st);
    }
}

// ============================================================
// 执行单行翻译
// ============================================================
void TranslationService::doTranslate(const QString &cid, int index,
                                      const QString &text,
                                      const QString &targetLang,
                                      BatchState *batch) {
    Q_UNUSED(targetLang)

    // 空行直接跳过
    if (text.trimmed().isEmpty()) {
        batch->pending--;
        if (batch->pending == 0) {
            m_cache.insert(cid, batch->result);
            emit lyricsTranslated(cid, batch->result);
            m_batches.remove(cid);
            delete batch;
        }
        return;
    }

    // 已经是中文 → 直接返回原文，不消耗配额
    if (isChinese(text) && !hasJapanese(text)) {
        batch->result[index] = text;
        emit lineTranslated(cid, index, text);

        batch->pending--;
        if (batch->pending == 0) {
            m_cache.insert(cid, batch->result);
            emit lyricsTranslated(cid, batch->result);
            m_batches.remove(cid);
            delete batch;
        }
        return;
    }

    // 太长的行跳过（MyMemory 单次上限 500 字符）
    if (text.length() > 500) {
        qWarning() << "[Translate] line too long, skipped:" << text.length();
        batch->result[index] = "";
        batch->pending--;
        if (batch->pending == 0) {
            m_cache.insert(cid, batch->result);
            emit lyricsTranslated(cid, batch->result);
            m_batches.remove(cid);
            delete batch;
        }
        return;
    }

    // 自动检测语言
    QString langpair = detectLangPair(text);

    // 构造 MyMemory 请求
    QUrl url("https://api.mymemory.translated.net/get");
    QUrlQuery q;
    q.addQueryItem("q", text);
    q.addQueryItem("langpair", langpair);
    url.setQuery(q);

    QNetworkRequest req{url};
    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    req.setHeader(QNetworkRequest::UserAgentHeader,
                  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                  "AppleWebKit/537.36 (KHTML, like Gecko) "
                  "Chrome/120.0.0.0 Safari/537.36");

    auto *reply = m_manager->get(req);
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, cid, index, batch]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "[Translate] network error:"
                       << reply->errorString();
            batch->result[index] = "";
        } else {
            QByteArray data = reply->readAll();
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(data, &err);

            if (err.error != QJsonParseError::NoError) {
                qWarning() << "[Translate] JSON parse error:"
                           << err.errorString();
                batch->result[index] = "";
            } else {
                QJsonObject obj = doc.object();
                int status = obj["responseStatus"].toInt();

                // MyMemory 用 HTTP 200 + responseStatus 区分结果
                if (status != 200) {
                    QString detail = obj["responseDetails"].toString();
                    qWarning() << "[Translate] MyMemory status:" << status
                               << detail;
                    batch->result[index] = "";
                } else {
                    QJsonObject rsp = obj["responseData"].toObject();
                    QString translated = rsp["translatedText"].toString();

                    // MyMemory 有时会把错误信息塞进 translatedText
                    if (translated.contains("MYMEMORY WARNING") ||
                        translated.contains("QUERY LENGTH LIMIT") ||
                        translated.contains("INVALID")) {
                        qWarning() << "[Translate] MyMemory warning:"
                                   << translated;
                        translated = "";
                    }

                    batch->result[index] = translated;
                }
            }
        }

        emit lineTranslated(cid, index, batch->result[index]);

        batch->pending--;
        if (batch->pending == 0) {
            m_cache.insert(cid, batch->result);
            emit lyricsTranslated(cid, batch->result);
            m_batches.remove(cid);
            delete batch;
            qDebug() << "[Translate] MyMemory batch done for cid" << cid;
        }
    });
}

// ============================================================
// 清空缓存
// ============================================================
void TranslationService::clearCache() {
    m_cache.clear();
    qDebug() << "[Translate] cache cleared";
}