@testable import Lotsawa
import XCTest

typealias TinyGrammar = Grammar<Int8>

class GrammarPreprocessingTests: XCTestCase {
  func testTrivialNullable() throws {
    let g = try """
      a ::= _ | a b | a c
      b ::= d 'foo'
      c ::= b
      """
      .asTestGrammar(recognizing: "a")
    let n = g.raw.nullSymbolSets()
    XCTAssert(n.nulling.isEmpty)
    XCTAssertEqual(g.text(n.nullable), ["a"])
  }

  func testTrivialNulling() throws {
    let g = try """
      a ::= _
      c ::= b
      """
      .asTestGrammar(recognizing: "a")
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
      .asTestGrammar(recognizing: "a")
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
      .asTestGrammar(recognizing: "a")
    let n = g.raw.nullSymbolSets()
    XCTAssertEqual(g.text(n.nullable), ["n0", "n1", "n2", "n3", "n4", "n5", "x0", "x1", "y"])
    XCTAssertEqual(g.text(n.nulling), ["n0", "n1", "n2", "n3", "n4", "n5"])
  }

  func testLeoPositions() throws {
    let g = try """
      a ::= b   // no recursion

      b ::= b c // simple left recursion

      c ::= d e // indirect left recursion
      d ::= c
      d ::= f
      f ::= c g

      b1 ::= c1 b1 // simple right recursion

      c1 ::= e1 d1 // indirect right recursion
      d1 ::= c1
      d1 ::= f1
      f1 ::= g1 c1
      """
      .asTestGrammar(recognizing: "a")

    let expectedPositions = Set(
      """
      b1 ::= c1•b1
      c1 ::= e1•d1
      d1 ::= •c1
      d1 ::= •f1
      f1 ::= g1•c1
      """
        .split(separator: "\n").map(String.init))

    XCTAssertEqual(Set(g.raw.leoPositions().map(g.dottedText)), expectedPositions)
  }

  #if false
  // Good for eyeballing generation results
  func testGenerator() {
    var g = TinyGrammar()
    g.addRule(lhs: 0, rhs: [1, 2])
    g.addRule(lhs: 1, rhs: [])
    g.addRule(lhs: 1, rhs: [1, 3])
    g.addRule(lhs: 2, rhs: [4])
    g.addRule(lhs: 2, rhs: [4, 2])
    g.generateParses(Symbol(0), maxDepth: 6) { p in
      print(p.lazy.map(String.init(describing:)).joined(separator: " "))
    }
  }
  #endif

  func testDenullification_slow() {

    // Exhaustively test all 3^8 combinations of grammars containing S -> RHS where RHS has 0-8
    // symbols and each symbol of RHS is a unique symbol that is either nulling, nullable, or
    // non-nullable.
    let maxRHSCount: Symbol.ID = 8
    for n in 0...maxRHSCount {
      var base = TinyGrammar(recognizing: Symbol(0))
      let rhs = (1..<n+1).lazy.map(Symbol.init(id:))

      base.addRule(lhs: Symbol(0), rhs: rhs)
      let combinations = repeatElement(3, count: Int(n)).reduce(1, *)
      for combo in 0..<combinations {
        var raw = base
        var c = combo

        for s in rhs {
          defer { c /= 3 }
          if c % 3 == 0 { continue } // non-nullable
          else if c % 3 == 1 { raw.addRule(lhs: s, rhs: CollectionOfOne(Symbol(s.id + n))) }
          raw.addRule(lhs: s, rhs: EmptyCollection())
        }

        var (cooked, rawPosition, isNullable) = raw.eliminatingNulls()

        // Make sure we have a position for the start symbol.
        rawPosition.appendMapping(from: cooked.size, to: raw.size)

        let terminals = raw.symbols().terminals
        XCTAssertEqual(cooked.symbols().terminals, terminals)

        let cookedNulls = cooked.nullSymbolSets()
        XCTAssert(cookedNulls.nulling.isEmpty)
        XCTAssert(cookedNulls.nullable.isEmpty)

        // Generate all raw parses into rawParses, removing any empty nonterminals and any entirely
        // empty parses.
        var rawParses = Set<TinyGrammar.Parse>()
        var foundEmpty = false
        raw.generateParses(Symbol(0)) { p in
          let p1 = p.eliminatingNulls()
          if p1.moves.isEmpty {
            foundEmpty = true
          }
          else {
            let x = rawParses.insert(p1)
            XCTAssert(x.inserted, "\(p1) generated twice")
          }
        }
        XCTAssertEqual(foundEmpty, isNullable)

        // Generate all cooked parses into cookedParses, eliminating any synthesized nonterminals
        // and transforming positions back into their raw equivalents.
        var cookedParses = Set<TinyGrammar.Parse>()
        cooked.generateParses(Symbol(0)) { p in
          XCTAssert(
            cookedParses.insert(
              p.eliminatingSymbols(
                greaterThan: Symbol(raw.maxSymbolID), mappingPositionsThrough: rawPosition)
            ).inserted, "\(p) generated twice; duplicate rule in rewrite?")
        }

        XCTAssertEqual(
          rawParses, cookedParses,
          "\nraw: \(raw)\ncooked: \(cooked)\n"
            + "map: \(rawPosition.points): \((0..<cooked.size).map {rawPosition[$0]})")
      }
    }
  }
}
