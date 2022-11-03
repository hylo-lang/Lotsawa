@testable import Lotsawa
import XCTest

class GrammarInternalTests: XCTestCase {
  func testPredotPostdot() {
    var g = Grammar<Int8>(recognizing: Symbol(0))
    let r0 = g.addRule(lhs: Symbol(0), rhs: EmptyCollection())
    let r1 = g.addRule(lhs: Symbol(Int8.max), rhs: (1...4).map(Symbol.init))
    let r2 = g.addRule(lhs: Symbol(Int8.max), rhs: CollectionOfOne(Symbol(0)))

    XCTAssert(g.rhs(r0).isEmpty)
    XCTAssertEqual(g.rule(containing: g.rhsStart(r0)), r0)
    XCTAssertNil(g.predot(at: g.rhsStart(r0)))
    XCTAssertNil(g.postdot(at: g.rhsStart(r0)))

    let r1Start = g.rhsStart(r1)
    XCTAssertNil(g.predot(at: r1Start))

    XCTAssertEqual(g.postdot(at: r1Start), Symbol(1))
    XCTAssertEqual(g.predot(at: r1Start + 1), Symbol(1))

    XCTAssertEqual(g.postdot(at: r1Start + 1), Symbol(2))
    XCTAssertEqual(g.predot(at: r1Start + 2), Symbol(2))

    XCTAssertEqual(g.postdot(at: r1Start + 2), Symbol(3))
    XCTAssertEqual(g.predot(at: r1Start + 3), Symbol(3))

    XCTAssertEqual(g.postdot(at: r1Start + 3), Symbol(4))
    XCTAssertEqual(g.predot(at: r1Start + 4), Symbol(4))

    XCTAssertNil(g.postdot(at: r1Start + 4))


    let r2Start = g.rhsStart(r2)
    XCTAssertNil(g.predot(at: r2Start))

    XCTAssertEqual(g.postdot(at: r2Start), Symbol(0))
    XCTAssertEqual(g.predot(at: r2Start + 1), Symbol(0))

    XCTAssertNil(g.postdot(at: r2Start + 1))
  }
}
