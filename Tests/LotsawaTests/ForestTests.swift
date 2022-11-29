import XCTest
@testable import Lotsawa

class ForestTests: XCTestCase {
  /*
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
    var r = TestRecognizer(g)
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
    var r = TestRecognizer(g)
    let unrecognized = r.recognize("42+(9/3-20)")

    XCTAssertNil(unrecognized, "\n\(r)")

    // Intended parse tree:
    //
    // (sum
    //
    //  (sum
    //   (product
    //    (factor
    //     (number
    //      (digit "4")
    //      (number (digit "2"))))))
    //
    //  (additive "+")
    //
    //  (product
    //
    //   (factor
    //    "("
    //
    //    (sum
    //
    //     (sum
    //      (product
    //       (product (factor (number (digit "9"))) )
    //       (multiplicative "/")
    //       (factor (number (digit "3")))))
    //
    //     (additive "-")
    //
    //     (product
    //      (factor
    //       (number
    //        (digit "2")
    //        (number (digit "0")))))
    //
    //     ")"
    //     ))))
  }

  func testEmptyRules() throws {
    let g = try """
      A ::= _ | B
      B ::= A
      """
      .asTestGrammar(recognizing: "A")
    var r = TestRecognizer(g)
    XCTAssertNil(r.recognize(""), "\n\(r)")
  }

  func testRightRecursion() throws {
    let g = try """
      A ::= 'a' A | _
      """
      .asTestGrammar(recognizing: "A")
    var r = TestRecognizer(g)

    XCTAssertNil(r.recognize("aaaaaaa"))
    XCTAssertNil(r.recognize(""), "\n\(r)")
  }

  func testRightRecursion2() throws {
    let g = try """
      A ::= 'a' A | 'a'
      """
      .asTestGrammar(recognizing: "A")
    var r = TestRecognizer(g)

    XCTAssertNil(r.recognize("aaaaaa"))
    XCTAssertNil(r.recognize("a"))
    XCTAssertNotNil(r.recognize(""), "\n\(r)")
  }
   */

  func testAmbiguity() throws {
    let g = try """
      B ::= B 'a' | 'a'
      X ::= B B B
      """
      .asTestGrammar(recognizing: "X")
    var r = TestRecognizer(g)

    XCTAssertNil(r.recognize("aaaa"))
    let f = r.base.forest
    var d0 = f.derivations(g.symbols["X"]!, over: 0..<4)
    var d1: [Forest<Symbol.ID>.Derivation] = []

    while !d0.isEmpty {
      d1.append(f.first(d0))
      f.removeFirst(&d0)
    }
    XCTAssertEqual(d1.map { g.symbolName[Int($0.lhs.id)] }, ["X", "X", "X"])
    XCTAssertEqual(
      d1.map { $0.rhs.map { g.symbolName[Int($0.id)] } },
      [["B", "B", "B"], ["B", "B", "B"], ["B", "B", "B"]])
    XCTAssertEqual(
      Set(d1.map(\.rhsOrigins).map(Array.init)),
      [[0, 1, 2], [0, 1, 3], [0, 2, 3]]
    )
  }
}
