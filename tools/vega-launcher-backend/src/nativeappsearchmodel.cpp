#include "nativeappsearchmodel.h"

#include <QMetaObject>
#include <QObject>
#include <QRegularExpression>
#include <QSet>
#include <QStringList>

#include <algorithm>
#include <limits>
#include <optional>

namespace {

struct IndexedApp {
    QString id;
    QString name;
    QString foldedName;
    QStringList foldedWords;
    QString initials;
    QString iconName;
};

struct ScoredApp {
    int index;
    int score;
};

constexpr int confidentMatchScore = 800'000;

QStringList splitWords(const QString &text)
{
    static const QRegularExpression separator(QStringLiteral("[^\\p{L}\\p{N}]+"));
    return text.split(separator, Qt::SkipEmptyParts);
}

QString wordInitials(const QStringList &words)
{
    QString initials;
    initials.reserve(words.size());
    for (const QString &word : words)
        initials.append(word.front());
    return initials;
}

std::optional<int> fuzzyScore(const IndexedApp &app, const QString &query,
                              const QStringList &queryWords, const QString &compactQuery)
{
    const QString &text = app.foldedName;
    if (query.isEmpty())
        return 0;
    if (text == query)
        return 1'000'000;
    if (text.startsWith(query))
        return 950'000 - text.size();

    int nextWord = 0;
    int skippedWords = 0;
    int unmatchedCharacters = 0;
    bool allWordsMatch = !queryWords.isEmpty();
    for (const QString &queryWord : queryWords) {
        int matchedWord = nextWord;
        while (matchedWord < app.foldedWords.size()
               && !app.foldedWords.at(matchedWord).startsWith(queryWord))
            ++matchedWord;
        if (matchedWord == app.foldedWords.size()) {
            allWordsMatch = false;
            break;
        }
        skippedWords += matchedWord - nextWord;
        unmatchedCharacters += app.foldedWords.at(matchedWord).size() - queryWord.size();
        nextWord = matchedWord + 1;
    }
    if (allWordsMatch)
        return 900'000 - skippedWords * 1'000 - unmatchedCharacters;

    if (compactQuery.size() > 1 && app.initials.startsWith(compactQuery))
        return 850'000 - app.initials.size();

    const qsizetype containedAt = text.indexOf(query);
    if (containedAt >= 0)
        return 700'000 - static_cast<int>(containedAt * 32 + text.size());

    int score = 0;
    qsizetype previous = -1;
    qsizetype cursor = 0;
    for (const QChar character : query) {
        const qsizetype position = text.indexOf(character, cursor);
        if (position < 0)
            return std::nullopt;

        score += 100;
        if (position == 0 || !text.at(position - 1).isLetterOrNumber())
            score += 80;
        if (previous >= 0) {
            const int gap = static_cast<int>(position - previous - 1);
            score += gap == 0 ? 60 : -gap * 4;
        } else {
            score -= static_cast<int>(position * 6);
        }
        previous = position;
        cursor = position + 1;
    }

    return score - static_cast<int>(text.size() - query.size());
}

QVariantMap appRow(const IndexedApp &app)
{
    return {
        {QStringLiteral("nativeApp"), true},
        {QStringLiteral("key"), QStringLiteral("app:") + app.id},
        {QStringLiteral("id"), app.id},
        {QStringLiteral("name"), app.name},
        {QStringLiteral("iconName"), app.iconName},
    };
}

} // namespace

class AppSearchWorker final : public QObject
{
    Q_OBJECT

public:
    explicit AppSearchWorker(std::atomic<quint64> *latestGeneration)
        : latestGeneration_(latestGeneration)
    {
    }

public slots:
    void rebuildIndex(quint64 revision, const QVariantList &entries)
    {
        QVector<IndexedApp> index;
        QSet<QString> seenIds;
        index.reserve(entries.size());
        for (const QVariant &value : entries) {
            const QVariantMap entry = value.toMap();
            const QString name = entry.value(QStringLiteral("name")).toString().trimmed();
            if (name.isEmpty())
                continue;

            QString id = entry.value(QStringLiteral("id")).toString();
            if (id.isEmpty())
                id = name;
            if (seenIds.contains(id))
                continue;
            seenIds.insert(id);
            const QString foldedName = name.toCaseFolded();
            const QStringList foldedWords = splitWords(foldedName);
            index.push_back({
                .id = std::move(id),
                .name = name,
                .foldedName = foldedName,
                .foldedWords = foldedWords,
                .initials = wordInitials(foldedWords),
                .iconName = entry.value(QStringLiteral("iconName")).toString(),
            });
        }
        index_ = std::move(index);
        emit indexReady(revision);
    }

    void search(quint64 generation, const QString &query, int limit, const QVariantList &fallbackRows)
    {
        if (generation != latestGeneration_->load(std::memory_order_acquire))
            return;

        const QString foldedQuery = query.trimmed().toCaseFolded();
        const QStringList queryWords = splitWords(foldedQuery);
        const QString compactQuery = queryWords.join(QString());
        QVector<ScoredApp> matches;
        matches.reserve(index_.size());
        bool hasConfidentMatch = false;
        for (int i = 0; i < index_.size(); ++i) {
            if (generation != latestGeneration_->load(std::memory_order_relaxed))
                return;
            const std::optional<int> score = fuzzyScore(index_.at(i), foldedQuery, queryWords, compactQuery);
            if (score) {
                matches.push_back({i, *score});
                hasConfidentMatch |= *score >= confidentMatchScore;
            }
        }

        std::sort(matches.begin(), matches.end(), [this](const ScoredApp &left, const ScoredApp &right) {
            if (left.score != right.score)
                return left.score > right.score;
            return QString::localeAwareCompare(index_.at(left.index).name, index_.at(right.index).name) < 0;
        });

        QVariantList rows;
        rows.reserve(std::max(0, limit));
        for (const ScoredApp &match : matches) {
            if (rows.size() >= limit)
                break;
            if (hasConfidentMatch && match.score < confidentMatchScore)
                continue;
            rows.push_back(appRow(index_.at(match.index)));
        }
        if (!hasConfidentMatch) {
            for (const QVariant &fallback : fallbackRows) {
                if (rows.size() >= limit)
                    break;
                rows.push_back(fallback);
            }
        }

        if (generation == latestGeneration_->load(std::memory_order_acquire))
            emit searchCompleted(generation, rows);
    }

signals:
    void indexReady(quint64 revision);
    void searchCompleted(quint64 generation, const QVariantList &rows);

private:
    std::atomic<quint64> *latestGeneration_;
    QVector<IndexedApp> index_;
};

NativeAppSearchModel::NativeAppSearchModel(QObject *parent)
    : QAbstractListModel(parent)
    , worker_(new AppSearchWorker(&latestSearchGeneration_))
{
    workerThread_.setObjectName(QStringLiteral("vega-app-search"));
    worker_->moveToThread(&workerThread_);

    connect(this, &NativeAppSearchModel::indexRequested,
            worker_, &AppSearchWorker::rebuildIndex, Qt::QueuedConnection);
    connect(this, &NativeAppSearchModel::searchRequested,
            worker_, &AppSearchWorker::search, Qt::QueuedConnection);
    connect(worker_, &AppSearchWorker::indexReady,
            this, &NativeAppSearchModel::handleIndexReady, Qt::QueuedConnection);
    connect(worker_, &AppSearchWorker::searchCompleted,
            this, &NativeAppSearchModel::handleSearchCompleted, Qt::QueuedConnection);
    connect(&workerThread_, &QThread::finished, worker_, &QObject::deleteLater);

    workerThread_.start();
}

NativeAppSearchModel::~NativeAppSearchModel()
{
    latestSearchGeneration_.store(std::numeric_limits<quint64>::max(), std::memory_order_release);
    workerThread_.quit();
    workerThread_.wait();
}

int NativeAppSearchModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : rows_.size();
}

QVariant NativeAppSearchModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= rows_.size())
        return {};
    if (role == ModelDataRole)
        return rows_.at(index.row());
    return {};
}

QHash<int, QByteArray> NativeAppSearchModel::roleNames() const
{
    return {{ModelDataRole, QByteArrayLiteral("modelData")}};
}

bool NativeAppSearchModel::busy() const
{
    return busy_;
}

bool NativeAppSearchModel::indexReady() const
{
    return indexReady_;
}

void NativeAppSearchModel::rebuildIndex(const QVariantList &entries)
{
    latestSearchGeneration_.fetch_add(1, std::memory_order_acq_rel);
    setBusy(false);
    if (indexReady_) {
        indexReady_ = false;
        emit indexReadyChanged();
    }
    emit indexRequested(++indexRevision_, entries);
}

void NativeAppSearchModel::search(const QString &query, int limit, const QVariantList &fallbackRows)
{
    lastQuery_ = query;
    lastLimit_ = std::max(0, limit);
    lastFallbackRows_ = fallbackRows;

    const quint64 generation = latestSearchGeneration_.fetch_add(1, std::memory_order_acq_rel) + 1;
    if (query.trimmed().isEmpty() || lastLimit_ == 0) {
        setBusy(false);
        applyRows({});
        emit searchFinished();
        return;
    }

    if (!indexReady_) {
        setBusy(false);
        applyRows(fallbackRows.mid(0, lastLimit_));
        return;
    }

    setBusy(true);
    emit searchRequested(generation, query, lastLimit_, fallbackRows);
}

QVariantMap NativeAppSearchModel::get(int row) const
{
    if (row < 0 || row >= rows_.size())
        return {};
    return rows_.at(row);
}

void NativeAppSearchModel::clear()
{
    latestSearchGeneration_.fetch_add(1, std::memory_order_acq_rel);
    lastQuery_.clear();
    lastFallbackRows_.clear();
    setBusy(false);
    applyRows({});
}

void NativeAppSearchModel::handleIndexReady(quint64 revision)
{
    if (revision != indexRevision_)
        return;
    indexReady_ = true;
    emit indexReadyChanged();
    search(lastQuery_, lastLimit_, lastFallbackRows_);
}

void NativeAppSearchModel::handleSearchCompleted(quint64 generation, const QVariantList &rows)
{
    if (generation != latestSearchGeneration_.load(std::memory_order_acquire))
        return;
    applyRows(rows);
    setBusy(false);
    emit searchFinished();
}

void NativeAppSearchModel::applyRows(const QVariantList &rows)
{
    QVector<QVariantMap> desired;
    QSet<QString> desiredKeys;
    desired.reserve(rows.size());
    for (const QVariant &value : rows) {
        const QVariantMap row = value.toMap();
        const QString key = row.value(QStringLiteral("key")).toString();
        if (key.isEmpty() || desiredKeys.contains(key))
            continue;
        desiredKeys.insert(key);
        desired.push_back(row);
    }

    const int oldCount = rows_.size();
    const int commonCount = std::min(oldCount, static_cast<int>(desired.size()));
    int firstChanged = -1;
    int lastChanged = -1;
    for (int row = 0; row < commonCount; ++row) {
        if (rows_.at(row) == desired.at(row))
            continue;
        rows_[row] = desired.at(row);
        if (firstChanged < 0)
            firstChanged = row;
        lastChanged = row;
    }

    if (desired.size() < oldCount) {
        beginRemoveRows({}, desired.size(), oldCount - 1);
        rows_.remove(desired.size(), oldCount - desired.size());
        endRemoveRows();
    } else if (desired.size() > oldCount) {
        beginInsertRows({}, oldCount, desired.size() - 1);
        for (int row = oldCount; row < desired.size(); ++row)
            rows_.push_back(desired.at(row));
        endInsertRows();
    }

    if (firstChanged >= 0)
        emit dataChanged(index(firstChanged), index(lastChanged), {ModelDataRole});
    if (oldCount != desired.size())
        emit this->countChanged();
}

void NativeAppSearchModel::setBusy(bool busy)
{
    if (busy_ == busy)
        return;
    busy_ = busy;
    emit busyChanged();
}

#include "nativeappsearchmodel.moc"
