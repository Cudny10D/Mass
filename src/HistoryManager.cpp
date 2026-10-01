#include "HistoryManager.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDateTime>
#include <QDebug>

HistoryManager::HistoryManager(QObject *parent)
    : QObject(parent),
      m_settings("ArknightsMusicPlayer", "history") {
    load();
    qDebug() << "[History] loaded" << m_history.size() << "items";
}

void HistoryManager::load() {
    QString json = m_settings.value("items").toString();
    m_history.clear();
    if (json.isEmpty()) return;

    QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    if (!doc.isArray()) return;

    for (const auto &v : doc.array()) {
        m_history.append(v.toObject().toVariantMap());
    }
}

void HistoryManager::save() {
    QJsonArray arr;
    for (const auto &v : m_history) {
        arr.append(QJsonObject::fromVariantMap(v.toMap()));
    }
    QJsonDocument doc(arr);
    m_settings.setValue("items",
        QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));
}

void HistoryManager::addSong(const QString &cid, const QString &name,
                             const QString &artist, const QString &cover) {
    qDebug() << "[History] addSong:" << cid << name;

    for (int i = m_history.size() - 1; i >= 0; --i) {
        if (m_history[i].toMap()["cid"].toString() == cid) {
            m_history.removeAt(i);
        }
    }

    QVariantMap item;
    item["cid"] = cid;
    item["name"] = name;
    item["artist"] = artist;
    item["cover"] = cover;
    item["timestamp"] = QDateTime::currentMSecsSinceEpoch();

    m_history.prepend(item);
    while (m_history.size() > 12) m_history.removeLast();

    save();
    emit historyChanged();
    qDebug() << "[History] now has" << m_history.size() << "items";
}

void HistoryManager::clear() {
    qDebug() << "[History] clear";
    m_history.clear();
    save();
    emit historyChanged();
}