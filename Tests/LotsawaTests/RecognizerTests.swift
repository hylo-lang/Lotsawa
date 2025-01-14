import Lotsawa
import TestResources

import XCTest

class RecognizerTests: XCTestCase {
  func testLeftRecursiveArithmetic() throws {
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
    let unrecognized = r.recognize("42+(9/3-20)")

    XCTAssertNil(unrecognized, "\n\(r)")
  }

  func testRightRecursiveArithmetic() throws {
    let g = try """
      sum ::= product additive sum | product
      product ::= factor multiplicative product  | factor
      factor ::= '(' sum ')' | number
      number ::= digit number | digit
      digit ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
      additive ::= '+' | '-'
      multiplicative ::= '*' | '/'
      """
      .asTestGrammar(recognizing: "sum")
    var r = DebugRecognizer(g)
    let unrecognized = r.recognize("42+(9/3-20)")

    XCTAssertNil(unrecognized, "\n\(r)")
  }

  func testEmptyRules() throws {
    let g = try """
      A ::= _ | B
      B ::= A
      """
      .asTestGrammar(recognizing: "A")
    var r = DebugRecognizer(g)
    XCTAssertNil(r.recognize(""), "\n\(r)")
  }

  func testRightRecursion() throws {
    let g = try """
      A ::= 'a' A | _
      """
      .asTestGrammar(recognizing: "A")
    var r = DebugRecognizer(g)

    XCTAssertNil(r.recognize("aaaaaaa"))
    let expectedSetSize = r.base.chart.earleySet(2).count
    XCTAssert(
      (3..<7).allSatisfy { r.base.chart.earleySet($0).count == expectedSetSize },
      "Leo optimization failure\n\(r)"
    )

    XCTAssertNil(r.recognize(""), "\n\(r)")
  }

  func testRightRecursion2() throws {
    let g = try """
      A ::= 'a' A | 'a'
      """
      .asTestGrammar(recognizing: "A")
    var r = DebugRecognizer(g)

    XCTAssertNil(r.recognize("aaaaaa"))
    let expectedSetSize = r.base.chart.earleySet(2).count
    XCTAssert(
      (3..<7).allSatisfy { r.base.chart.earleySet($0).count == expectedSetSize },
      "Leo optimization failure\n\(r)"
    )

    XCTAssertNil(r.recognize("a"))
    XCTAssertNotNil(r.recognize(""), "\n\(r)")
  }

  func testAmbiguity() throws {
    let g = try """
      B ::= B 'a' | 'a'
      X ::= B B B
      """
      .asTestGrammar(recognizing: "X")
    var r = DebugRecognizer(g)

    XCTAssertNil(r.recognize("aaaa"))
  }

  func testAnsiC() throws {
    let g = TestResources.ansiCGrammar
    var r = DebugRecognizer(g)
    XCTAssert(r.base.finishEarleme(), "Couldn't finish initial earleme")

    var completedParseDiscovered = false
    for (i, c) in ansiCTokens.prefix(1000).enumerated() {
      r.base.discover(c, startingAt: .init(i))
      XCTAssert(r.base.finishEarleme(), "No progress in earleme \(i)")

      if completedParseDiscovered || r.base.hasCompleteParse() {
        completedParseDiscovered = true
      }
    }

    XCTAssert(completedParseDiscovered, "Input not recognized.")
  }
}
