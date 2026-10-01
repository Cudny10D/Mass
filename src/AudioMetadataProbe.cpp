#include "AudioMetadataProbe.h"
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QDebug>
#include <QtEndian>

static const char *kUserAgent =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36";

AudioMetadataProbe::AudioMetadataProbe(QNetworkAccessManager *sharedManager,
                                        QObject *parent)
    : QObject(parent), m_manager(sharedManager) {}

// ============================================================
// 对外接口
// ============================================================
void AudioMetadataProbe::probe(const QString &cid, const QString &url) {
    if (cid.isEmpty() || url.isEmpty()) return;

    // 命中缓存
    if (m_results.contains(cid)) {
        const auto &r = m_results[cid];
        emit probeFinished(cid, r.durationMs, r.sampleRate, r.channels);
        return;
    }

    // 已在探测中
    if (m_active.contains(cid)) return;

    ProbeState st;
    st.url = url;
    st.expectedBytes = 2048;
    st.attempt = 0;
    m_active.insert(cid, st);
    doRequest(cid);
}

bool AudioMetadataProbe::hasResult(const QString &cid) const {
    return m_results.contains(cid);
}
qint64 AudioMetadataProbe::getDurationMs(const QString &cid) const {
    auto it = m_results.find(cid);
    return it != m_results.end() ? it->durationMs : -1;
}
int AudioMetadataProbe::getSampleRate(const QString &cid) const {
    auto it = m_results.find(cid);
    return it != m_results.end() ? it->sampleRate : 0;
}
int AudioMetadataProbe::getChannels(const QString &cid) const {
    auto it = m_results.find(cid);
    return it != m_results.end() ? it->channels : 0;
}
void AudioMetadataProbe::clearCache() {
    m_results.clear();
    qDebug() << "[Probe] cache cleared";
}

// ============================================================
// 发起 Range 请求
// ============================================================
void AudioMetadataProbe::doRequest(const QString &cid) {
    auto it = m_active.find(cid);
    if (it == m_active.end()) return;
    auto &st = *it;

    st.attempt++;
    if (st.attempt > 5) {
        emit probeFailed(cid, "max attempts exceeded");
        m_active.remove(cid);
        return;
    }

    QNetworkRequest req{QUrl(st.url)};
    req.setHeader(QNetworkRequest::UserAgentHeader, kUserAgent);
    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    // ★ 关键：Range 请求，只读头部
    req.setRawHeader("Range",
        QString("bytes=0-%1").arg(st.expectedBytes - 1).toUtf8());

    qDebug() << "[Probe]" << cid << "attempt" << st.attempt
             << "range: 0-" << (st.expectedBytes - 1);

    auto *reply = m_manager->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, cid]() {
        reply->deleteLater();

        auto it2 = m_active.find(cid);
        if (it2 == m_active.end()) return;
        auto &state = *it2;

        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "[Probe]" << cid << "error:" << reply->errorString();
            emit probeFailed(cid, reply->errorString());
            m_active.remove(cid);
            return;
        }

        QByteArray buf = reply->readAll();

        // 从 Content-Range 解析完整文件大小
        // 格式: "bytes 0-2047/54321000"
        qint64 fileSize = -1;
        QByteArray crh = reply->rawHeader("Content-Range");
        if (!crh.isEmpty()) {
            int slash = crh.lastIndexOf('/');
            if (slash >= 0) {
                fileSize = crh.mid(slash + 1).trimmed().toLongLong();
            }
        }

        ProbeResult out;
        int requiredBytes = 0;
        bool ok = false;

        if (buf.size() >= 12 && buf.startsWith("RIFF")
                && buf.mid(8, 4) == "WAVE") {
            ok = parseWav(buf, fileSize, out, requiredBytes);
        } else if (buf.size() >= 3 && buf.startsWith("ID3")) {
            ok = parseMp3(buf, fileSize, out, requiredBytes);
        } else if (buf.size() >= 2 &&
                   (quint8)buf[0] == 0xFF &&
                   ((quint8)buf[1] & 0xE0) == 0xE0) {
            ok = parseMp3(buf, fileSize, out, requiredBytes);
        }

        if (ok) {
            m_results.insert(cid, out);
            m_active.remove(cid);
            qDebug() << "[Probe]" << cid << "OK:"
                     << "duration:" << out.durationMs << "ms"
                     << "sampleRate:" << out.sampleRate
                     << "channels:" << out.channels
                     << "size:" << buf.size() << "bytes";
            emit probeFinished(cid, out.durationMs, out.sampleRate, out.channels);
            return;
        }

        // 需要更多数据 → 下一轮请求更大范围
        if (requiredBytes > state.expectedBytes && requiredBytes <= 512 * 1024) {
            state.expectedBytes = requiredBytes;
            doRequest(cid);
            return;
        }

        qWarning() << "[Probe]" << cid << "parse failed, required:"
                   << requiredBytes << "have:" << buf.size();
        emit probeFailed(cid, "parse failed");
        m_active.remove(cid);
    });
}

// ============================================================
// 解析 WAV（RIFF 容器）
//   12 字节头 + "fmt " chunk + "data" chunk
//   从 data chunk 的 size 和采样率、声道、位深算时长
// ============================================================
bool AudioMetadataProbe::parseWav(const QByteArray &buf, qint64 fileSize,
                                   ProbeResult &out, int &requiredBytes) {
    Q_UNUSED(fileSize)

    if (buf.size() < 44) {
        requiredBytes = 44;
        return false;
    }

    int pos = 12;
    quint16 channels = 0;
    quint32 sampleRate = 0;
    quint16 bitsPerSample = 0;
    quint32 dataSize = 0;

    while (pos + 8 <= buf.size()) {
        QByteArray chunkId = buf.mid(pos, 4);
        quint32 chunkSize = qFromLittleEndian<quint32>(
            reinterpret_cast<const uchar *>(buf.constData() + pos + 4));

        if (chunkId == "fmt ") {
            if (pos + 8 + 16 > buf.size()) {
                requiredBytes = pos + 8 + 16;
                return false;
            }
            const uchar *p = reinterpret_cast<const uchar *>(
                buf.constData() + pos + 8);
            // AudioFormat: p[0..1]  (1=PCM, 3=IEEE float)
            channels      = qFromLittleEndian<quint16>(p + 2);
            sampleRate    = qFromLittleEndian<quint32>(p + 4);
            // ByteRate:   p[8..11]
            // BlockAlign: p[12..13]
            bitsPerSample = qFromLittleEndian<quint16>(p + 14);
        } else if (chunkId == "data") {
            dataSize = chunkSize;
            break;
        }

        qint64 next = pos + 8 + chunkSize;
        if (chunkSize % 2 != 0) next++;   // chunk 偶数对齐
        pos = (int)next;

        if (pos + 8 > buf.size()) {
            requiredBytes = qMin(pos + 8 + 4096, 512 * 1024);
            return false;
        }
    }

    if (dataSize > 0 && sampleRate > 0 && channels > 0 && bitsPerSample > 0) {
        double bytesPerSec = (double)sampleRate * channels
                           * (bitsPerSample / 8.0);
        double durationSec = dataSize / bytesPerSec;
        out.durationMs = (qint64)(durationSec * 1000.0);
        out.sampleRate = (int)sampleRate;
        out.channels   = (int)channels;
        return true;
    }

    requiredBytes = qMin((int)buf.size() + 8192, 512 * 1024);
    return false;
}

// ============================================================
// 解析 MP3（ID3v2 + MPEG 帧头 + CBR 估算）
// ============================================================
bool AudioMetadataProbe::parseMp3(const QByteArray &buf, qint64 fileSize,
                                   ProbeResult &out, int &requiredBytes) {
    int frameStart = 0;
    int id3Size = 0;

    // 跳过 ID3v2
    if (buf.size() >= 10 && buf.startsWith("ID3")) {
        const uchar *p = reinterpret_cast<const uchar *>(buf.constData());
        // 同步安全整数（每字节低 7 位）
        id3Size = ((p[6] & 0x7F) << 21) |
                  ((p[7] & 0x7F) << 14) |
                  ((p[8] & 0x7F) << 7)  |
                  (p[9] & 0x7F);
        frameStart = 10 + id3Size;
    }

    if (buf.size() < frameStart + 4) {
        requiredBytes = frameStart + 4 + 1024;
        return false;
    }

    const uchar *h = reinterpret_cast<const uchar *>(
        buf.constData() + frameStart);
    if (h[0] != 0xFF || (h[1] & 0xE0) != 0xE0) {
        requiredBytes = 0;
        return false;
    }

    int versionBits = (h[1] >> 3) & 0x03;   // 00=2.5, 10=2, 11=1
    int layerBits   = (h[1] >> 1) & 0x03;   // 01=III, 10=II, 11=I
    int bitrateIdx  = (h[2] >> 4) & 0x0F;
    int srIdx       = (h[2] >> 2) & 0x03;
    int chanMode    = (h[3] >> 6) & 0x03;

    if (versionBits == 1 || layerBits == 0) return false;
    if (bitrateIdx == 0 || bitrateIdx == 15 || srIdx == 3) return false;

    // 比特率表（kbps）
    static const int bitrates[2][3][16] = {
        {   // MPEG1
            {0,32,64,96,128,160,192,224,256,288,320,352,384,416,448,0},
            {0,32,48,56,64,80,96,112,128,160,192,224,256,320,384,0},
            {0,32,40,48,56,64,80,96,112,128,160,192,224,256,320,0},
        },
        {   // MPEG2 / 2.5
            {0,32,48,56,64,80,96,112,128,144,160,176,192,224,256,0},
            {0,8,16,24,32,40,48,56,64,80,96,112,128,144,160,0},
            {0,8,16,24,32,40,48,56,64,80,96,112,128,144,160,0},
        }
    };

    int verIdx = (versionBits == 3) ? 0 : 1;
    int layIdx = 3 - layerBits;
    int bitrateKbps = bitrates[verIdx][layIdx][bitrateIdx];
    if (bitrateKbps == 0) return false;

    // 采样率
    static const int srMPEG1[3] = {44100, 48000, 32000};
    int sampleRate = srMPEG1[srIdx];
    if (versionBits == 2) sampleRate /= 2;
    else if (versionBits == 0) sampleRate /= 4;

    if (fileSize <= 0) return false;

    // CBR 时长估算
    qint64 audioBytes = fileSize - id3Size;
    double durationSec = (audioBytes * 8.0) / (bitrateKbps * 1000.0);

    out.durationMs = (qint64)(durationSec * 1000.0);
    out.sampleRate = sampleRate;
    out.channels   = (chanMode == 3) ? 1 : 2;
    return true;
}