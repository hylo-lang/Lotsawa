@testable import Lotsawa
import XCTest

class AdjacencyMatrixTests: XCTestCase {
  func testEmpty() {
    let x = AdjacencyMatrix()
    for i in 0..<64 {
      for j in 0..<64 {
        XCTAssert(!x.hasEdge(from: i, to: j))
      }
    }
  }

  let universe = 1..<(Int.bitWidth * 2)
  func edgeShouldExist(from x: Int, to y: Int) -> Bool { x != y && x % y == 0 }

  func divisibility() -> AdjacencyMatrix {
    var a = AdjacencyMatrix()

    for x in universe {
      for y in universe {
        if edgeShouldExist(from: x, to: y) {
          a.addEdge(from: x, to: y)
        }
      }
    }
    return a
  }

  func testAddEdge() {
    let a = divisibility()

    for x in universe {
      for y in universe {
        XCTAssertEqual(a.hasEdge(from: x, to: y), edgeShouldExist(from: x, to: y), "\(x) -> \(y)")
      }
    }
  }

  func testTransitiveClosure() {
    var a = divisibility()
    a.formTransitiveClosure()

    var a1 = Dictionary<Int, Set<Int>>()
    for x in universe {
      for y in universe {
        if edgeShouldExist(from: x, to: y) { a1[x, default: []].insert(y) }
      }
    }

    for start in universe {
      var visited = Set<Int>()

      func reachNeighbors(_ source: Int) {
        for n in a1[source, default:[]] where !visited.contains(n) {
          visited.insert(n)
          reachNeighbors(n)
        }
      }
      reachNeighbors(start)

      for end in universe {
        XCTAssertEqual(a.hasEdge(from: start, to: end), visited.contains(end), "\(start) -> \(end)")
      }
    }
  }
}
