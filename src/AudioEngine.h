#pragma once
#include <QObject>
#include <QString>
#include <QMediaPlayer>
#include <QAudioOutput>

class QTimer;
class StreamAudioPlayer;

class AudioEngine : public QObject {
    Q_OBJECT
    Q_PROPERTY(qint64 position READ position NOTIFY positionChanged)
    Q_PROPERTY(qint64 duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(int loopMode READ loopMode WRITE setLoopMode NOTIFY loopModeChanged)
    Q_PROPERTY(bool buffering READ buffering NOTIFY bufferingChanged)
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

signals:
    void playbackStateChanged(bool playing);
    void positionChanged(qint64 pos);
    void durationChanged(qint64 dur);
    void loopModeChanged(int mode);
    void bufferingChanged(bool buffering);
    void trackFinished();

private:
    QMediaPlayer *m_player = nullptr;
    QAudioOutput *m_audioOutput = nullptr;
    StreamAudioPlayer *m_stream = nullptr;
    QTimer *m_fallbackTimer = nullptr;   // ★ QMediaPlayer 卡住时的回退

    bool m_usingStream = false;
    int m_loopMode = 0;
    bool m_buffering = false;
    float m_volume = 0.8f;
    QString m_currentUrl;

    void applyLoopMode();
    void setBuffering(bool b);
    void switchToStreamPlayer();
    void switchToMediaPlayer();
};