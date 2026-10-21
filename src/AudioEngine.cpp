#include "AudioEngine.h"
#include "StreamAudioPlayer.h"
#include <QDebug>
#include <QUrl>
#include <QAudioBufferOutput>
#include <QAudioBuffer>
#include <cmath>

AudioEngine::AudioEngine(QObject *parent)
    : QObject(parent),
      m_player(new QMediaPlayer(this)),
      m_audioOutput(new QAudioOutput(this)),
      m_stream(new StreamAudioPlayer(this)) {

    m_player->setAudioOutput(m_audioOutput);
    m_audioOutput->setVolume(m_volume);
    m_clock.start();

    // 拿到 QMediaPlayer 解码后的 PCM，用来做鼓点/响度检测。
    // 注意：只有非流式播放（本地文件等）走这里；流式播放由
    // StreamAudioPlayer 在写音频设备前自己算。
    m_bufferOutput = new QAudioBufferOutput(this);
    m_player->setAudioBufferOutput(m_bufferOutput);
    connect(m_bufferOutput, &QAudioBufferOutput::audioBufferReceived,
            this, [this](const QAudioBuffer &buffer) {
        if (m_usingStream || !buffer.isValid()) return;

        const QAudioFormat fmt = buffer.format();
        if (fmt != m_beatFormat) {
            m_beatFormat = fmt;
            m_beat.setFormat(fmt);
        }

        float level = 0.0f;
        const bool isBeat = m_beat.feed(buffer.constData<uchar>(),
                                        int(buffer.byteCount()),
                                        m_clock.elapsed(), level);
        publishLevel(level);
        if (isBeat) publishBeat(m_beat.strength());
    });

    // QMediaPlayer 信号
    connect(m_player, &QMediaPlayer::playingChanged, this, [this]() {
        if (!m_usingStream) emit playbackStateChanged(m_player->isPlaying());
    });
    connect(m_player, &QMediaPlayer::positionChanged, this, [this](qint64 p) {
        if (!m_usingStream) emit positionChanged(p);
    });
    connect(m_player, &QMediaPlayer::durationChanged, this, [this](qint64 d) {
        if (!m_usingStream) emit durationChanged(d);
    });
    connect(m_player, &QMediaPlayer::mediaStatusChanged, this,
            [this](QMediaPlayer::MediaStatus s) {
        if (m_usingStream) return;
        if (s == QMediaPlayer::EndOfMedia && m_loopMode != 1) {
            emit trackFinished();
        }
    });
    connect(m_player, &QMediaPlayer::errorOccurred, this,
            [](QMediaPlayer::Error e, const QString &msg) {
        qWarning() << "[QMediaPlayer] error:" << e << msg;
    });

    // StreamAudioPlayer 信号
    connect(m_stream, &StreamAudioPlayer::positionChanged,
            this, [this](qint64 p) {
        if (m_usingStream) emit positionChanged(p);
    });
    connect(m_stream, &StreamAudioPlayer::durationChanged,
            this, [this](qint64 d) {
        if (m_usingStream) emit durationChanged(d);
    });
    connect(m_stream, &StreamAudioPlayer::playbackStateChanged,
            this, [this](bool p) {
        if (m_usingStream) emit playbackStateChanged(p);
    });
    connect(m_stream, &StreamAudioPlayer::bufferingChanged,
            this, [this](bool b) {
        if (m_usingStream) setBuffering(b);
    });
    connect(m_stream, &StreamAudioPlayer::trackFinished, this, [this]() {
        if (!m_usingStream) return;
        if (m_loopMode == 1) m_stream->start(m_currentUrl);
        else emit trackFinished();
    });
    // 流式播放的鼓点/响度
    connect(m_stream, &StreamAudioPlayer::beat, this, [this](float s) {
        if (m_usingStream) publishBeat(s);
    });
    connect(m_stream, &StreamAudioPlayer::levelChanged, this, [this](float l) {
        if (m_usingStream) publishLevel(l);
    });

    applyLoopMode();
}

void AudioEngine::publishBeat(float strength) {
    emit beat(strength);
}

void AudioEngine::publishLevel(float level) {
    m_level = level;
    // 变化太小就不发信号，避免每帧都刷 QML
    if (std::abs(level - m_emittedLevel) < 0.004f) return;
    m_emittedLevel = level;
    emit levelChanged(level);
}

AudioEngine::~AudioEngine() = default;

// ============================================================
// play：远程 WAV → 流式播放；其它 → QMediaPlayer
// ============================================================
bool AudioEngine::play(const QString &url) {
    qDebug() << "[AudioEngine] play() url=" << url;
    if (url.isEmpty()) return false;

    m_currentUrl = url;

    bool isRemote = url.startsWith("http://") || url.startsWith("https://");
    bool isWav = url.endsWith(".wav", Qt::CaseInsensitive);

    if (isRemote && isWav) {
        // 流式播放，立即出声音
        switchToStreamPlayer();
        return m_stream->start(url);
    }

    // 其它走 QMediaPlayer
    switchToMediaPlayer();
    m_player->setSource(QUrl(url));
    m_player->play();
    return true;
}

void AudioEngine::pause() {
    if (m_usingStream) m_stream->pause();
    else m_player->pause();
}

void AudioEngine::resume() {
    if (m_usingStream) m_stream->resume();
    else m_player->play();
}

void AudioEngine::stop() {
    if (m_usingStream) m_stream->stop();
    else m_player->stop();
    m_beat.reset();
    publishLevel(0.0f);
    m_emittedLevel = -1.0f;
    setBuffering(false);
}

void AudioEngine::setVolume(float v) {
    v = qBound(0.0f, v, 1.0f);
    if (qFuzzyCompare(m_volume, v)) return;
    m_volume = v;
    m_audioOutput->setVolume(m_volume);
    m_stream->setVolume(m_volume);
    emit volumeChanged(m_volume);
}

void AudioEngine::seek(qint64 ms) {
    if (m_usingStream) m_stream->seek(ms);
    else m_player->setPosition(ms);
}

bool AudioEngine::isPlaying() const {
    if (m_usingStream) return m_stream->isPlaying();
    return m_player->playbackState() == QMediaPlayer::PlayingState;
}

qint64 AudioEngine::position() const {
    if (m_usingStream) return m_stream->position();
    return m_player->position();
}

qint64 AudioEngine::duration() const {
    if (m_usingStream) return m_stream->duration();
    return m_player->duration();
}

int AudioEngine::loopMode() const { return m_loopMode; }

void AudioEngine::setLoopMode(int mode) {
    mode = ((mode % 4) + 4) % 4;
    if (m_loopMode == mode) return;
    m_loopMode = mode;
    applyLoopMode();
    emit loopModeChanged(mode);
}

void AudioEngine::applyLoopMode() {
    if (m_loopMode == 1) m_player->setLoops(QMediaPlayer::Infinite);
    else m_player->setLoops(1);
}

void AudioEngine::cycleLoopMode() {
    setLoopMode((m_loopMode + 1) % 4);
}

void AudioEngine::setBuffering(bool b) {
    if (m_buffering == b) return;
    m_buffering = b;
    qDebug() << "[AudioEngine] buffering =" << b;
    emit bufferingChanged(b);
}

void AudioEngine::switchToStreamPlayer() {
    if (m_usingStream) return;
    m_player->stop();
    setBuffering(true);
    m_usingStream = true;
    qDebug() << "[AudioEngine] → STREAM player";
}

void AudioEngine::switchToMediaPlayer() {
    if (!m_usingStream) return;
    m_stream->stop();
    setBuffering(false);
    m_usingStream = false;
    qDebug() << "[AudioEngine] → MEDIA player";
}