/// An [adjacency matrix](https://en.wikipedia.org/wiki/Adjacency_matrix) representation of a
/// directed graph.
struct AdjacencyMatrix: Hashable {
  /// Adds an edge from `source` to `destination`.
  mutating func addEdge(from source: Int, to destination: Int) {
    if rows.count <= source {
      rows.amortizedLinearReserveCapacity(source + 1)
      rows.append(contentsOf: repeatElement(BitSet(), count: source - rows.count + 1))
    }
    rows[source].insert(destination)
  }

  /// Returns true if there is an edge from `source` to `destination`.
  func hasEdge(from source: Int, to destination: Int) -> Bool {
    source < rows.count && rows[source].contains(destination)
  }

  /// A mapping from vertex onto its successors.
  var rows: [BitSet] = []

  /// For each vertex v, adds an edge from v to u iff u is reachable from v.
  ///
  /// This is the Floyd Warshall transitive closure algorithm.
  ///
  /// - Complexity: O(N^3)
  mutating func formTransitiveClosure() {
    var changed = false
    repeat {
      changed = false
      for i in rows.indices where !rows[i].isEmpty {
        for j in rows.indices where i != j && rows[i].contains(j) {
          changed = rows[i].formUnionReportingChange(rows[j]) || changed
        }
      }
    }
    while changed
  }
}
