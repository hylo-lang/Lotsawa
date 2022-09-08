@testable import Lotsawa
import XCTest

class AdjacencyMatrixTests: XCTestCase {

  /// The range of values used to construct matrices in these tests.
  let universe = 1..<(Int.bitWidth * 2)
  
  /// Constructs an AdjacencyMatrix with an edge from `i` to `j` iff `fromPredicate(i, j)`.
  func makeAdjacencyMatrix(fromPredicate predicate: (Int, Int) -> Bool) -> AdjacencyMatrix {
    var result = AdjacencyMatrix();
    for i in universe {
      for j in universe where predicate(i, j) {
          result.addEdge(from: i, to: j);
      }
    }
    return result;
  }
  
  /// Tests that an empty AdjacencyMatrix has no edges.
  func testEmpty() {
    let x = AdjacencyMatrix()
    for i in universe {
      for j in universe {
        XCTAssert(!x.hasEdge(from: i, to: j))
      }
    }
  }
  
  /// Returns true iff `y` divides `x` and `x` and `y` are inequal.
  let nontriviallyDivides = { (_ x: Int, _ y: Int) in x != y && x % y == 0 };
  
  /// Ensures an `AdjacencyMatrix` modeling integer divisibility has the expected edges.
  func testDivisibility() {
    let divisibilityMatrix = makeAdjacencyMatrix(fromPredicate: nontriviallyDivides);
    for i in universe {
      for j in universe {
        XCTAssertEqual(divisibilityMatrix.hasEdge(from: i, to: j), nontriviallyDivides(i, j), "\(i) -> \(j)")
      }
    }
  }

  /// Ensures an `AdjacencyMatrix` modeling integer divisibility
  func testTransitiveClosure() {
    var divisibility = makeAdjacencyMatrix(fromPredicate: nontriviallyDivides);
    divisibility.formTransitiveClosure()

    /// Models the divisibility matrix as a mapping of verticies to out-edges.
    var mock = Dictionary<Int, Set<Int>>()
    for x in universe {
      for y in universe {
        if nontriviallyDivides(x, y) { mock[x, default: []].insert(y) }
      }
    }

    for start in universe {
      var visited = Set<Int>()

      /// Recursively visit each vertex following the edges in `mock`.
      func visitNeighbors(_ source: Int) {
        for n in mock[source, default:[]] where !visited.contains(n) {
          visited.insert(n)
          visitNeighbors(n)
        }
      }
      visitNeighbors(start)

      /// Ensure that all `end` vertices reachable from `start` have an edge between them in `adjacencyMatrix`.
      /// Note this does not ensure that `divisibilityMatrix` has the minimum required edges to express the transitive closure.
      for end in universe {
        XCTAssertEqual(visited.contains(end), divisibility.hasEdge(from: start, to: end), "\(start) -> \(end)")
      }
    }
  }
}

