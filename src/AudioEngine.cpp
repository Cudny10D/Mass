#include "AudioEngine.h"
#include "StreamAudioPlayer.h"
#include <QDebug>
#include <QUrl>
#include <QTimer>

AudioEngine::AudioEngine(QObject *parent)
    : QObject(parent),
      m_player(new QMediaPlayer(this)),
      m_audioOutput(new QAudioOutput(this)),
      m_stream(new StreamAudioPlayer(this)) {

    m_player->setAudioOutput(m_audioOutput);
    m_audioOutput->setVolume(m_volume);

    // ---- QMediaPlayer 信号 ----
    connect(m_player, &QMediaPlayer::playingChanged, this, [this]() {
        qDebug() << "[QMediaPlayer] playingChanged =" << m_player->isPlaying();
        if (!m_usingStream) emit playbackStateChanged(m_player->isPlaying());
    });
    connect(m_player, &QMediaPlayer::positionChanged, this, [this](qint64 p) {
        if (!m_usingStream) emit positionChanged(p);
    });
    connect(m_player, &QMediaPlayer::durationChanged, this, [this](qint64 d) {
        qDebug() << "[QMediaPlayer] durationChanged =" << d << "ms";
        if (!m_usingStream) emit durationChanged(d);
    });
    connect(m_player, &QMediaPlayer::mediaStatusChanged, this,
            [this](QMediaPlayer::MediaStatus s) {
        QString status;
        switch (s) {
        case QMediaPlayer::NoMedia:         status = "NoMedia"; break;
        case QMediaPlayer::LoadingMedia:    status = "LoadingMedia"; break;
        case QMediaPlayer::LoadedMedia:     status = "LoadedMedia"; break;
        case QMediaPlayer::StalledMedia:    status = "StalledMedia"; break;
        case QMediaPlayer::BufferingMedia:  status = "BufferingMedia"; break;
        case QMediaPlayer::BufferedMedia:   status = "BufferedMedia"; break;
        case QMediaPlayer::EndOfMedia:      status = "EndOfMedia"; break;
        case QMediaPlayer::InvalidMedia:    status = "InvalidMedia"; break;
        }
        qDebug() << "[QMediaPlayer] mediaStatus =" << status;

        if (m_usingStream) return;

        if (s == QMediaPlayer::LoadedMedia
            || s == QMediaPlayer::BufferedMedia) {
            // 加载成功 → 停止回退定时器
            if (m_fallbackTimer) m_fallbackTimer->stop();
        }

        if (s == QMediaPlayer::EndOfMedia && m_loopMode != 1) {
            emit trackFinished();
        }
    });
    connect(m_player, &QMediaPlayer::errorOccurred, this,
            [this](QMediaPlayer::Error e, const QString &msg) {
        qWarning() << "[QMediaPlayer] error:" << e << msg;
        // 错误 → 尝试回退到流式播放
        if (!m_usingStream && !m_currentUrl.isEmpty()) {
            qDebug() << "[AudioEngine] QMediaPlayer failed, fallback to stream";
            switchToStreamPlayer();
            m_stream->start(m_currentUrl);
        }
    });

    // ---- StreamAudioPlayer 信号转发 ----
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
        if (m_loopMode == 1) {
            m_stream->start(m_currentUrl);
        } else {
            emit trackFinished();
        }
    });

    // ★ 回退定时器：QMediaPlayer 3 秒没起来 → 用 StreamAudioPlayer
    m_fallbackTimer = new QTimer(this);
    m_fallbackTimer->setSingleShot(true);
    m_fallbackTimer->setInterval(3000);
    connect(m_fallbackTimer, &QTimer::timeout, this, [this]() {
        if (m_usingStream) return;
        if (m_currentUrl.isEmpty()) return;

        QMediaPlayer::MediaStatus st = m_player->mediaStatus();
        if (st == QMediaPlayer::LoadedMedia
            || st == QMediaPlayer::BufferedMedia
            || st == QMediaPlayer::BufferingMedia) {
            qDebug() << "[AudioEngine] fallback cancelled, QMediaPlayer OK";
            return;
        }

        qWarning() << "[AudioEngine] QMediaPlayer stuck at" << st
                   << "→ fallback to StreamAudioPlayer";
        m_player->stop();
        switchToStreamPlayer();
        m_stream->start(m_currentUrl);
    });

    applyLoopMode();
}

AudioEngine::~AudioEngine() = default;

bool AudioEngine::play(const QString &url) {
    qDebug() << "[AudioEngine] play() url=" << url;
    if (url.isEmpty()) return false;

    m_currentUrl = url;

    // 清空旧的流式状态
    if (m_usingStream) {
        m_stream->stop();
        setBuffering(false);
        m_usingStream = false;
        qDebug() << "[AudioEngine] switched from stream to QMediaPlayer";
    }

    // ★ 先试 QMediaPlayer
    m_player->setSource(QUrl(url));
    m_player->play();

    // 启动回退定时器
    if (m_fallbackTimer) m_fallbackTimer->start();

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
    if (m_fallbackTimer) m_fallbackTimer->stop();
    if (m_usingStream) m_stream->stop();
    else m_player->stop();
    setBuffering(false);
}

void AudioEngine::setVolume(float v) {
    m_volume = qBound(0.0f, v, 1.0f);
    m_audioOutput->setVolume(m_volume);
    m_stream->setVolume(m_volume);
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
    mode = ((mode % 3) + 3) % 3;
    if (m_loopMode == mode) return;
    m_loopMode = mode;
    applyLoopMode();
    emit loopModeChanged(mode);
}

void AudioEngine::applyLoopMode() {
    if (m_loopMode == 1) {
        m_player->setLoops(QMediaPlayer::Infinite);
    } else {
        m_player->setLoops(1);
    }
}

void AudioEngine::cycleLoopMode() {
    setLoopMode((m_loopMode + 1) % 3);
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
    setBuffering(false);
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