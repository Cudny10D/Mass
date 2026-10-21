#pragma once

#include <QAudioFormat>
#include <QByteArray>
#include <QVector>
#include <algorithm>
#include <cmath>
#include <cstring>

// 底鼓 / 鼓点检测
//
// 关键：只看低频。全频段 RMS 会被军鼓、人声、镲片一起触发，
// 结果就是「每 140ms 抖一下」。这里先做两阶级联低通（~140Hz），
// 把中高频滤掉，再在低频包络上做 onset 检测 —— 这才对应「鼓点」。
//
// onset 判定：~20ms 一帧的低频 RMS，明显高于最近 ~1.2 秒的平均值时
// 判为一次鼓点（energy-based onset detection）。
class BeatDetector {
public:
    void reset() {
        m_accum = 0.0;
        m_frames = 0;
        m_history.clear();
        m_history.reserve(64);
        m_lastBeatMs = -100000;
        m_level = 0.0f;
        m_strength = 0.0f;
        for (int i = 0; i < 2; ++i) m_stage[i].reset();
    }

    void setFormat(const QAudioFormat &f) {
        m_rate = f.sampleRate() > 0 ? f.sampleRate() : 44100;
        m_channels = std::max(1, f.channelCount());
        m_bytesPerSample = f.bytesPerSample();
        m_sampleFormat = f.sampleFormat();
        // ~20ms 一帧
        m_windowFrames = std::max(128, m_rate / 50);

        // 两阶 Butterworth 低通，拐点取 140Hz（采样率很低时按比例降）
        const double cutoff = std::min(140.0, m_rate * 0.10);
        for (int i = 0; i < 2; ++i)
            m_stage[i].setLowPass(cutoff, 0.70710678, double(m_rate));

        reset();
    }

    // 输入一块 PCM；返回本块中是否出现鼓点。level 为低频响度 0..1。
    bool feed(const QByteArray &pcm, qint64 nowMs, float &level) {
        return feed(pcm.constData(), pcm.size(), nowMs, level);
    }

    bool feed(const void *data, int bytes, qint64 nowMs, float &level) {
        level = m_level;
        if (m_bytesPerSample <= 0 || !data || bytes <= 0) return false;

        const int frameBytes = m_bytesPerSample * m_channels;
        if (frameBytes <= 0) return false;

        const char *p = static_cast<const char *>(data);
        const int frames = bytes / frameBytes;
        bool beat = false;

        for (int i = 0; i < frames; ++i, p += frameBytes) {
            // 多声道混成单声道，交给低通
            double mono = 0.0;
            for (int c = 0; c < m_channels; ++c)
                mono += sampleAt(p + c * m_bytesPerSample);
            mono /= double(m_channels);

            double y = m_stage[0].process(mono);
            y = m_stage[1].process(y);

            m_accum += y * y;
            if (++m_frames >= m_windowFrames) {
                const double rms = std::sqrt(m_accum / m_frames);
                m_accum = 0.0;
                m_frames = 0;
                if (processWindow(rms, nowMs)) beat = true;
            }
        }

        level = m_level;
        return beat;
    }

    float level() const { return m_level; }
    float strength() const { return m_strength; }

private:
    struct Biquad {
        double b0 = 1.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0;
        double x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;

        void reset() { x1 = x2 = y1 = y2 = 0.0; }

        void setLowPass(double fc, double q, double fs) {
            const double pi = 3.14159265358979323846;
            const double w0 = 2.0 * pi * fc / fs;
            const double alpha = std::sin(w0) / (2.0 * q);
            const double cw = std::cos(w0);
            const double a0 = 1.0 + alpha;

            b0 = (1.0 - cw) * 0.5 / a0;
            b1 = (1.0 - cw) / a0;
            b2 = (1.0 - cw) * 0.5 / a0;
            a1 = (-2.0 * cw) / a0;
            a2 = (1.0 - alpha) / a0;
        }

        double process(double x) {
            const double y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
            x2 = x1;
            x1 = x;
            y2 = y1;
            y1 = y;
            return y;
        }
    };

    bool processWindow(double rms, qint64 nowMs) {
        double avg = 0.0;
        if (!m_history.isEmpty()) {
            for (double v : m_history) avg += v;
            avg /= double(m_history.size());
        }

        m_history.push_back(rms);
        if (m_history.size() > 60) m_history.removeFirst();   // ~1.2s

        // 低频响度：底鼓比全频段安静，这里放大得多一些
        const float target = std::min(1.0f, float(rms * 12.0));
        m_level += (target - m_level) * (target > m_level ? 0.60f : 0.14f);

        if (m_history.size() < 16) return false;

        // 低频包络比较平滑，但底鼓/贝斯音符本身很密。这里把阈值和冷却都收紧：
        // 冷却 400ms 意味着视觉上最多 ~2.5 次/秒（对应 150 BPM 的四分音符），
        // 再密就会变成「一直闪」，反而看不出节拍。
        constexpr double kFloor = 0.0015;
        constexpr double kRatio = 1.65;
        constexpr qint64 kCooldownMs = 400;

        const bool loudEnough = rms > kFloor && rms > avg * kRatio;
        const bool cooled = (nowMs - m_lastBeatMs) > kCooldownMs;
        if (!loudEnough || !cooled) return false;

        m_lastBeatMs = nowMs;
        const double ratio = rms / std::max(avg, 1e-9);
        m_strength = float(std::min(1.0, (ratio - 1.0) / 1.0));
        return true;
    }

    double sampleAt(const char *p) const {
        switch (m_sampleFormat) {
        case QAudioFormat::Float: {
            float v = 0.f;
            std::memcpy(&v, p, sizeof(float));
            return double(v);
        }
        case QAudioFormat::Int16: {
            qint16 v = 0;
            std::memcpy(&v, p, sizeof(qint16));
            return double(v) / 32768.0;
        }
        case QAudioFormat::Int32: {
            qint32 v = 0;
            std::memcpy(&v, p, sizeof(qint32));
            return double(v) / 2147483648.0;
        }
        case QAudioFormat::UInt8: {
            quint8 v = 0;
            std::memcpy(&v, p, sizeof(quint8));
            return (double(v) - 128.0) / 128.0;
        }
        default:
            return 0.0;
        }
    }

    int m_rate = 44100;
    int m_channels = 2;
    int m_bytesPerSample = 0;
    int m_windowFrames = 882;
    QAudioFormat::SampleFormat m_sampleFormat = QAudioFormat::Float;

    Biquad m_stage[2];

    double m_accum = 0.0;
    int m_frames = 0;
    QVector<double> m_history;
    qint64 m_lastBeatMs = -100000;

    float m_level = 0.0f;
    float m_strength = 0.0f;
};
