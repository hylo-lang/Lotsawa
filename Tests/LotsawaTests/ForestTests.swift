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

  func testRawForestAmbiguity() throws {
    let g = try """
      B ::= B 'a' | 'a'
      X ::= B B B
      """
      .asTestGrammar(recognizing: "X")
    var r = TestRecognizer(g)

    XCTAssertNil(r.recognize("aaaa"))
    let f = r.base.forest
    var d0 = f.derivations(of: g.symbols["X"]!, over: 0..<4)
    var d1: [Forest<Symbol.ID>.Derivation] = []

    while !d0.isEmpty {
      d1.append(f.first(of: d0))
      f.removeFirst(from: &d0)
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

  func testAmbiguity() throws {
    let g = try """
      B ::= B 'a' | 'a'
      X ::= B B B
      """
      .asTestGrammar(recognizing: "X")
    var r = TestRecognizer(g)

    XCTAssertNil(r.recognize("aaaa"))
    let f = r.forest
    let xs = f.derivations(of: "X", over: 0..<4)
    XCTAssert(xs.map(\.ruleName).allSatisfy { $0 == "X ::= B B B" })
    XCTAssertEqual(Set(xs.lazy.map(\.rhsOrigins)), [[0, 1, 2], [0, 1, 3], [0, 2, 3]])

    let b01 = f.derivations(of: "B", over: 0..<1)
    XCTAssertEqual(b01.count, 1)
    XCTAssertEqual(b01.first!.ruleName, "B ::= 'a'")
    XCTAssertEqual(b01.first!.rhsOrigins, [0])

    let b12 = f.derivations(of: "B", over: 1..<2)
    XCTAssertEqual(b12.count, 1)
    XCTAssertEqual(b12.first!.ruleName, "B ::= 'a'")
    XCTAssertEqual(b12.first!.rhsOrigins, [1])

    let b23 = f.derivations(of: "B", over: 2..<3)
    XCTAssertEqual(b23.count, 1)
    XCTAssertEqual(b23.first!.ruleName, "B ::= 'a'")
    XCTAssertEqual(b23.first!.rhsOrigins, [2])

    let b02 = f.derivations(of: "B", over: 0..<2)
    XCTAssertEqual(b02.count, 1)
    XCTAssertEqual(b02.first!.ruleName, "B ::= B 'a'")
    XCTAssertEqual(b02.first!.rhsOrigins, [0, 1])

    let b13 = f.derivations(of: "B", over: 1..<3)
    XCTAssertEqual(b13.count, 1)
    XCTAssertEqual(b13.first!.ruleName, "B ::= B 'a'")
    XCTAssertEqual(b13.first!.rhsOrigins, [1, 2])

    XCTAssert(f.derivations(of: "'a'", over: 0..<1).isEmpty)
    XCTAssert(f.derivations(of: "X", over: 0..<1).isEmpty)
  }
}
