import XCTest
import Lotsawa

extension TestForest {
  func checkUniqueDerivation(
    ofLHS expectedRule: String,
    over locus: Range<SourcePosition>,
    rhsOrigins expectedRHSOrigins: [SourcePosition],
    _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line
  ) throws {
    let d0 = derivations(of: String(expectedRule.split(separator: " ").first!), over: locus)
    let d = try d0.checkedOnlyElement(message() + "\n\(recognizer)", file: file, line: line)
    XCTAssertEqual(
      d.ruleName, expectedRule, "ruleName mismatch" + message() + "\n\(recognizer)",
      file: file, line: line)
    XCTAssertEqual(
      d.rhsOrigins, expectedRHSOrigins, "rhsOrigin mismatch" + message() + "\n\(recognizer)",
      file: file, line: line)
  }
}

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
    var r = TestRecognizer(g) //    01234567890
    let unrecognized = r.recognize("42+(9/3-20)")
    XCTAssertNil(unrecognized)

    let f = r.forest
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
    var r = TestRecognizer(g) //    01234567890
    let unrecognized = r.recognize("42+(9/3-20)")

    // This test somehow unchallenged by the Leo optimization.  Perhaps we need input like 1*2*3.
    XCTAssertNil(unrecognized, "\n\(r)")
    let f = r.forest
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

  func testRightRecursion() throws {
    let g = try """
      A ::= 'a' A | 'a'
      """
      .asTestGrammar(recognizing: "A")
    var r = TestRecognizer(g)

    XCTAssertNil(r.recognize("aaaaa"))

    let f = r.forest
    try f.checkUniqueDerivation(ofLHS: "A ::= 'a' A", over: 0..<5, rhsOrigins: [0, 1])
    try f.checkUniqueDerivation(ofLHS: "A ::= 'a' A", over: 1..<5, rhsOrigins: [1, 2])
    try f.checkUniqueDerivation(ofLHS: "A ::= 'a' A", over: 2..<5, rhsOrigins: [2, 3])
    try f.checkUniqueDerivation(ofLHS: "A ::= 'a' A", over: 3..<5, rhsOrigins: [3, 4])
    try f.checkUniqueDerivation(ofLHS: "A ::= 'a'", over: 4..<5, rhsOrigins: [4])
  }

  func testRightRecursion0() throws {
    let g = try """
      A ::= 'w' 'x' B | 'w'
      B ::= C
      C ::= 'y' 'z' A
      C ::= 'y' 'z' 'w' 'x' 'y' 'z' 'w'
      """
      .asTestGrammar(recognizing: "A")
    var r = TestRecognizer(g)
    
    XCTAssertNil(r.recognize("wxyzwxyzw"))
    
    print(r)
  }
  
    func testRightRecursion2() throws {
    let g = try """
      A ::= 'x' B | 'x'
      B ::= 'y' A
      """
      .asTestGrammar(recognizing: "A")
    var r = TestRecognizer(g)

    XCTAssertNil(r.recognize("xyxyxyx"))

    print(r)
    let f = r.forest
    try f.checkUniqueDerivation(ofLHS: "A ::= 'x' B", over: 0..<7, rhsOrigins: [0, 1])
    try f.checkUniqueDerivation(ofLHS: "B ::= 'y' A", over: 1..<7, rhsOrigins: [1, 2])
    try f.checkUniqueDerivation(ofLHS: "A ::= 'x' B", over: 2..<7, rhsOrigins: [2, 3])
    try f.checkUniqueDerivation(ofLHS: "B ::= 'y' A", over: 3..<7, rhsOrigins: [3, 4])
    try f.checkUniqueDerivation(ofLHS: "A ::= 'x' B", over: 4..<7, rhsOrigins: [4, 5])
    try f.checkUniqueDerivation(ofLHS: "B ::= 'y' A", over: 5..<7, rhsOrigins: [5, 6])
    try f.checkUniqueDerivation(ofLHS: "A ::= 'x'", over: 6..<7, rhsOrigins: [6])
  }

  func testRightRecursion3() throws {
    let g = try """
      A ::= 'x' B | 'x'
      B ::= C
      C ::= 'y' A
      """
      .asTestGrammar(recognizing: "A")
    var r = TestRecognizer(g)

    XCTAssertNil(r.recognize("xyxyxyx"))

    let f = r.forest
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

  /*
  func testEmptyRules() throws {
    let g = try """
      A ::= _ | B
      B ::= A
      """
      .asTestGrammar(recognizing: "A")
    var r = TestRecognizer(g)
    XCTAssertNil(r.recognize(""), "\n\(r)")
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
