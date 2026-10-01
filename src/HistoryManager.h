#pragma once
#include <QObject>
#include <QVariantList>
#include <QSettings>

class HistoryManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList history READ history NOTIFY historyChanged)
    Q_PROPERTY(int count READ count NOTIFY historyChanged)
public:
    explicit HistoryManager(QObject *parent = nullptr);

    QVariantList history() const { return m_history; }
    int count() const { return m_history.size(); }

    Q_INVOKABLE void addSong(const QString &cid, const QString &name,
                             const QString &artist, const QString &cover);
    Q_INVOKABLE void clear();

signals:
    void historyChanged();

private:
    QSettings m_settings;
    QVariantList m_history;
    void load();
    void save();
};