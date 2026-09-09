#pragma once

#include <QAbstractListModel>
#include <QThread>
#include <QVariantList>

#include <atomic>

class AppSearchWorker;

class NativeAppSearchModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(bool indexReady READ indexReady NOTIFY indexReadyChanged)

public:
    enum Role {
        ModelDataRole = Qt::UserRole + 1,
    };

    explicit NativeAppSearchModel(QObject *parent = nullptr);
    ~NativeAppSearchModel() override;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool busy() const;
    bool indexReady() const;

    Q_INVOKABLE void rebuildIndex(const QVariantList &entries);
    Q_INVOKABLE void search(const QString &query, int limit, const QVariantList &fallbackRows = {});
    Q_INVOKABLE QVariantMap get(int row) const;
    Q_INVOKABLE void clear();

signals:
    void countChanged();
    void busyChanged();
    void indexReadyChanged();
    void searchFinished();

    void indexRequested(quint64 revision, const QVariantList &entries);
    void searchRequested(quint64 generation, const QString &query, int limit, const QVariantList &fallbackRows);

private slots:
    void handleIndexReady(quint64 revision);
    void handleSearchCompleted(quint64 generation, const QVariantList &rows);

private:
    void applyRows(const QVariantList &rows);
    void setBusy(bool busy);

    QVector<QVariantMap> rows_;
    QThread workerThread_;
    AppSearchWorker *worker_ = nullptr;
    std::atomic<quint64> latestSearchGeneration_ = 0;
    quint64 indexRevision_ = 0;
    QString lastQuery_;
    int lastLimit_ = 0;
    QVariantList lastFallbackRows_;
    bool busy_ = false;
    bool indexReady_ = false;
};
