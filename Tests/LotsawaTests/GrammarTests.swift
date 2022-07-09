import Lotsawa

import XCTest

class GrammarTests: XCTestCase {
  func testEmpty() {
    let g = Grammar<Int, Int>()
    XCTAssertEqual(g.size, 0)
    XCTAssert(g.ruleIDs.isEmpty)
    XCTAssert(g.rules.isEmpty)
  }

  func testByteSymbols() {
    var g = Grammar<Int8, Int8>()
    let r0 = g.addRule(lhs: 0, rhs: EmptyCollection())
    XCTAssertEqual(r0.ordinal, 0)
    XCTAssertEqual(g.size, 1)

    XCTAssertEqual(Array(g.ruleIDs), [r0])
    XCTAssertEqual([[0]], g.rules.map { r in [r.lhs] + r.rhs })

    let r1 = g.addRule(lhs: Int8.max, rhs: (1...4).map { i in Int8.max - Int8(i) })
    XCTAssertEqual(g.size, 6)

    XCTAssertEqual(Array(g.ruleIDs), [r0, r1])
    XCTAssertEqual(
      [[0], (0...4).map { i in Int8.max - Int8(i) }],
      g.rules.map { r in [r.lhs] + r.rhs })

    let r2 = g.addRule(lhs: Int8.max, rhs: CollectionOfOne(0))
    XCTAssertEqual(g.size, 8)
    XCTAssertEqual(Array(g.ruleIDs), [r0, r1, r2])
    XCTAssertEqual(
      [[0], (0...4).map { i in Int8.max - Int8(i) }, [Int8.max, 0]],
      g.rules.map { r in [r.lhs] + r.rhs })

    while g.size < Int8.max {
      g.addRule(lhs: Int8(g.size), rhs: EmptyCollection())
    }
  }

  func test2ByteSymbols() {
    var g = Grammar<Int16, Int8>()
    let r0 = g.addRule(lhs: 0, rhs: EmptyCollection())
    XCTAssertEqual(r0.ordinal, 0)
    XCTAssertEqual(g.size, 1)

    XCTAssertEqual(Array(g.ruleIDs), [r0])
    XCTAssertEqual([[0]], g.rules.map { r in [r.lhs] + r.rhs })

    let r1 = g.addRule(lhs: Int16.max, rhs: (1...4).map { i in Int16.max - Int16(i) })
    XCTAssertEqual(g.size, 6)

    XCTAssertEqual(Array(g.ruleIDs), [r0, r1])
    XCTAssertEqual(
      [[0], (0...4).map { i in Int16.max - Int16(i) }],
      g.rules.map { r in [r.lhs] + r.rhs })

    let r2 = g.addRule(lhs: Int16.max, rhs: CollectionOfOne(0))
    XCTAssertEqual(g.size, 8)
    XCTAssertEqual(Array(g.ruleIDs), [r0, r1, r2])
    XCTAssertEqual(
      [[0], (0...4).map { i in Int16.max - Int16(i) }, [Int16.max, 0]],
      g.rules.map { r in [r.lhs] + r.rhs })
  }
}
