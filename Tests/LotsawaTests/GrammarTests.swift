import Lotsawa

import XCTest

extension Symbol {
  init<I: BinaryInteger>(_ id: I) { self = Symbol(id: ID(id)) }
}

class GrammarTests: XCTestCase {
  func testEmpty() {
    let g = DefaultGrammar(recognizing: Symbol(0))
    XCTAssertEqual(g.size, 0)
    XCTAssert(g.ruleIDs.isEmpty)
    XCTAssert(g.rules.isEmpty)
  }

  func test1ByteSymbols() {
    var g = Grammar<Int8>(recognizing: Symbol(0))
    let r0 = g.addRule(lhs: Symbol(0), rhs: EmptyCollection())
    XCTAssertEqual(r0.ordinal, 0)
    XCTAssertEqual(g.size, 1)

    XCTAssertEqual(Array(g.ruleIDs), [r0])
    XCTAssertEqual([[Symbol(0)]], g.rules.map { r in [r.lhs] + r.rhs })

    let r1 = g.addRule(
      lhs: Symbol(Int8.max),
      rhs: (1...4).map { i in Symbol(Int8.max - Int8(i)) })
    XCTAssertEqual(g.size, 6)

    XCTAssertEqual(Array(g.ruleIDs), [r0, r1])

    XCTAssertEqual(
      [[0], (0...4).map { i in Symbol.ID(Int8.max - Int8(i)) }],
      g.rules.map { r in [r.lhs.id] + r.rhs.map(\.id) })

    let r2 = g.addRule(lhs: Symbol(Int8.max), rhs: CollectionOfOne(Symbol(0)))
    XCTAssertEqual(g.size, 8)
    XCTAssertEqual(Array(g.ruleIDs), [r0, r1, r2])
    XCTAssertEqual(
      [[0], (0...4).map { i in Symbol.ID(Int8.max - Int8(i)) }, [Symbol.ID(Int8.max), 0]],
      g.rules.map { r in [r.lhs.id] + r.rhs.map(\.id) })

    while g.size < Int8.max {
      g.addRule(lhs: Symbol(g.size), rhs: EmptyCollection())
    }
  }

  func test2ByteSymbols1ByteSize() {
    var g = Grammar<Int16>(recognizing: Symbol(0))
    let r0 = g.addRule(lhs: Symbol(0), rhs: EmptyCollection())
    XCTAssertEqual(r0.ordinal, 0)
    XCTAssertEqual(g.size, 1)

    XCTAssertEqual(Array(g.ruleIDs), [r0])
    XCTAssertEqual([[0]], g.rules.map { r in [r.lhs.id] + r.rhs.map(\.id) })

    let r1 = g.addRule(
      lhs: Symbol(Symbol.maxID),
      rhs: (1...4).map { i in Symbol(Symbol.maxID - Int16(i)) })
    XCTAssertEqual(g.size, 6)

    XCTAssertEqual(Array(g.ruleIDs), [r0, r1])
    XCTAssertEqual(
      [[0], (0...4).map { i in Symbol.maxID - Int16(i) }],
      g.rules.map { r in [r.lhs.id] + r.rhs.map(\.id) })

    let r2 = g.addRule(lhs: Symbol(Symbol.maxID), rhs: CollectionOfOne(Symbol(0)))
    XCTAssertEqual(g.size, 8)
    XCTAssertEqual(Array(g.ruleIDs), [r0, r1, r2])
    XCTAssertEqual(
      [[0], (0...4).map { i in Symbol.maxID - Int16(i) }, [Symbol.maxID, 0]],
      g.rules.map { r in [r.lhs.id] + r.rhs.map(\.id) })
  }
}
