@testable import Lotsawa
import XCTest

class ChartInternalTests: XCTestCase {
  func testItemOperations() throws {
    let g = try """
      A ::= B C D E
      """
      .asTestGrammar(recognizing: "A")

    let i0 = Chart.Item(predicting: g.raw.ruleIDs.first!, in: g.raw, at: 42)
    XCTAssert(i0.isEarley)
    XCTAssertFalse(i0.isCompletion)
    XCTAssertNil(i0.lhs)
    XCTAssertEqual(g.symbolName[Int(i0.transitionSymbol!.id)], "B")

    let i1 = i0.advanced(in: g.raw)
    XCTAssert(i1.isEarley)
    XCTAssertFalse(i1.isCompletion)
    XCTAssertEqual(i1.prefix(in: g.raw), i0)
    XCTAssertNil(i0.lhs)
    XCTAssertEqual(g.symbolName[Int(i1.transitionSymbol!.id)], "C")

    let i2 = i1.advanced(in: g.raw)
    XCTAssert(i2.isEarley)
    XCTAssertFalse(i2.isCompletion)
    XCTAssertEqual(i2.prefix(in: g.raw), i1)
    XCTAssertNil(i0.lhs)
    XCTAssertEqual(g.symbolName[Int(i2.transitionSymbol!.id)], "D")

    let i3 = i2.advanced(in: g.raw)
    XCTAssert(i3.isEarley)
    XCTAssertFalse(i3.isCompletion)
    XCTAssertEqual(i3.prefix(in: g.raw), i2)
    XCTAssertNil(i0.lhs)
    XCTAssertEqual(g.symbolName[Int(i3.transitionSymbol!.id)], "E")

    let i4 = i3.advanced(in: g.raw)
    XCTAssert(i4.isEarley)
    XCTAssert(i4.isCompletion)
    XCTAssertEqual(i4.prefix(in: g.raw), i3)
    XCTAssertNil(i4.transitionSymbol)
    XCTAssertEqual(g.symbolName[Int(i4.lhs!.id)], "A")
  }
}
