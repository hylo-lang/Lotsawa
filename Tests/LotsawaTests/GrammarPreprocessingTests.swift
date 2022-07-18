@testable import Lotsawa

import XCTest

struct TinyConfig: GrammarConfig {
  typealias Symbol = Int8
  typealias Size = UInt8
}
typealias TinyGrammar = Grammar<TinyConfig>

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

  func testDenullification() {
    // Strategy:
    //
    // Create simple finite grammar S -> 𝛂
    // Where 𝛂 is any string of
    // - a new nulling symbol
    // - a new nullable symbol
    // - a new non-nullable symbol

    // denullify
    // explore the grammars in parallel.

    let maxRHSCount: TinyGrammar.Symbol = 8
    for n in 0...maxRHSCount {
      var base = TinyGrammar()
      let rhs = 1..<n+1
      base.addRule(lhs: 0, rhs: rhs)
      let combinations = repeatElement(3, count: Int(n)).reduce(1, *)
      for combo in 0..<combinations {
        var raw = base
        var c = combo
        for s in rhs {
          defer { c /= 3 }
          if c % 3 == 0 { continue } // non-nullable
          else if c % 3 == 1 { raw.addRule(lhs: s, rhs: CollectionOfOne(s + n)) }
          raw.addRule(lhs: s, rhs: EmptyCollection())
        }

        let (cooked, mapBack) = raw.eliminatingNulls()
        let terminals = raw.symbols().terminals
        XCTAssertEqual(cooked.symbols().terminals, terminals)

        let cookedNulls = cooked.nullSymbolSets()
        XCTAssert(cookedNulls.nulling.isEmpty)
        XCTAssert(cookedNulls.nullable.isEmpty)

        // Validate mapBack, somewhat.
        for r in cooked.rules {
          for i in r.rhs.indices {
            let s = r.rhs[i]
            if s <= raw.maxSymbol {
              XCTAssertEqual(s, raw.postdot(at: mapBack[TinyGrammar.Size(i)]))
            }
          }
        }

        // TODO: Actually test for grammar equivalence.  Can't figure that out right now. Until
        // then, the following code helps you eyeball it.
        #if false
        print("-----------------------------")
        let n = raw.nullSymbolSets()
        print(
          "raw: 0 ::= ",
          rhs.lazy.map { s in
            n.nulling.contains(s) ? "(\(s))"
              : n.nullable.contains(s) ? "\(s)?"
              : "\(s)"
              }.joined(separator: " "))

        print("cooked:\(n.nullable.contains(0) ? " 𝛆 |" : "")", cooked)
        #endif
      }
    }
  }
}

extension Grammar: CustomStringConvertible {
  /// Returns the human-readable name for `s`.
  func text(_ s: Symbol) -> String { String(s) }

  /// Returns a human-readable representation of `r`.
  func rhsText(_ r: Rule) -> String {
    r.rhs.isEmpty ? "𝛆" : r.rhs.lazy.map { s in text(s) }.joined(separator: " ")
  }

  /// Returns a human-readable representation of `self`.
  public var description: String {
    let sortedRules = MultiMap(grouping: rules, by: \.lhs).storage
      .sorted(by: { a,b in a.key < b.key })

    return sortedRules.lazy.map { (lhs, alternatives) in
      "\(lhs) ::= " + alternatives.lazy.map(rhsText).joined(separator: " | ")
    }.joined(separator: "; ")
  }
}
