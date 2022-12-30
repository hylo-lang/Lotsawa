@testable import Lotsawa
import XCTest

struct UnexpectedlyEmpty: Error {}

class ChartInternalTests: XCTestCase {
  func testItemOperations() throws {
    let g = try """
      A ::= B C D E
      """
      .asTestGrammar(recognizing: "A")

    let i0 = Chart.ItemID(predicting: g.raw.ruleIDs.first!, in: g.raw, at: 42)
    XCTAssert(i0.isEarley)
    XCTAssertFalse(i0.isLeo)
    XCTAssertEqual(i0.origin, 42)
    XCTAssertFalse(i0.isCompletion)
    XCTAssertNil(i0.lhs)
    XCTAssertEqual(g.symbolName[Int(i0.transitionSymbol!.id)], "B")

    let i1 = i0.advanced(in: g.raw)
    XCTAssertEqual(i1.dotPosition, i0.dotPosition + 1)
    XCTAssert(i1.isEarley)
    XCTAssertFalse(i1.isLeo)
    XCTAssertEqual(i1.origin, 42)
    XCTAssertFalse(i1.isCompletion)
    XCTAssertEqual(i1.mainstem(in: g.raw), i0)
    XCTAssertNil(i0.lhs)
    XCTAssertEqual(g.symbolName[Int(i1.transitionSymbol!.id)], "C")

    let i2 = i1.advanced(in: g.raw)
    XCTAssertEqual(i2.dotPosition, i1.dotPosition + 1)
    XCTAssert(i2.isEarley)
    XCTAssertFalse(i2.isLeo)
    XCTAssertEqual(i2.origin, 42)
    XCTAssertFalse(i2.isCompletion)
    XCTAssertEqual(i2.mainstem(in: g.raw), i1)
    XCTAssertNil(i0.lhs)
    XCTAssertEqual(g.symbolName[Int(i2.transitionSymbol!.id)], "D")

    let i3 = i2.advanced(in: g.raw)
    XCTAssertEqual(i3.dotPosition, i2.dotPosition + 1)
    XCTAssert(i3.isEarley)
    XCTAssertFalse(i3.isLeo)
    XCTAssertEqual(i3.origin, 42)
    XCTAssertFalse(i3.isCompletion)
    XCTAssertEqual(i3.mainstem(in: g.raw), i2)
    XCTAssertNil(i0.lhs)
    XCTAssertEqual(g.symbolName[Int(i3.transitionSymbol!.id)], "E")

    let i4 = i3.advanced(in: g.raw)
    XCTAssertEqual(i4.dotPosition, i3.dotPosition + 1)
    XCTAssert(i4.isEarley)
    XCTAssertFalse(i4.isLeo)
    XCTAssertEqual(i4.origin, 42)
    XCTAssert(i4.isCompletion)
    XCTAssertEqual(i4.mainstem(in: g.raw), i3)
    XCTAssertNil(i4.transitionSymbol)
    XCTAssertEqual(g.symbolName[Int(i4.lhs!.id)], "A")

    // TODO: test init(memoizing:transitionSymbol:)
    // TODO: test key
    // TODO: test transitionKey
    //   transitionKey(_:)
    //   completionKey(_:, origin:)
    //   <
    //   ==
    //   isLeo
    //   leoMemo
  }

  func testUnambiguousLeftDerivation() throws {
    let g = try """
      sum ::= sum additive product | product
      product ::= product multiplicative factor | factor
      factor ::= '(' sum ')' | number
      number ::= number digit | digit
      digit ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
      additive ::= '+' | '-'
      multiplicative ::= '*' | '/'
      """
      .asTestGrammar(recognizing: "sum")
    var r = DebugRecognizer(g)
    let unrecognized = r.recognize("1+2")
    XCTAssertNil(unrecognized, "\n\(r)")

    let sum = g.symbols["sum"]!
    let product = g.symbols["product"]!
    let number = g.symbols["number"]!
    let digit = g.symbols["digit"]!
    let additive = g.symbols["additive"]!
    let multiplicative = g.symbols["multiplicative"]!

    let chart = r.base.chart
    let top3 = try chart.completions(of: sum, over: 0..<3).checkedOnlyElement()
    XCTAssert(top3.isCompletion)
    let topRuleID = g.raw.rule(containing: top3.dotPosition)
    let topRule = g.raw.storedRule(topRuleID)
    XCTAssertEqual(topRule.lhs, sum)
    XCTAssertEqual(Array(topRule.rhs), [sum, additive, product])

    let mainstem = try chart.mainstemIndices(of: top3.item, inEarleySet: 3).checkedOnlyElement()
    XCTAssertEqual(chart.earleme(ofEntryIndex: mainstem), 2)

    let rhsProduct = try chart.completions(of: product, over: 2..<3)
      .checkedOnlyElement()
    XCTAssert(rhsProduct.isCompletion)

    let top2 = try chart.earleyMainstem(of: top3).checkedOnlyElement()
    XCTAssertEqual(g.raw.rule(containing: top2.dotPosition), topRuleID)

    XCTAssertEqual(top2.transitionSymbol, product)

    let top1 = try chart.earleyMainstem(of: top2).checkedOnlyElement()

    XCTAssertEqual(g.raw.rule(containing: top1.dotPosition), topRuleID)

    let top0 = try chart.earleyMainstem(of: top1).checkedOnlyElement()

    XCTAssertEqual(g.raw.rule(containing: top0.dotPosition), topRuleID)

    // Could explore more, but it's time to create a better abstraction.

    // suppress "unused" warnings.
    _ = (number, digit, multiplicative)
  }
}
