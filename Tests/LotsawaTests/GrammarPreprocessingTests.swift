@testable import Lotsawa

import XCTest


class GrammarPreprocessingTests: XCTestCase {
  func testTrivialNullable() throws {
    let g = try """
      a ::= _ | a b | a c
      b ::= d 'foo'
      c ::= b
      """
      .asTestGrammar()
    let n = g.raw.nullSymbolSets()
    XCTAssert(n.nulling.isEmpty)
    XCTAssertEqual(g.text(n.nullable), ["a"])
  }

  func testTrivialNulling() throws {
    let g = try """
      a ::= _
      c ::= b
      """
      .asTestGrammar()
    let n = g.raw.nullSymbolSets()
    XCTAssertEqual(g.text(n.nulling), ["a"])
    XCTAssertEqual(g.text(n.nullable), ["a"])
  }

  func testTransitiveNullable() throws {
    let g = try """
      a ::= a b | a c
      n0 ::= n1 n2 | a
      n1 ::= n2 n2 n3 n3  | a a
      n2 ::= n3 n3 n3 n4 n4 n4 n4 | a a a
      n3 ::= n4 n5 | a
      n4 ::= n5 | a
      n5 ::= _ | 'foo'
      b ::= d 'foo'
      c ::= b
      """
      .asTestGrammar()
    let n = g.raw.nullSymbolSets()
    XCTAssert(n.nulling.isEmpty)
    XCTAssertEqual(g.text(n.nullable), ["n0", "n1", "n2", "n3", "n4", "n5"])
  }

  func testTransitiveNulling() throws {
    let g = try """
      a ::= a b | a c
      n0 ::= n1 n2 | n2 n3
      n1 ::= n2 n3 n2 n3 | n3 n4
      x0 ::= n2 n3 y n2 n3 | n3 n4
      x1 ::= n2 n3 n2 n3 | n3 y n4
      n2 ::= n3 n4 | n5
      n3 ::= n4 n5 | _
      n4 ::= n5
      n5 ::= _
      y ::= z | _ | a
      """
      .asTestGrammar()
    let n = g.raw.nullSymbolSets()
    XCTAssertEqual(g.text(n.nullable), ["n0", "n1", "n2", "n3", "n4", "n5", "x0", "x1", "y"])
    XCTAssertEqual(g.text(n.nulling), ["n0", "n1", "n2", "n3", "n4", "n5"])
  }
}
