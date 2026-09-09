import QtQuick
import qs.services

Item {
    id: root

    property string pendingQuery: ""

    signal resultsReady(string query, var results)

    function search(query) {
        const normalizedQuery = query.trim().toLowerCase()
        const results = SearchRegistry.getResultsRanked(normalizedQuery)
        if (results === null) {
            root.pendingQuery = query
            return
        }

        root.pendingQuery = ""
        root.resultsReady(query, results)
    }

    function setCurrentSearch(value) {
        SearchRegistry.currentSearch = value
    }

    Connections {
        target: SearchRegistry

        function onIndexReadyChanged() {
            if (!SearchRegistry.indexReady || root.pendingQuery === "") return
            const query = root.pendingQuery
            Qt.callLater(() => {
                if (root.pendingQuery !== query) return
                root.search(query)
            })
        }
    }
}
