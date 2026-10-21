#pragma once
#include <QObject>
#include <QString>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QAudioFormat>
#include <QElapsedTimer>
#include "BeatDetector.h"

class QAudioBufferOutput;
class StreamAudioPlayer;

class AudioEngine : public QObject {
    Q_OBJECT
    Q_PROPERTY(qint64 position READ position NOTIFY positionChanged)
    Q_PROPERTY(qint64 duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(int loopMode READ loopMode WRITE setLoopMode NOTIFY loopModeChanged)
    Q_PROPERTY(bool buffering READ buffering NOTIFY bufferingChanged)
    Q_PROPERTY(float volume READ volume WRITE setVolume NOTIFY volumeChanged)
    // 当前响度 0..1，供全屏播放器做随音乐起伏的背景
    Q_PROPERTY(float level READ level NOTIFY levelChanged)
public:
    explicit AudioEngine(QObject *parent = nullptr);
    ~AudioEngine();

    Q_INVOKABLE bool play(const QString &url);
    Q_INVOKABLE void pause();
    Q_INVOKABLE void resume();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void setVolume(float volume);
    Q_INVOKABLE void seek(qint64 ms);
    Q_INVOKABLE bool isPlaying() const;
    Q_INVOKABLE void cycleLoopMode();

    qint64 position() const;
    qint64 duration() const;
    int loopMode() const;
    void setLoopMode(int mode);
    bool buffering() const { return m_buffering; }
    float volume() const { return m_volume; }
    float level() const { return m_level; }

signals:
    void playbackStateChanged(bool playing);
    void positionChanged(qint64 pos);
    void durationChanged(qint64 dur);
    void loopModeChanged(int mode);
    void bufferingChanged(bool buffering);
    void volumeChanged(float volume);
    void trackFinished();
    // 检测到一次鼓点，strength 0..1
    void beat(float strength);
    void levelChanged(float level);

private:
    QMediaPlayer *m_player = nullptr;
    QAudioOutput *m_audioOutput = nullptr;
    StreamAudioPlayer *m_stream = nullptr;
    QAudioBufferOutput *m_bufferOutput = nullptr;

    BeatDetector m_beat;
    QAudioFormat m_beatFormat;
    QElapsedTimer m_clock;
    float m_level = 0.0f;
    float m_emittedLevel = -1.0f;

    bool m_usingStream = false;
    int m_loopMode = 0;
    bool m_buffering = false;
    float m_volume = 0.8f;
    QString m_currentUrl;

    void applyLoopMode();
    void setBuffering(bool b);
    void switchToStreamPlayer();
    void switchToMediaPlayer();

    void publishBeat(float strength);
    void publishLevel(float level);
};
