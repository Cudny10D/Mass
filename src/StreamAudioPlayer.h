#pragma once
#include <QObject>
#include <QString>
#include <QByteArray>
#include <QAudioFormat>
#include <QTimer>
#include <QPointer>
#include <QList>
#include <QMap>

class QNetworkAccessManager;
class QNetworkReply;
class QAudioSink;
class QIODevice;

class StreamAudioPlayer : public QObject {
    Q_OBJECT
public:
    explicit StreamAudioPlayer(QObject *parent = nullptr);
    ~StreamAudioPlayer() override;

    bool start(const QString &url);
    void stop();
    void pause();
    void resume();
    void setVolume(float v);
    void seek(qint64 ms);

    qint64 position() const;
    qint64 duration() const;
    bool isPlaying() const { return m_playing && !m_paused; }

signals:
    void positionChanged(qint64 pos);
    void durationChanged(qint64 dur);
    void playbackStateChanged(bool playing);
    void bufferingChanged(bool buffering);
    void trackFinished();

private:
    struct WavInfo {
        int     dataStart     = 0;
        qint64  dataSize      = 0;
        int     sampleRate    = 0;
        int     channels      = 0;
        int     bitsPerSample = 0;
        int     containerBits = 0;
        quint16 formatCode    = 0;
        quint16 subFormat     = 0;
        bool    valid         = false;
    };

    QNetworkAccessManager *m_net = nullptr;
    QPointer<QAudioSink>   m_sink;
    QPointer<QIODevice>    m_device;

    QAudioFormat m_format;
    QString      m_url;
    WavInfo      m_info;

    // ---------- 并发拉取 ----------
    qint64 m_nextFetchPos = 0;
    qint64 m_nextWritePos = 0;
    QList<QNetworkReply*>    m_inFlight;
    QMap<qint64, QByteArray> m_orderedChunks;

    qint64 m_bytesWritten = 0;
    qint64 m_durationMs   = 0;
    qint64 m_seekBaseMs   = 0;

    float m_userVolume = 1.0f;

    QByteArray m_rawBuffer;
    QByteArray m_pcmBuffer;
    QByteArray m_pendingData;

    bool m_active    = false;
    bool m_playing   = false;
    bool m_paused    = false;
    bool m_buffering = false;

    quint64 m_generation = 0;

    QTimer m_positionTimer;

    static constexpr int CHUNK_SIZE       = 512 * 1024;
    static constexpr int PREBUFFER_BYTES  = 512 * 1024;
    static constexpr int LOW_WATERMARK    = 1024 * 1024;
    static constexpr int SINK_BUFFER_SIZE = 2 * 1024 * 1024;
    static constexpr int MAX_PENDING      = 6 * 1024 * 1024;
    static constexpr int MAX_IN_FLIGHT    = 3;

    int frameBytes() const {
        int cb = m_info.containerBits > 0 ? m_info.containerBits : 32;
        return (m_info.channels > 0 ? m_info.channels : 2) * (cb / 8);
    }

    int bytesPerSecond() const {
        return m_info.sampleRate * m_info.channels * (m_info.containerBits / 8);
    }

    void fetchHeader(quint64 gen);
    void onHeaderReceived(QNetworkReply *reply, quint64 gen);
    bool setupSink(quint64 gen);
    void startSinkAndFlush();
    void fetchChunk(quint64 gen);
    void onChunkReply(QNetworkReply *reply, quint64 gen, qint64 startPos);
    void drainOrderedChunks();
    void abortAllInFlight();
    void writeToSink(const QByteArray &raw);
    void flushPendingData();
    void updatePosition();
    void onSinkStateChanged(int state);

    static bool parseWavHeader(const QByteArray &buf, WavInfo &out);
};