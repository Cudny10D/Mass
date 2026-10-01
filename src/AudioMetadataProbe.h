#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QHash>
#include <QByteArray>

class AudioMetadataProbe : public QObject {
    Q_OBJECT
public:
    explicit AudioMetadataProbe(QNetworkAccessManager *sharedManager,
                                QObject *parent = nullptr);

    // 探测音频元数据（通过 Range 请求，只读头部）
    Q_INVOKABLE void probe(const QString &cid, const QString &url);

    Q_INVOKABLE bool hasResult(const QString &cid) const;
    Q_INVOKABLE qint64 getDurationMs(const QString &cid) const;
    Q_INVOKABLE int getSampleRate(const QString &cid) const;
    Q_INVOKABLE int getChannels(const QString &cid) const;
    Q_INVOKABLE void clearCache();

signals:
    void probeFinished(const QString &cid, qint64 durationMs,
                       int sampleRate, int channels);
    void probeFailed(const QString &cid, const QString &error);

private:
    struct ProbeState {
        QString url;
        int expectedBytes = 2048;
        int attempt = 0;
    };
    struct ProbeResult {
        qint64 durationMs = -1;
        int sampleRate = 0;
        int channels = 0;
    };

    QNetworkAccessManager *m_manager;
    QHash<QString, ProbeState> m_active;
    QHash<QString, ProbeResult> m_results;

    void doRequest(const QString &cid);

    static bool parseWav(const QByteArray &buf, qint64 fileSize,
                         ProbeResult &out, int &requiredBytes);
    static bool parseMp3(const QByteArray &buf, qint64 fileSize,
                         ProbeResult &out, int &requiredBytes);
};