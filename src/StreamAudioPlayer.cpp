#include "StreamAudioPlayer.h"
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QAudioSink>
#include <QAudioFormat>
#include <QAudioDevice>
#include <QMediaDevices>
#include <QDebug>
#include <QUrl>
#include <QtEndian>
#include <cstring>

static const char *kUserAgent =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36";

static constexpr quint16 WAVE_FORMAT_PCM        = 0x0001;
static constexpr quint16 WAVE_FORMAT_IEEE_FLOAT = 0x0003;
static constexpr quint16 WAVE_FORMAT_EXTENSIBLE = 0xFFFE;

// ============================================================
// 格式转换
// ============================================================
static QByteArray convert24toInt32(const QByteArray &in) {
    int samples = in.size() / 3;
    QByteArray out; out.resize(samples * 4);
    const uchar *p = reinterpret_cast<const uchar *>(in.constData());
    uchar *o = reinterpret_cast<uchar *>(out.data());
    for (int i = 0; i < samples; ++i) {
        uint32_t u = ((uint32_t)p[0] << 8)
                   | ((uint32_t)p[1] << 16)
                   | ((uint32_t)p[2] << 24);
        std::memcpy(o, &u, 4);
        p += 3; o += 4;
    }
    return out;
}
static QByteArray convert24toFloat(const QByteArray &in) {
    int samples = in.size() / 3;
    QByteArray out; out.resize(samples * 4);
    const uchar *p = reinterpret_cast<const uchar *>(in.constData());
    float *o = reinterpret_cast<float *>(out.data());
    for (int i = 0; i < samples; ++i) {
        int32_t s = (int32_t)((uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16));
        if (s & 0x800000) s |= 0xFF000000;
        *o = s / 8388608.0f;
        p += 3; ++o;
    }
    return out;
}
static QByteArray convert24toInt16(const QByteArray &in) {
    int samples = in.size() / 3;
    QByteArray out; out.resize(samples * 2);
    const uchar *p = reinterpret_cast<const uchar *>(in.constData());
    int16_t *o = reinterpret_cast<int16_t *>(out.data());
    for (int i = 0; i < samples; ++i) {
        int32_t s = (int32_t)((uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16));
        if (s & 0x800000) s |= 0xFF000000;
        o[i] = (int16_t)(s >> 8);
        p += 3;
    }
    return out;
}
static QByteArray convertFloatToInt32(const QByteArray &in) {
    int samples = in.size() / 4;
    QByteArray out; out.resize(samples * 4);
    const float *p = reinterpret_cast<const float *>(in.constData());
    int32_t *o = reinterpret_cast<int32_t *>(out.data());
    for (int i = 0; i < samples; ++i) {
        float f = p[i];
        if (f > 1.0f) f = 1.0f;
        if (f < -1.0f) f = -1.0f;
        o[i] = (int32_t)(f * 2147483647.0f);
    }
    return out;
}
static QByteArray convertFloatToInt16(const QByteArray &in) {
    int samples = in.size() / 4;
    QByteArray out; out.resize(samples * 2);
    const float *p = reinterpret_cast<const float *>(in.constData());
    int16_t *o = reinterpret_cast<int16_t *>(out.data());
    for (int i = 0; i < samples; ++i) {
        float f = p[i];
        if (f > 1.0f) f = 1.0f;
        if (f < -1.0f) f = -1.0f;
        o[i] = (int16_t)(f * 32767.0f);
    }
    return out;
}
static QByteArray convertInt32ToFloat(const QByteArray &in) {
    int samples = in.size() / 4;
    QByteArray out; out.resize(samples * 4);
    const int32_t *p = reinterpret_cast<const int32_t *>(in.constData());
    float *o = reinterpret_cast<float *>(out.data());
    for (int i = 0; i < samples; ++i) o[i] = p[i] / 2147483648.0f;
    return out;
}
static QByteArray convertInt16ToFloat(const QByteArray &in) {
    int samples = in.size() / 2;
    QByteArray out; out.resize(samples * 4);
    const int16_t *p = reinterpret_cast<const int16_t *>(in.constData());
    float *o = reinterpret_cast<float *>(out.data());
    for (int i = 0; i < samples; ++i) o[i] = p[i] / 32768.0f;
    return out;
}
static QByteArray convertInt16ToInt32(const QByteArray &in) {
    int samples = in.size() / 2;
    QByteArray out; out.resize(samples * 4);
    const int16_t *p = reinterpret_cast<const int16_t *>(in.constData());
    int32_t *o = reinterpret_cast<int32_t *>(out.data());
    for (int i = 0; i < samples; ++i) o[i] = ((int32_t)p[i]) << 16;
    return out;
}

StreamAudioPlayer::StreamAudioPlayer(QObject *parent)
    : QObject(parent) {
    m_net = new QNetworkAccessManager(this);
    m_positionTimer.setInterval(30);
    connect(&m_positionTimer, &QTimer::timeout,
            this, &StreamAudioPlayer::updatePosition);
}

StreamAudioPlayer::~StreamAudioPlayer() { stop(); }

// ============================================================
// abort 所有在飞请求
// ============================================================
void StreamAudioPlayer::abortAllInFlight() {
    for (auto *r : m_inFlight) {
        if (!r) continue;
        r->disconnect(this);
        r->abort();
        r->deleteLater();
    }
    m_inFlight.clear();
    m_orderedChunks.clear();
}

// ============================================================
// start
// ============================================================
bool StreamAudioPlayer::start(const QString &url) {
    m_generation++;

    if (m_sink) {
        QAudioSink *oldSink = m_sink;
        m_sink = nullptr;
        m_device = nullptr;
        oldSink->disconnect(this);
        oldSink->setVolume(0.0f);
        QTimer::singleShot(30, oldSink, [oldSink]() {
            oldSink->stop();
            oldSink->deleteLater();
        });
    }

    abortAllInFlight();

    m_positionTimer.stop();
    m_active = false;
    m_playing = false;
    m_paused = false;
    m_buffering = false;

    if (url.isEmpty()) return false;

    m_url          = url;
    m_active       = true;
    m_buffering    = true;
    m_bytesWritten = 0;
    m_nextFetchPos = 0;
    m_nextWritePos = 0;
    m_durationMs   = 0;
    m_seekBaseMs   = 0;
    m_info         = WavInfo();
    m_rawBuffer.clear();
    m_pcmBuffer.clear();
    m_pendingData.clear();
    m_orderedChunks.clear();

    emit bufferingChanged(true);
    emit durationChanged(0);
    emit positionChanged(0);

    qDebug() << "[Stream] start (gen" << m_generation << "):" << url;
    fetchHeader(m_generation);
    return true;
}

void StreamAudioPlayer::stop() {
    m_generation++;
    m_active = false;
    m_playing = false;
    m_paused = false;
    m_buffering = false;

    abortAllInFlight();

    if (m_sink) {
        QAudioSink *s = m_sink;
        m_sink = nullptr;
        m_device = nullptr;
        s->disconnect(this);
        s->setVolume(0.0);
        s->stop();
        s->deleteLater();
    }
    m_device = nullptr;

    m_positionTimer.stop();
    m_bytesWritten = 0;
    m_nextFetchPos = 0;
    m_nextWritePos = 0;
    m_seekBaseMs = 0;
    m_rawBuffer.clear();
    m_pcmBuffer.clear();
    m_pendingData.clear();
    m_orderedChunks.clear();
}

void StreamAudioPlayer::pause() {
    if (m_sink && m_playing) {
        m_sink->setVolume(0.0);
        m_sink->suspend();
        m_paused = true;
        emit playbackStateChanged(false);
    }
}

void StreamAudioPlayer::resume() {
    if (m_sink && m_paused) {
        m_sink->resume();
        m_sink->setVolume(m_userVolume);
        m_paused = false;
        emit playbackStateChanged(true);
    }
}

void StreamAudioPlayer::setVolume(float v) {
    m_userVolume = qBound(0.0f, v, 1.0f);
    if (m_sink) m_sink->setVolume(m_userVolume);
}

// ============================================================
// seek
// ============================================================
void StreamAudioPlayer::seek(qint64 ms) {
    if (!m_active || !m_info.valid) return;
    if (m_durationMs <= 0) return;

    if (ms < 0) ms = 0;
    if (ms > m_durationMs) ms = m_durationMs;

    int bps = bytesPerSecond();
    if (bps <= 0) return;

    qint64 offsetBytes = (ms * bps) / 1000;
    int fb = frameBytes();
    offsetBytes = (offsetBytes / fb) * fb;

    qint64 newFetchPos = m_info.dataStart + offsetBytes;

    qDebug() << "[Stream] seek to" << ms << "ms";

    m_generation++;
    abortAllInFlight();

    m_rawBuffer.clear();
    m_pcmBuffer.clear();
    m_pendingData.clear();
    m_orderedChunks.clear();
    m_bytesWritten = 0;
    m_buffering = true;
    m_playing = false;
    m_paused = false;

    if (m_sink) {
        QAudioSink *s = m_sink;
        m_sink = nullptr;
        m_device = nullptr;
        s->disconnect(this);
        s->setVolume(0.0);
        s->stop();
        s->deleteLater();
    }
    m_device = nullptr;

    m_seekBaseMs = ms;

    if (!setupSink(m_generation)) {
        m_active = false;
        emit trackFinished();
        return;
    }

    m_nextFetchPos = newFetchPos;
    m_nextWritePos = newFetchPos;
    m_positionTimer.start();

    emit bufferingChanged(true);
    emit positionChanged(ms);

    fetchChunk(m_generation);
}

qint64 StreamAudioPlayer::position() const {
    if (!m_sink || !m_device) return m_seekBaseMs;
    return m_seekBaseMs + m_sink->processedUSecs() / 1000;
}

qint64 StreamAudioPlayer::duration() const {
    return m_durationMs;
}

// ============================================================
// fetchHeader
// ============================================================
void StreamAudioPlayer::fetchHeader(quint64 gen) {
    QNetworkRequest req{QUrl(m_url)};
    req.setHeader(QNetworkRequest::UserAgentHeader, kUserAgent);
    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    req.setRawHeader("Range", "bytes=0-4095");

    auto *reply = m_net->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, gen]() {
        reply->deleteLater();
        if (gen != m_generation) return;
        if (!m_active) return;
        onHeaderReceived(reply, gen);
    });
}

void StreamAudioPlayer::onHeaderReceived(QNetworkReply *reply, quint64 gen) {
    if (gen != m_generation) return;

    if (reply->error() != QNetworkReply::NoError) {
        qWarning() << "[Stream] header failed:" << reply->errorString();
        m_active = false;
        emit trackFinished();
        return;
    }

    QByteArray buf = reply->readAll();
    qDebug() << "[Stream] header bytes:" << buf.size();

    if (!parseWavHeader(buf, m_info)) {
        qWarning() << "[Stream] invalid WAV header";
        m_active = false;
        emit trackFinished();
        return;
    }

    qint64 bytesPerSec = bytesPerSecond();
    if (bytesPerSec > 0) {
        m_durationMs = (m_info.dataSize * 1000) / bytesPerSec;
    }

    qDebug() << "[Stream] WAV:"
             << m_info.sampleRate << "Hz,"
             << m_info.channels << "ch,"
             << "formatCode:" << QString("0x%1").arg(m_info.formatCode, 4, 16, QChar('0'))
             << "container:" << m_info.containerBits << "bit,"
             << "dataStart:" << m_info.dataStart
             << "dataSize:" << m_info.dataSize / 1024 / 1024 << "MB,"
             << "duration:" << m_durationMs / 1000 << "s";

    emit durationChanged(m_durationMs);

    if (!setupSink(gen)) {
        m_active = false;
        emit trackFinished();
        return;
    }

    m_nextFetchPos = m_info.dataStart;
    m_nextWritePos = m_info.dataStart;
    m_seekBaseMs = 0;
    m_positionTimer.start();
    fetchChunk(gen);
}

// ============================================================
// setupSink
// ============================================================
bool StreamAudioPlayer::setupSink(quint64 gen) {
    if (gen != m_generation) return false;

    m_format.setSampleRate(m_info.sampleRate);
    m_format.setChannelCount(m_info.channels);

    quint16 effectiveFormat = m_info.formatCode;
    if (m_info.formatCode == WAVE_FORMAT_EXTENSIBLE) {
        effectiveFormat = m_info.subFormat;
    }

    if (effectiveFormat == WAVE_FORMAT_IEEE_FLOAT) {
        m_format.setSampleFormat(QAudioFormat::Float);
    } else {
        if (m_info.bitsPerSample <= 16) {
            m_format.setSampleFormat(QAudioFormat::Int16);
        } else {
            m_format.setSampleFormat(QAudioFormat::Int32);
        }
    }

    QAudioDevice device = QMediaDevices::defaultAudioOutput();
    if (device.isNull()) {
        qWarning() << "[Stream] no default audio output device!";
        return false;
    }

    m_sink = new QAudioSink(device, m_format, this);

    QAudioFormat actual = m_sink->format();
    qDebug() << "[Stream] actual sink format:"
             << actual.sampleRate() << "Hz,"
             << actual.channelCount() << "ch,"
             << actual.sampleFormat();

    m_format = actual;

    m_sink->setVolume(m_userVolume);
    m_sink->setBufferSize(SINK_BUFFER_SIZE);

    connect(m_sink, &QAudioSink::stateChanged, this,
            [this, gen](QAudio::State s) {
        if (gen != m_generation) return;
        onSinkStateChanged((int)s);
    });

    return true;
}

void StreamAudioPlayer::startSinkAndFlush() {
    if (!m_sink) return;
    if (m_device) return;

    m_device = m_sink->start();
    if (!m_device) {
        qWarning() << "[Stream] QAudioSink start failed, error:"
                   << m_sink->error();
        return;
    }

    {
        int bytesPerFrame = m_format.channelCount() * m_format.bytesPerSample();
        int frames = m_info.sampleRate / 100;
        if (frames < 32) frames = 32;
        QByteArray silence(frames * bytesPerFrame, '\0');
        m_device->write(silence);
    }

    flushPendingData();

    qDebug() << "[Stream] sink started, state:" << (int)m_sink->state()
             << "pending:" << m_pendingData.size() / 1024 << "KB";
}

// ============================================================
// ★ fetchChunk：并发发起最多 MAX_IN_FLIGHT 个请求
// ============================================================
void StreamAudioPlayer::fetchChunk(quint64 gen) {
    if (gen != m_generation) return;
    if (!m_active) return;

    qint64 end = m_info.dataStart + m_info.dataSize;

    // 内存压力检查：pendingData + 在飞请求估算
    qint64 estimatedPending = m_pendingData.size()
                            + m_orderedChunks.size() * CHUNK_SIZE
                            + m_inFlight.size() * CHUNK_SIZE;
    if (estimatedPending >= MAX_PENDING) return;

    // 发新请求直到 MAX_IN_FLIGHT
    while (m_inFlight.size() < MAX_IN_FLIGHT) {
        if (m_nextFetchPos >= end) break;

        qint64 remain = end - m_nextFetchPos;
        qint64 size = qMin((qint64)CHUNK_SIZE, remain);
        qint64 startPos = m_nextFetchPos;
        m_nextFetchPos += size;

        QNetworkRequest req{QUrl(m_url)};
        req.setHeader(QNetworkRequest::UserAgentHeader, kUserAgent);
        req.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
        req.setRawHeader("Range",
            QString("bytes=%1-%2")
                .arg(startPos)
                .arg(startPos + size - 1)
                .toUtf8());

        auto *reply = m_net->get(req);
        m_inFlight.append(reply);

        qDebug() << "[Stream] fetch chunk:" << size / 1024 << "KB at"
                 << startPos / 1024 << "KB"
                 << "(in-flight:" << m_inFlight.size() << ")";

        connect(reply, &QNetworkReply::finished, this,
                [this, reply, gen, startPos]() {
            reply->deleteLater();
            if (m_inFlight.contains(reply)) m_inFlight.removeOne(reply);

            if (gen != m_generation) return;
            if (!m_active) return;

            onChunkReply(reply, gen, startPos);
        });
    }
}

// ============================================================
// ★ 单个 chunk 返回：按 startPos 排序，顺序写入
// ============================================================
void StreamAudioPlayer::onChunkReply(QNetworkReply *reply, quint64 gen,
                                      qint64 startPos) {
    if (gen != m_generation) return;

    if (reply->error() != QNetworkReply::NoError) {
        qWarning() << "[Stream] chunk failed at" << startPos
                   << ":" << reply->errorString();
        // 播放中断
        m_active = false;
        m_playing = false;
        m_positionTimer.stop();
        emit playbackStateChanged(false);
        emit trackFinished();
        return;
    }

    QByteArray data = reply->readAll();
    if (data.isEmpty()) {
        fetchChunk(gen);
        return;
    }

    m_orderedChunks.insert(startPos, data);
    drainOrderedChunks();

    // 继续拉
    fetchChunk(gen);
}

// ============================================================
// ★ 按序把 orderedChunks 写入 sink
// ============================================================
void StreamAudioPlayer::drainOrderedChunks() {
    while (!m_orderedChunks.isEmpty()) {
        auto it = m_orderedChunks.find(m_nextWritePos);
        if (it == m_orderedChunks.end()) break;

        QByteArray chunk = it.value();
        m_orderedChunks.erase(it);

        writeToSink(chunk);
        m_nextWritePos += chunk.size();
    }
}

// ============================================================
// writeToSink
// ============================================================
void StreamAudioPlayer::writeToSink(const QByteArray &raw) {
    quint16 effectiveCode = m_info.formatCode;
    if (m_info.formatCode == WAVE_FORMAT_EXTENSIBLE) {
        effectiveCode = m_info.subFormat;
    }
    bool srcIsFloat = (effectiveCode == WAVE_FORMAT_IEEE_FLOAT);
    int srcBits = m_info.containerBits > 0
                ? m_info.containerBits
                : m_info.bitsPerSample;
    int srcSampleBytes = srcBits / 8;
    if (srcSampleBytes <= 0) return;

    m_rawBuffer.append(raw);
    int usable = (m_rawBuffer.size() / srcSampleBytes) * srcSampleBytes;
    if (usable <= 0) return;

    QByteArray srcAligned = m_rawBuffer.left(usable);
    m_rawBuffer.remove(0, usable);

    QAudioFormat::SampleFormat sinkFmt = m_format.sampleFormat();
    QByteArray pcm;

    if (srcIsFloat) {
        if (srcBits == 32) {
            if (sinkFmt == QAudioFormat::Float) pcm = srcAligned;
            else if (sinkFmt == QAudioFormat::Int32) pcm = convertFloatToInt32(srcAligned);
            else if (sinkFmt == QAudioFormat::Int16) pcm = convertFloatToInt16(srcAligned);
        }
    } else {
        if (srcBits == 16) {
            if (sinkFmt == QAudioFormat::Int16) pcm = srcAligned;
            else if (sinkFmt == QAudioFormat::Int32) pcm = convertInt16ToInt32(srcAligned);
            else if (sinkFmt == QAudioFormat::Float) pcm = convertInt16ToFloat(srcAligned);
        } else if (srcBits == 24) {
            if (sinkFmt == QAudioFormat::Int32) pcm = convert24toInt32(srcAligned);
            else if (sinkFmt == QAudioFormat::Float) pcm = convert24toFloat(srcAligned);
            else if (sinkFmt == QAudioFormat::Int16) pcm = convert24toInt16(srcAligned);
        } else if (srcBits == 32) {
            if (sinkFmt == QAudioFormat::Int32) pcm = srcAligned;
            else if (sinkFmt == QAudioFormat::Float) pcm = convertInt32ToFloat(srcAligned);
        }
    }

    if (pcm.isEmpty()) return;

    int bytesPerSample = m_format.bytesPerSample();
    int frameBytes = m_format.channelCount() * bytesPerSample;
    if (frameBytes <= 0) return;

    m_pcmBuffer.append(pcm);
    int aligned = (m_pcmBuffer.size() / frameBytes) * frameBytes;
    if (aligned <= 0) return;

    QByteArray toWrite = m_pcmBuffer.left(aligned);
    m_pcmBuffer.remove(0, aligned);

    m_pendingData.append(toWrite);

    if (m_buffering) {
        if (m_pendingData.size() >= PREBUFFER_BYTES) {
            m_buffering = false;
            qDebug() << "[Stream] prebuffer done,"
                     << m_pendingData.size() / 1024 << "KB, starting sink";
            startSinkAndFlush();
            emit bufferingChanged(false);
        }
        return;
    }

    flushPendingData();
}

void StreamAudioPlayer::flushPendingData() {
    if (!m_sink || !m_device) return;
    if (m_pendingData.isEmpty()) return;
    if (!m_active) return;

    QAudio::State st = m_sink->state();
    if (st == QAudio::StoppedState) return;

    qint64 totalWritten = 0;
    while (totalWritten < m_pendingData.size() && m_active) {
        qint64 w = m_device->write(m_pendingData.constData() + totalWritten,
                                    m_pendingData.size() - totalWritten);
        if (w <= 0) break;
        totalWritten += w;
    }

    if (totalWritten > 0) {
        m_bytesWritten += totalWritten;
        m_pendingData.remove(0, (int)totalWritten);
    }
}

void StreamAudioPlayer::onSinkStateChanged(int stateInt) {
    QAudio::State s = (QAudio::State)stateInt;

    switch (s) {
    case QAudio::ActiveState:
        if (!m_buffering && !m_playing && !m_paused) {
            m_playing = true;
            emit playbackStateChanged(true);
            qDebug() << "[Stream] playing (sink Active)";
        }
        if (!m_pendingData.isEmpty()) flushPendingData();
        break;

    case QAudio::IdleState:
        if (!m_pendingData.isEmpty()) { flushPendingData(); break; }
        if (m_active) {
            qint64 end = m_info.dataStart + m_info.dataSize;
            bool allFetched = (m_nextFetchPos >= end)
                           && m_inFlight.isEmpty()
                           && m_orderedChunks.isEmpty();
            if (allFetched && m_pendingData.isEmpty()) {
                qDebug() << "[Stream] finished";
                m_active = false;
                m_playing = false;
                m_positionTimer.stop();
                emit playbackStateChanged(false);
                emit trackFinished();
            } else {
                fetchChunk(m_generation);
            }
        }
        break;

    case QAudio::SuspendedState:
        break;

    case QAudio::StoppedState:
        if (m_playing) {
            m_playing = false;
            emit playbackStateChanged(false);
        }
        break;

    default:
        break;
    }
}

void StreamAudioPlayer::updatePosition() {
    if (!m_sink || !m_active) return;

    if (!m_pendingData.isEmpty()) flushPendingData();

    qint64 pos = position();
    emit positionChanged(pos);

    // pendingData 低于水位线 → 拉更多
    if (m_pendingData.size() < LOW_WATERMARK
        || m_orderedChunks.isEmpty() == false) {
        fetchChunk(m_generation);
    }
}

bool StreamAudioPlayer::parseWavHeader(const QByteArray &buf, WavInfo &out) {
    if (buf.size() < 12) return false;
    if (!buf.startsWith("RIFF")) return false;
    if (buf.mid(8, 4) != "WAVE") return false;

    int pos = 12;
    while (pos + 8 <= buf.size()) {
        QByteArray chunkId = buf.mid(pos, 4);
        quint32 chunkSize = qFromLittleEndian<quint32>(
            reinterpret_cast<const uchar *>(buf.constData() + pos + 4));

        if (chunkId == "fmt ") {
            if (chunkSize < 16 || pos + 8 + 16 > buf.size()) return false;

            const uchar *p = reinterpret_cast<const uchar *>(
                buf.constData() + pos + 8);

            out.formatCode    = qFromLittleEndian<quint16>(p + 0);
            out.channels      = qFromLittleEndian<quint16>(p + 2);
            out.sampleRate    = qFromLittleEndian<quint32>(p + 4);
            quint16 containerBits = qFromLittleEndian<quint16>(p + 14);

            out.containerBits = containerBits;
            out.bitsPerSample = containerBits;

            if (out.formatCode == WAVE_FORMAT_EXTENSIBLE && chunkSize >= 40
                && pos + 8 + 40 <= buf.size()) {
                quint16 validBits = qFromLittleEndian<quint16>(p + 18);
                if (validBits > 0 && validBits <= 32) {
                    out.bitsPerSample = validBits;
                }
                out.subFormat = qFromLittleEndian<quint16>(p + 24);
            }
        } else if (chunkId == "data") {
            out.dataStart = pos + 8;
            out.dataSize  = chunkSize;
            out.valid     = true;
            return true;
        }

        qint64 next = pos + 8 + chunkSize;
        if (chunkSize % 2 != 0) next++;
        pos = (int)next;
    }
    return false;
}