#include "TranslationService.h"
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QUrl>
#include <QUrlQuery>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonParseError>
#include <QSettings>
#include <QTimer>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QStandardPaths>
#include <QDateTime>
#include <QCoreApplication>
#include <QDebug>

// ============================================================
// 常量
// ============================================================
static const char *kUserAgent =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36";

static const char *kDeepLFreeEndpoint = "https://api-free.deepl.com/v2/translate";
static const char *kDeepLProEndpoint  = "https://api.deepl.com/v2/translate";

static constexpr int kMyMemoryStaggerMs = 120;
static constexpr int kSaveThrottleMs    = 3000;

// ============================================================
// 语言检测
// ============================================================
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

static bool isChinese(const QString &text) {
    int letters = 0;
    int cjk = 0;
    for (const QChar &c : text) {
        if (c.isLetter()) {
            letters++;
            ushort u = c.unicode();
            if ((u >= 0x4E00 && u <= 0x9FFF) ||
                (u >= 0x3400 && u <= 0x4DBF)) {
                cjk++;
            }
        }
    }
    if (letters == 0) return false;
    return (double)cjk / letters > 0.5;
}

static QString myMemoryLangPair(const QString &text) {
    return hasJapanese(text) ? "ja|zh-CN" : "en|zh-CN";
}

static QString normalizeDeepLTarget(const QString &lang) {
    QString l = lang.trimmed().toUpper();
    if (l.isEmpty()) return "ZH";
    if (l == "ZH-CN" || l == "ZH-HANS" || l == "ZH" || l == "CN") return "ZH";
    if (l == "ZH-TW" || l == "ZH-HANT" || l == "TW")            return "ZH-HANT";
    if (l == "EN" || l == "EN-US" || l == "EN-GB")              return "EN-US";
    if (l == "JA" || l == "JP")                                 return "JA";
    if (l == "KO" || l == "KR")                                 return "KO";
    return l;
}

// ============================================================
// 构造 + 配置
// ============================================================
TranslationService::TranslationService(QNetworkAccessManager *sharedManager,
                                        QObject *parent)
    : QObject(parent), m_manager(sharedManager)
{
    loadSettings();

    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(kSaveThrottleMs);
    connect(&m_saveTimer, &QTimer::timeout,
            this, &TranslationService::savePersistentCacheNow);

    loadPersistentCache();
}

void TranslationService::loadSettings() {
    QSettings s("ArknightsMusicPlayer", "settings");

    QByteArray env = qgetenv("DEEPL_API_KEY");
    QString envKey = QString::fromUtf8(env).trimmed();
    QString storedKey = s.value("translate/deeplApiKey").toString().trimmed();
    m_apiKey = !envKey.isEmpty() ? envKey : storedKey;

    QString backend = s.value("translate/backend", "mymemory").toString();
    if      (backend == "deepl")   m_backend = Backend::DeepL;
    else                           m_backend = Backend::MyMemory;

    m_useLyricsPack = s.value("translate/useLyricsPack", true).toBool();

    qDebug() << "[Translate] loadSettings:"
             << "backend=" << activeBackendName()
             << "hasDeepLKey=" << !m_apiKey.isEmpty()
             << "useLyricsPack=" << m_useLyricsPack;
}

void TranslationService::saveBackend() {
    QSettings s("ArknightsMusicPlayer", "settings");
    QString name;
    switch (m_backend) {
    case Backend::DeepL:  name = "deepl";  break;
    default:              name = "mymemory"; break;
    }
    s.setValue("translate/backend", name);
    s.sync();
}

QString TranslationService::activeBackendName() const {
    switch (m_backend) {
    case Backend::DeepL:
        if (m_apiKey.isEmpty())       return "MyMemory（DeepL 未配置 Key）";
        if (m_quotaExhausted)         return "MyMemory（DeepL 配额耗尽）";
        return "DeepL";
    default:
        return "MyMemory";
    }
}

// ============================================================
// 持久化
// ============================================================
QString TranslationService::cacheFilePath() const {
    QString dir = QStandardPaths::writableLocation(
        QStandardPaths::AppLocalDataLocation);
    QDir().mkpath(dir);
    return dir + "/translation-cache.json";
}

void TranslationService::loadPersistentCache() {
    QString path = cacheFilePath();
    QFile f(path);

    if (!f.exists()) {
        qDebug() << "[Translate] no persistent cache yet:" << path;
        return;
    }

    if (!f.open(QIODevice::ReadOnly)) {
        qWarning() << "[Translate] cannot open cache:" << path;
        return;
    }

    QByteArray data = f.readAll();
    f.close();

    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(data, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "[Translate] cache parse error:" << err.errorString();
        return;
    }

    QJsonObject root = doc.object();
    QJsonObject entries = root["entries"].toObject();

    int loaded = 0;
    for (auto it = entries.begin(); it != entries.end(); ++it) {
        const QString cid = it.key();
        QJsonObject e = it.value().toObject();

        QStringList translated;
        for (const auto &v : e["translated"].toArray())
            translated << v.toString();

        QStringList source;
        for (const auto &v : e["source"].toArray())
            source << v.toString();

        if (!translated.isEmpty()) {
            m_cache.insert(cid, translated);
            m_sourceCache.insert(cid, source);
            ++loaded;
        }
    }

    qDebug() << "[Translate] loaded" << loaded
             << "translated lyrics from cache";
    emit cacheCountChanged();
}

void TranslationService::scheduleSave() {
    m_saveTimer.start();
}

void TranslationService::savePersistentCacheNow() {
    QJsonObject entries;
    for (auto it = m_cache.begin(); it != m_cache.end(); ++it) {
        const QString cid = it.key();
        const QStringList &translated = it.value();

        QJsonArray ta;
        for (const QString &s : translated) ta.append(s);

        QJsonArray sa;
        const QStringList &source = m_sourceCache.value(cid);
        for (const QString &s : source) sa.append(s);

        QJsonObject e;
        e["source"]     = sa;
        e["translated"] = ta;
        entries[cid] = e;
    }

    QJsonObject root;
    root["version"]      = 1;
    root["generated_at"] = QDateTime::currentDateTime()
                              .toString(Qt::ISODate);
    root["backend"]      = activeBackendName();
    root["count"]        = m_cache.size();
    root["entries"]      = entries;

    QJsonDocument doc(root);
    QByteArray data = doc.toJson(QJsonDocument::Compact);

    QString path = cacheFilePath();
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "[Translate] cannot write cache:" << path;
        return;
    }
    f.write(data);
    f.close();

    qDebug() << "[Translate] cache saved:" << path
             << "(" << m_cache.size() << "entries,"
             << data.size() / 1024 << "KB)";
}

void TranslationService::flushCache() {
    if (m_saveTimer.isActive()) {
        m_saveTimer.stop();
    }
    savePersistentCacheNow();
}

// ============================================================
// 导出 / 导入
// ============================================================
bool TranslationService::exportCache(const QString &filePath) {
    if (filePath.isEmpty()) return false;

    QJsonObject entries;
    for (auto it = m_cache.begin(); it != m_cache.end(); ++it) {
        const QString cid = it.key();
        const QStringList &translated = it.value();

        QJsonArray ta;
        for (const QString &s : translated) ta.append(s);

        QJsonArray sa;
        const QStringList &source = m_sourceCache.value(cid);
        for (const QString &s : source) sa.append(s);

        QJsonObject e;
        e["source"]     = sa;
        e["translated"] = ta;
        entries[cid] = e;
    }

    QJsonObject root;
    root["version"]      = 1;
    root["generated_at"] = QDateTime::currentDateTime()
                              .toString(Qt::ISODate);
    root["backend"]      = activeBackendName();
    root["count"]        = m_cache.size();
    root["entries"]      = entries;

    QJsonDocument doc(root);
    QByteArray data = doc.toJson(QJsonDocument::Compact);

    QFile f(filePath);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "[Translate] export failed:" << filePath;
        return false;
    }
    f.write(data);
    f.close();

    qDebug() << "[Translate] exported" << m_cache.size()
             << "entries to" << filePath
             << "(" << data.size() / 1024 << "KB)";
    return true;
}

int TranslationService::importCache(const QString &filePath) {
    QFile f(filePath);
    if (!f.open(QIODevice::ReadOnly)) {
        qWarning() << "[Translate] import failed:" << filePath;
        return 0;
    }

    QByteArray data = f.readAll();
    f.close();

    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(data, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "[Translate] import parse error:" << err.errorString();
        return 0;
    }

    QJsonObject root = doc.object();
    QJsonObject entries = root["entries"].toObject();

    int imported = 0;
    for (auto it = entries.begin(); it != entries.end(); ++it) {
        const QString cid = it.key();

        if (m_cache.contains(cid)) continue;

        QJsonObject e = it.value().toObject();

        QStringList translated;
        for (const auto &v : e["translated"].toArray())
            translated << v.toString();

        QStringList source;
        for (const auto &v : e["source"].toArray())
            source << v.toString();

        if (!translated.isEmpty()) {
            m_cache.insert(cid, translated);
            m_sourceCache.insert(cid, source);
            ++imported;
        }
    }

    qDebug() << "[Translate] imported" << imported << "new entries";

    if (imported > 0) {
        emit cacheCountChanged();
        scheduleSave();
    }

    return imported;
}

// ============================================================
// 使用歌词包开关
// ============================================================
void TranslationService::setUseLyricsPack(bool v) {
    if (m_useLyricsPack == v) return;
    m_useLyricsPack = v;

    QSettings s("ArknightsMusicPlayer", "settings");
    s.setValue("translate/useLyricsPack", v);
    s.sync();

    emit useLyricsPackChanged();
    qDebug() << "[Translate] useLyricsPack =" << v;
}

// ============================================================
// 删除已导入的歌词包（清空内存 + 删文件）
// ============================================================
void TranslationService::clearLyricsPack() {
    m_cache.clear();
    m_sourceCache.clear();
    m_batches.clear();

    QString path = cacheFilePath();
    QFile::remove(path);

    emit cacheCountChanged();
    qDebug() << "[Translate] lyrics pack cleared";
}

// ============================================================
// 后端切换
// ============================================================
void TranslationService::setUseDeepL(bool v) {
    if (v && m_backend == Backend::DeepL) return;
    if (!v && m_backend != Backend::DeepL) return;
    m_backend = v ? Backend::DeepL : Backend::MyMemory;
    saveBackend();
    emit backendChanged();
}

void TranslationService::setApiKey(const QString &key) {
    m_apiKey = key.trimmed();
    QSettings s("ArknightsMusicPlayer", "settings");
    s.setValue("translate/deeplApiKey", m_apiKey);
    s.sync();
    emit backendChanged();
}

void TranslationService::resetQuotaFlag() {
    if (!m_quotaExhausted) return;
    m_quotaExhausted = false;
    emit backendChanged();
}

// ============================================================
// 翻译入口
// ============================================================
void TranslationService::translate(const QString &cid, const QString &text,
                                    const QString &targetLang) {
    if (cid.isEmpty() || text.trimmed().isEmpty()) return;
    if (m_batches.contains(cid)) return;

    auto *st = new BatchState;
    st->cid = cid;
    st->source << text;
    st->result << QString();
    m_batches.insert(cid, st);

    startTranslate(st, targetLang);
}

void TranslationService::translateLyrics(const QString &cid,
                                          const QStringList &lines,
                                          const QString &targetLang) {
    if (cid.isEmpty() || lines.isEmpty()) return;

    if (m_useLyricsPack && m_cache.contains(cid)) {
        emit lyricsTranslated(cid, m_cache[cid]);
        return;
    }
    if (m_batches.contains(cid)) return;

    auto *st = new BatchState;
    st->cid = cid;
    st->source = lines;
    st->result = QStringList();
    for (int i = 0; i < lines.size(); ++i) st->result << QString();
    m_batches.insert(cid, st);

    startTranslate(st, targetLang);
}

void TranslationService::startTranslate(BatchState *batch,
                                         const QString &targetLang) {
    if (!batch) return;

    switch (m_backend) {
    case Backend::DeepL:
        if (!m_apiKey.isEmpty() && !m_quotaExhausted)
            doTranslateDeepL(batch, targetLang);
        else
            doTranslateMyMemory(batch);
        break;
    default:
        doTranslateMyMemory(batch);
        break;
    }
}

TranslationService::Prepared
TranslationService::prepareBatch(BatchState *batch, int maxLineLength) {
    Prepared p;
    batch->validIndices.clear();

    for (int i = 0; i < batch->source.size(); ++i) {
        const QString &line = batch->source[i];

        if (line.trimmed().isEmpty()) {
            batch->result[i] = "";
            continue;
        }

        if (isChinese(line) && !hasJapanese(line)) {
            batch->result[i] = line;
            emit lineTranslated(batch->cid, i, line);
            continue;
        }

        if (line.length() > maxLineLength) {
            qWarning() << "[Translate] line too long, skipped:"
                       << line.length();
            batch->result[i] = "";
            continue;
        }

        p.texts << line;
        p.indices << i;
    }

    batch->validIndices = p.indices;
    return p;
}

bool TranslationService::isBatchValid(BatchState *batch) const {
    return batch
        && m_batches.contains(batch->cid)
        && m_batches.value(batch->cid) == batch;
}

// ============================================================
// MyMemory
// ============================================================
void TranslationService::doTranslateMyMemory(BatchState *batch) {
    if (!batch) return;

    Prepared p = prepareBatch(batch, 500);

    if (p.texts.isEmpty()) {
        qDebug() << "[Translate] MyMemory: no lines need translation";
        finishBatch(batch);
        return;
    }

    qDebug() << "[Translate] MyMemory:" << p.texts.size() << "lines";
    batch->pending = p.texts.size();

    for (int i = 0; i < p.texts.size(); ++i) {
        const int idx = p.indices[i];
        const QString text = p.texts[i];
        QTimer::singleShot(i * kMyMemoryStaggerMs, this,
            [this, batch, idx, text]() {
            if (!isBatchValid(batch)) return;
            doMyMemoryLine(batch, idx, text);
        });
    }
}

void TranslationService::doMyMemoryLine(BatchState *batch, int index,
                                         const QString &text) {
    QUrl url("https://api.mymemory.translated.net/get");
    QUrlQuery q;
    q.addQueryItem("q", text);
    q.addQueryItem("langpair", myMemoryLangPair(text));
    url.setQuery(q);

    QNetworkRequest req{url};
    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    req.setHeader(QNetworkRequest::UserAgentHeader, kUserAgent);
    req.setTransferTimeout(10000);

    QNetworkReply *reply = m_manager->get(req);

    connect(reply, &QNetworkReply::finished, this,
            [this, reply, batch, index]() {
        reply->deleteLater();
        if (!isBatchValid(batch)) return;

        QString translated;

        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "[Translate] MyMemory error:"
                       << reply->errorString();
        } else {
            QJsonParseError err;
            QJsonDocument doc = QJsonDocument::fromJson(reply->readAll(), &err);

            if (err.error == QJsonParseError::NoError) {
                QJsonObject obj = doc.object();
                if (obj["responseStatus"].toInt() == 200) {
                    translated = obj["responseData"].toObject()
                                    ["translatedText"].toString();
                    if (translated.contains("MYMEMORY WARNING")
                        || translated.contains("QUERY LENGTH LIMIT")
                        || translated.contains("INVALID")) {
                        translated = "";
                    }
                }
            }
        }

        batch->result[index] = translated;
        emit lineTranslated(batch->cid, index, translated);

        if (--batch->pending <= 0) finishBatch(batch);
    });
}

// ============================================================
// DeepL
// ============================================================
void TranslationService::doTranslateDeepL(BatchState *batch,
                                            const QString &targetLang) {
    if (!batch) return;

    Prepared p = prepareBatch(batch, 1000);
    if (p.texts.isEmpty()) { finishBatch(batch); return; }

    QJsonObject body;
    QJsonArray textArray;
    for (const QString &t : p.texts) textArray.append(t);
    body["text"]        = textArray;
    body["target_lang"] = normalizeDeepLTarget(targetLang);

    QByteArray payload = QJsonDocument(body).toJson(QJsonDocument::Compact);

    QString endpoint = m_apiKey.endsWith(":fx")
                       ? QString::fromLatin1(kDeepLFreeEndpoint)
                       : QString::fromLatin1(kDeepLProEndpoint);

    QNetworkRequest req{QUrl(endpoint)};
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Authorization",
                     ("DeepL-Auth-Key " + m_apiKey).toUtf8());
    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    req.setTransferTimeout(15000);

    qDebug() << "[Translate] DeepL POST:" << p.texts.size() << "lines";

    QNetworkReply *reply = m_manager->post(req, payload);
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, batch]() {
        reply->deleteLater();
        handleDeepLReply(batch, reply);
    });
}

void TranslationService::handleDeepLReply(BatchState *batch,
                                            QNetworkReply *reply) {
    if (!isBatchValid(batch)) return;

    const int httpStatus =
        reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

    if (httpStatus == 456) {
        qWarning() << "[Translate] DeepL monthly quota exhausted";
        if (!m_quotaExhausted) {
            m_quotaExhausted = true;
            emit backendChanged();
        }
        for (int idx : batch->validIndices) batch->result[idx] = "";
        finishBatch(batch);
        return;
    }

    if (reply->error() != QNetworkReply::NoError) {
        QString err = reply->errorString();
        if (httpStatus == 403) err = "DeepL API Key 无效或已过期";
        else if (httpStatus == 429) err = "请求过于频繁，请稍后再试";
        else if (httpStatus == 413) err = "歌词过长，超出 DeepL 限制";

        qWarning() << "[Translate] DeepL error:" << err;
        for (int idx : batch->validIndices) batch->result[idx] = "";
        finishBatch(batch);
        emit translateFailed(batch->cid, err);
        return;
    }

    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(reply->readAll(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        for (int idx : batch->validIndices) batch->result[idx] = "";
        finishBatch(batch);
        return;
    }

    QJsonArray translations = doc.object()["translations"].toArray();
    const int n = qMin(translations.size(), batch->validIndices.size());
    for (int i = 0; i < n; ++i) {
        QString t = translations[i].toObject()["text"].toString();
        const int originalIdx = batch->validIndices[i];
        batch->result[originalIdx] = t;
        emit lineTranslated(batch->cid, originalIdx, t);
    }
    for (int i = n; i < batch->validIndices.size(); ++i)
        batch->result[batch->validIndices[i]] = "";

    finishBatch(batch);
}

// ============================================================
// 收尾 / 清空
// ============================================================
void TranslationService::finishBatch(BatchState *batch) {
    if (!batch) return;

    const QString cid = batch->cid;
    const QStringList result = batch->result;
    const QStringList source = batch->source;

    if (m_batches.value(cid) == batch) {
        m_batches.remove(cid);
        delete batch;
    } else {
        return;
    }

    m_cache.insert(cid, result);
    m_sourceCache.insert(cid, source);

    scheduleSave();

    emit cacheCountChanged();
    emit lyricsTranslated(cid, result);
}

void TranslationService::clearCache() {
    m_cache.clear();
    m_sourceCache.clear();
    m_batches.clear();

    QString path = cacheFilePath();
    QFile::remove(path);

    emit cacheCountChanged();
    qDebug() << "[Translate] cache cleared";
}