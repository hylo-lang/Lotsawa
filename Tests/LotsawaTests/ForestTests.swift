import XCTest
import Lotsawa

class ForestTests: XCTestCase {
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
    var r = DebugRecognizer(g) //    01234567890
    let unrecognized = r.recognize("42+(9/3-20)")
    XCTAssertNil(unrecognized)

    var f = r.forest
    try f.checkUniqueDerivation(
      ofLHS: "sum ::= sum additive product", over: 0..<11, rhsOrigins: [0, 2, 3])

    try f.checkUniqueDerivation(ofLHS: "sum ::= product", over: 0..<2, rhsOrigins: [0])
    try f.checkUniqueDerivation(ofLHS: "product ::= factor", over: 0..<2, rhsOrigins: [0])
    try f.checkUniqueDerivation(ofLHS: "factor ::= number", over: 0..<2, rhsOrigins: [0])
    try f.checkUniqueDerivation(ofLHS: "number ::= number digit", over: 0..<2, rhsOrigins: [0, 1])

    try f.checkUniqueDerivation(ofLHS: "number ::= digit", over: 0..<1, rhsOrigins: [0])
    try f.checkUniqueDerivation(ofLHS: "digit ::= '4'", over: 0..<1, rhsOrigins: [0])

    try f.checkUniqueDerivation(ofLHS: "digit ::= '2'", over: 1..<2, rhsOrigins: [1])

    try f.checkUniqueDerivation(ofLHS: "additive ::= '+'", over: 2..<3, rhsOrigins: [2])

    try f.checkUniqueDerivation(ofLHS: "product ::= factor", over: 3..<11, rhsOrigins: [3])
    try f.checkUniqueDerivation(ofLHS: "factor ::= '(' sum ')'", over: 3..<11, rhsOrigins: [3, 4, 10])

    try f.checkUniqueDerivation(
      ofLHS: "sum ::= sum additive product", over: 4..<10, rhsOrigins: [4, 7, 8])

    try f.checkUniqueDerivation(ofLHS: "sum ::= product", over: 4..<7, rhsOrigins: [4])
    try f.checkUniqueDerivation(
      ofLHS: "product ::= product multiplicative factor", over: 4..<7, rhsOrigins: [4, 5, 6])

    try f.checkUniqueDerivation(ofLHS: "product ::= factor", over: 4..<5, rhsOrigins: [4])
    try f.checkUniqueDerivation(ofLHS: "factor ::= number", over: 4..<5, rhsOrigins: [4])
    try f.checkUniqueDerivation(ofLHS: "number ::= digit", over: 4..<5, rhsOrigins: [4])
    try f.checkUniqueDerivation(ofLHS: "digit ::= '9'", over: 4..<5, rhsOrigins: [4])

    try f.checkUniqueDerivation(ofLHS: "multiplicative ::= '/'", over: 5..<6, rhsOrigins: [5])

    try f.checkUniqueDerivation(ofLHS: "factor ::= number", over: 6..<7, rhsOrigins: [6])
    try f.checkUniqueDerivation(ofLHS: "number ::= digit", over: 6..<7, rhsOrigins: [6])
    try f.checkUniqueDerivation(ofLHS: "digit ::= '3'", over: 6..<7, rhsOrigins: [6])

    try f.checkUniqueDerivation(ofLHS: "additive ::= '-'", over: 7..<8, rhsOrigins: [7])

    try f.checkUniqueDerivation(ofLHS: "product ::= factor", over: 8..<10, rhsOrigins: [8])
    try f.checkUniqueDerivation(ofLHS: "factor ::= number", over: 8..<10, rhsOrigins: [8])
    try f.checkUniqueDerivation(ofLHS: "number ::= number digit", over: 8..<10, rhsOrigins: [8, 9])

    try f.checkUniqueDerivation(ofLHS: "number ::= digit", over: 8..<9, rhsOrigins: [8])
    try f.checkUniqueDerivation(ofLHS: "digit ::= '2'", over: 8..<9, rhsOrigins: [8])

    try f.checkUniqueDerivation(ofLHS: "digit ::= '0'", over: 9..<10, rhsOrigins: [9])
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
    var r = DebugRecognizer(g) //    01234567890
    let unrecognized = r.recognize("42+(9/3-20)")

    // This test somehow unchallenged by the Leo optimization.  Perhaps we need input like 1*2*3.
    XCTAssertNil(unrecognized, "\n\(r)")
    var f = r.forest
    try f.checkUniqueDerivation(
      ofLHS: "sum ::= product additive sum", over: 0..<11, rhsOrigins: [0, 2, 3])

    try f.checkUniqueDerivation(ofLHS: "product ::= factor", over: 0..<2, rhsOrigins: [0])
    try f.checkUniqueDerivation(ofLHS: "factor ::= number", over: 0..<2, rhsOrigins: [0])
    try f.checkUniqueDerivation(ofLHS: "number ::= digit number", over: 0..<2, rhsOrigins: [0, 1])

    try f.checkUniqueDerivation(ofLHS: "digit ::= '4'", over: 0..<1, rhsOrigins: [0])

    try f.checkUniqueDerivation(ofLHS: "number ::= digit", over: 1..<2, rhsOrigins: [1])
    try f.checkUniqueDerivation(ofLHS: "digit ::= '2'", over: 1..<2, rhsOrigins: [1])

    try f.checkUniqueDerivation(ofLHS: "additive ::= '+'", over: 2..<3, rhsOrigins: [2])

    try f.checkUniqueDerivation(ofLHS: "product ::= factor", over: 3..<11, rhsOrigins: [3])
    try f.checkUniqueDerivation(ofLHS: "factor ::= '(' sum ')'", over: 3..<11, rhsOrigins: [3, 4, 10])

    try f.checkUniqueDerivation(
      ofLHS: "sum ::= product additive sum", over: 4..<10, rhsOrigins: [4, 7, 8])

    try f.checkUniqueDerivation(
      ofLHS: "product ::= factor multiplicative product", over: 4..<7, rhsOrigins: [4, 5, 6])

    try f.checkUniqueDerivation(ofLHS: "factor ::= number", over: 4..<5, rhsOrigins: [4])
    try f.checkUniqueDerivation(ofLHS: "number ::= digit", over: 4..<5, rhsOrigins: [4])
    try f.checkUniqueDerivation(ofLHS: "digit ::= '9'", over: 4..<5, rhsOrigins: [4])

    try f.checkUniqueDerivation(ofLHS: "multiplicative ::= '/'", over: 5..<6, rhsOrigins: [5])

    try f.checkUniqueDerivation(ofLHS: "product ::= factor", over: 6..<7, rhsOrigins: [6])
    try f.checkUniqueDerivation(ofLHS: "factor ::= number", over: 6..<7, rhsOrigins: [6])
    try f.checkUniqueDerivation(ofLHS: "number ::= digit", over: 6..<7, rhsOrigins: [6])
    try f.checkUniqueDerivation(ofLHS: "digit ::= '3'", over: 6..<7, rhsOrigins: [6])

    try f.checkUniqueDerivation(ofLHS: "additive ::= '-'", over: 7..<8, rhsOrigins: [7])

    try f.checkUniqueDerivation(ofLHS: "sum ::= product", over: 8..<10, rhsOrigins: [8])
    try f.checkUniqueDerivation(ofLHS: "product ::= factor", over: 8..<10, rhsOrigins: [8])
    try f.checkUniqueDerivation(ofLHS: "factor ::= number", over: 8..<10, rhsOrigins: [8])
    try f.checkUniqueDerivation(ofLHS: "number ::= digit number", over: 8..<10, rhsOrigins: [8, 9])

    try f.checkUniqueDerivation(ofLHS: "digit ::= '2'", over: 8..<9, rhsOrigins: [8])

    try f.checkUniqueDerivation(ofLHS: "number ::= digit", over: 9..<10, rhsOrigins: [9])
    try f.checkUniqueDerivation(ofLHS: "digit ::= '0'", over: 9..<10, rhsOrigins: [9])
  }

  func testRightRecursion00() throws {
    let g = try """
      A ::= 'a' A | 'a'
      """
      .asTestGrammar(recognizing: "A")
    var r = DebugRecognizer(g)

    XCTAssertNil(r.recognize("aaaaa"))

    var f = r.forest
    try f.checkUniqueDerivation(ofLHS: "A ::= 'a' A", over: 0..<5, rhsOrigins: [0, 1])
    try f.checkUniqueDerivation(ofLHS: "A ::= 'a' A", over: 1..<5, rhsOrigins: [1, 2])
    try f.checkUniqueDerivation(ofLHS: "A ::= 'a' A", over: 2..<5, rhsOrigins: [2, 3])
    try f.checkUniqueDerivation(ofLHS: "A ::= 'a' A", over: 3..<5, rhsOrigins: [3, 4])
    try f.checkUniqueDerivation(ofLHS: "A ::= 'a'", over: 4..<5, rhsOrigins: [4])
  }

  func testRightRecursion10() throws {
    let g = try """
      A ::= 'w' 'x' B | 'w'
      B ::= C
      C ::= 'y' 'z' A
      """
      .asTestGrammar(recognizing: "A")
    var r = DebugRecognizer(g)

    XCTAssertNil(r.recognize("wxyzwxyzw"))

    var f = r.forest
    try f.checkUniqueDerivation(ofLHS: "A ::= 'w' 'x' B", over: 0..<9, rhsOrigins: [0, 1, 2])
    try f.checkUniqueDerivation(ofLHS: "B ::= C", over: 2..<9, rhsOrigins: [2])
    try f.checkUniqueDerivation(ofLHS: "C ::= 'y' 'z' A", over: 2..<9, rhsOrigins: [2, 3, 4])

    try f.checkUniqueDerivation(ofLHS: "A ::= 'w' 'x' B", over: 4..<9, rhsOrigins: [4, 5, 6])
    try f.checkUniqueDerivation(ofLHS: "B ::= C", over: 6..<9, rhsOrigins: [6])
    try f.checkUniqueDerivation(ofLHS: "C ::= 'y' 'z' A", over: 6..<9, rhsOrigins: [6, 7, 8])
    try f.checkUniqueDerivation(ofLHS: "A ::= 'w'", over: 8..<9, rhsOrigins: [8])
  }

  func testRightRecursion15() throws {
    let g = try """
      A ::= 'w' 'x' B | 'w'
      B ::= C
      C ::= 'y' 'z' A
      C ::= 'y' 'z' 'w' 'x' 'y' 'z' 'w'
      """
      .asTestGrammar(recognizing: "A")
    var r = DebugRecognizer(g)

    XCTAssertNil(r.recognize("wxyzwxyzw"))
    var f = r.forest
    try f.checkUniqueDerivation(ofLHS: "A ::= 'w' 'x' B", over: 0..<9, rhsOrigins: [0, 1, 2])
    try f.checkUniqueDerivation(ofLHS: "B ::= C", over: 2..<9, rhsOrigins: [2])
    let cDerivations = f.derivations(of: "C", over: 2..<9)
    XCTAssertEqual(cDerivations.count, 2)
    XCTAssert(
      cDerivations.contains { $0.ruleName ==  "C ::= 'y' 'z' A" && $0.rhsOrigins == [2, 3, 4] },
      "expected derivation not found in \(cDerivations)")
    XCTAssert(
      cDerivations.contains {
        $0.ruleName ==  "C ::= 'y' 'z' 'w' 'x' 'y' 'z' 'w'" && $0.rhsOrigins.elementsEqual(2...8) },
      "expected derivation not found in \(cDerivations)")

    try f.checkUniqueDerivation(ofLHS: "A ::= 'w' 'x' B", over: 4..<9, rhsOrigins: [4, 5, 6])
    try f.checkUniqueDerivation(ofLHS: "B ::= C", over: 6..<9, rhsOrigins: [6])
    try f.checkUniqueDerivation(ofLHS: "C ::= 'y' 'z' A", over: 6..<9, rhsOrigins: [6, 7, 8])
    try f.checkUniqueDerivation(ofLHS: "A ::= 'w'", over: 8..<9, rhsOrigins: [8])
  }

  func testRightRecursion20() throws {
    let g = try """
      A ::= 'w' 'x' B | 'w'
      B ::= 'y' 'z' 'w' 'x' 'y' 'z' 'w'
      B ::= 'y' 'z' A
      """
      .asTestGrammar(recognizing: "A")
    var r = DebugRecognizer(g)

    XCTAssertNil(r.recognize("wxyzwxyzw"))
    var f = r.forest
    try f.checkUniqueDerivation(ofLHS: "A ::= 'w' 'x' B", over: 0..<9, rhsOrigins: [0, 1, 2])
    let bDerivations = f.derivations(of: "B", over: 2..<9)
    XCTAssertEqual(bDerivations.count, 2)
    XCTAssert(
      bDerivations.contains { $0.ruleName ==  "B ::= 'y' 'z' A" && $0.rhsOrigins == [2, 3, 4] },
      "expected derivation not found in \(bDerivations)")
    XCTAssert(
      bDerivations.contains {
        $0.ruleName ==  "B ::= 'y' 'z' 'w' 'x' 'y' 'z' 'w'" && $0.rhsOrigins.elementsEqual(2...8) },
      "expected derivation not found in \(bDerivations)")

    try f.checkUniqueDerivation(ofLHS: "A ::= 'w' 'x' B", over: 4..<9, rhsOrigins: [4, 5, 6])
    try f.checkUniqueDerivation(ofLHS: "B ::= 'y' 'z' A", over: 6..<9, rhsOrigins: [6, 7, 8])
    try f.checkUniqueDerivation(ofLHS: "A ::= 'w'", over: 8..<9, rhsOrigins: [8])
  }

  func testRightRecursion30() throws {
    let g = try """
      A ::= 'x' B | 'x'
      B ::= 'y' A
      """
      .asTestGrammar(recognizing: "A")
    var r = DebugRecognizer(g)

    XCTAssertNil(r.recognize("xyxyxyx"))

    var f = r.forest
    try f.checkUniqueDerivation(ofLHS: "A ::= 'x' B", over: 0..<7, rhsOrigins: [0, 1])
    try f.checkUniqueDerivation(ofLHS: "B ::= 'y' A", over: 1..<7, rhsOrigins: [1, 2])
    try f.checkUniqueDerivation(ofLHS: "A ::= 'x' B", over: 2..<7, rhsOrigins: [2, 3])
    try f.checkUniqueDerivation(ofLHS: "B ::= 'y' A", over: 3..<7, rhsOrigins: [3, 4])
    try f.checkUniqueDerivation(ofLHS: "A ::= 'x' B", over: 4..<7, rhsOrigins: [4, 5])
    try f.checkUniqueDerivation(ofLHS: "B ::= 'y' A", over: 5..<7, rhsOrigins: [5, 6])
    try f.checkUniqueDerivation(ofLHS: "A ::= 'x'", over: 6..<7, rhsOrigins: [6])
  }

  func testRightRecursion40() throws {
    let g = try """
      A ::= 'x' B | 'x'
      B ::= C
      C ::= 'y' A
      """
      .asTestGrammar(recognizing: "A")
    var r = DebugRecognizer(g)

    XCTAssertNil(r.recognize("xyxyxyx"))
    var f = r.forest
    try f.checkUniqueDerivation(ofLHS: "A ::= 'x' B", over: 0..<7, rhsOrigins: [0, 1])
    try f.checkUniqueDerivation(ofLHS: "B ::= C", over: 1..<7, rhsOrigins: [1])
    try f.checkUniqueDerivation(ofLHS: "C ::= 'y' A", over: 1..<7, rhsOrigins: [1, 2])
    try f.checkUniqueDerivation(ofLHS: "A ::= 'x' B", over: 2..<7, rhsOrigins: [2, 3])
    try f.checkUniqueDerivation(ofLHS: "B ::= C", over: 3..<7, rhsOrigins: [3])
    try f.checkUniqueDerivation(ofLHS: "C ::= 'y' A", over: 3..<7, rhsOrigins: [3, 4])
    try f.checkUniqueDerivation(ofLHS: "A ::= 'x' B", over: 4..<7, rhsOrigins: [4, 5])
    try f.checkUniqueDerivation(ofLHS: "B ::= C", over: 5..<7, rhsOrigins: [5])
    try f.checkUniqueDerivation(ofLHS: "C ::= 'y' A", over: 5..<7, rhsOrigins: [5, 6])
    try f.checkUniqueDerivation(ofLHS: "A ::= 'x'", over: 6..<7, rhsOrigins: [6])
  }

  func testRawForestAmbiguity() throws {
    let g = try """
      B ::= B 'a' | 'a'
      X ::= B B B
      """
      .asTestGrammar(recognizing: "X")
    var r = DebugRecognizer(g)

    XCTAssertNil(r.recognize("aaaa"))
    var f = r.base.forest
    let d0 = f.derivations(of: g.symbols["X"]!, over: 0..<4)

    XCTAssertEqual(d0.map { g.symbolName[.init($0.lhs.id)] }, ["X", "X", "X"])
    XCTAssertEqual(
      d0.map { $0.rhs.map { g.symbolName[.init($0.id)] } },
      [["B", "B", "B"], ["B", "B", "B"], ["B", "B", "B"]])
    XCTAssertEqual(
      Set(d0.map(\.rhsOrigins).map(Array.init)),
      [[0, 1, 2], [0, 1, 3], [0, 2, 3]]
    )
  }

  func testAmbiguity() throws {
    let g = try """
      B ::= B 'a' | 'a'
      X ::= B B B
      """
      .asTestGrammar(recognizing: "X")
    var r = DebugRecognizer(g)

    XCTAssertNil(r.recognize("aaaa"))
    var f = r.forest
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
