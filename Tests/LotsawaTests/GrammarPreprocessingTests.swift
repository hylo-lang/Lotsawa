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
      b1 ::= c1.b1
      c1 ::= e1.d1
      d1 ::= .c1
      d1 ::= .f1
      f1 ::= g1.c1
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
    g.generateParses(0, maxDepth: 6) { p in
      print(p.lazy.map(String.init(describing:)).joined(separator: " "))
    }
  }
  #endif

  func testDenullification() {

    // Exhaustively test all 3^8 combinations of grammars containing S -> RHS
    // where RHS has 0-8 symbols and each symbol of RHS is a unique symbol that is either nulling, nullable, or non-nullable.
    let maxRHSCount: TinyGrammar.Symbol = 8
    for n in 0...maxRHSCount {
      var base = TinyGrammar(recognizing: 0)
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

        var (cooked, rawPosition, isNullable) = raw.eliminatingNulls()

        // Make sure we have a position for the start symbol.
        rawPosition.appendMapping(from: .init(cooked.size), to: .init(raw.size))

        let terminals = raw.symbols().terminals
        XCTAssertEqual(cooked.symbols().terminals, terminals)

        let cookedNulls = cooked.nullSymbolSets()
        XCTAssert(cookedNulls.nulling.isEmpty)
        XCTAssert(cookedNulls.nullable.isEmpty)

        // Generate all raw parses into rawParses, removing any empty nonterminals and any entirely
        // empty parses.
        var rawParses = Set<TinyGrammar.Parse>()
        raw.generateParses(0) { p in
          let p1 = p.eliminatingNulls()
          if !p1.moves.isEmpty {
            let x = rawParses.insert(p1)
            XCTAssert(x.inserted, "\(p1) generated twice")
          }
        }

        // Generate all cooked parses into cookedParses, eliminating any synthesized nonterminals
        // and transforming positions back into their raw equivalents.
        var cookedParses = Set<TinyGrammar.Parse>()
        cooked.generateParses(0) { p in
          XCTAssert(
            cookedParses.insert(
              p.eliminatingSymbols(greaterThan: raw.maxSymbol, mappingPositionsThrough: rawPosition)
            ).inserted, "\(p) generated twice; duplicate rule in rewrite?")
        }

        XCTAssertEqual(
          rawParses, cookedParses,
          "\nraw: \(raw)\ncooked: \(cooked)\n"
            + "map: \(rawPosition.points): \((0..<cooked.size).map {rawPosition[.init($0)]})")
      }
    }
  }
}

extension Grammar: CustomStringConvertible {
  /// Returns the human-readable name for `s`.
  func text(_ s: Symbol) -> String { String(s) }

  /// Returns a human-readable representation of `r`.
  func rhsText(_ r: Rule) -> String {
    r.rhs.isEmpty ? "𝛆" : r.rhs.indices.lazy.map {
      i in text(r.rhs[i]) + i.subscriptingDigits()
    }.joined(separator: " ")
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

/// Parse generation.
///
/// This functionality is itself only tested by eyeball, which explains why it's not public.
extension Grammar {
  /// An element of a linear parse representation, including where in the grammar each recognized
  /// symbol occurs.
  enum ParseMove: Hashable, CustomStringConvertible {
    /// A terminal symbol `s` recognized at the given position.
    case terminal(_ s: Symbol, at: Position)
    /// The start of a nonterminal symbol `s` recognized at the given position.
    case begin(Symbol, at: Position)
    /// The end of the nonterminal symbol `s` last begun but not yet ended.
    case end(Symbol)
  }

  /// A representation of a parse tree.
  struct Parse: Hashable {
    var moves: [ParseMove] = []
  }

  /// Generates all complete parses of `start` having `maxLength` or fewer terminals and `maxDepth`
  /// or fewer levels of nesting, passing each one in turn to `receiver`.
  func generateParses(
    _ start: Symbol, maxLength: Int = Int.max, maxDepth: Int = Int.max, into receiver: (Parse)->()
  ) {
    let rulesByLHS = MultiMap(grouping: rules, by: \.lhs)
    var parse = Parse()
    var length = 0
    var depth = 0

    generateNonterminal(start, at: .init(size)) { receiver(parse) }

    func generateTerminal(_ s: Symbol, at p: Position, then onward: ()->()) {
      if length == maxLength { return }
      length += 1
      parse.moves.append(.terminal(s, at: p))
      onward()
    }

    func generateNonterminal(_ s: Symbol, at p: Position, then onward: ()->()) {
      if depth == maxDepth { return }
      depth += 1
      parse.moves.append(.begin(s, at: p))
      let mark = (length: length, depth: depth, parseCount: parse.moves.count)
      for r in rulesByLHS[s] {
        generateString(r.rhs) { parse.moves.append(.end(s)); onward() }
        parse.moves.removeSubrange(mark.parseCount...)
        (length, depth) = (mark.length, mark.depth)
      }
    }

    func generateSymbol(at p: Position, then onward: ()->()) {
      let s = postdot(at: p)!
      if rulesByLHS.storage[s] != nil {
        generateNonterminal(s, at: p, then: onward)
      }
      else {
        generateTerminal(s, at: p, then: onward)
      }
    }

    func generateString(_ s: Array<Symbol>.SubSequence, then onward: ()->()) {
      if s.isEmpty { return onward() }
      let depthMark = depth
      generateSymbol(at: .init(s.startIndex)) {
        depth = depthMark // Return to same depth between symbols of a string.
        generateString(s.dropFirst(), then: onward)
      }
    }
  }
}

extension BinaryInteger {
  /// Returns a string representation where all digits are subscript numerals
  func subscriptingDigits() -> String {
    return String(
      "\(self)".lazy.map { c in
        if c.unicodeScalars.count != 1 { return c }
        let u = c.unicodeScalars.first!
        if u < "0" || u > "9" { return c }
        return Character(
          Unicode.Scalar(
            u.value - ("0" as UnicodeScalar).value + ("₀" as UnicodeScalar).value)!)
      })
  }
}

extension Grammar.ParseMove {
  var description: String {
    switch self {
    case let .terminal(s, at: p): return "\(s)\(p.subscriptingDigits())"
    case let .begin(s, at: p): return "\(s)\(p.subscriptingDigits())("
    case .end: return ")"
    }
  }

  var symbol: Grammar.Symbol {
    switch self {
    case let .terminal(s, _): return s
    case let .begin(s, _): return s
    case let .end(s): return s
    }
  }
}

extension Grammar.Parse {
  func eliminatingNulls() -> Self {
    var r = Grammar.Parse()
    r.moves.reserveCapacity(moves.count)
    for m in moves {
      switch m {
      case .end:
        if m.symbol == r.moves.last!.symbol { _ = r.moves.popLast() }
        else { r.moves.append(m) }
      default:
        r.moves.append(m)
      }
    }
    return r
  }

  func eliminatingSymbols(
    greaterThan maxSymbol: Grammar.Symbol,
    mappingPositionsThrough positionMap: DiscreteMap<Grammar.Position, Grammar.Position>
  ) -> Self {
    var r = Grammar.Parse()
    r.moves.reserveCapacity(moves.count)
    for m in moves where m.symbol <= maxSymbol {
      switch m {
      case let .terminal(s, at: p): r.moves.append(.terminal(s, at: positionMap[p]))
      case let .begin(s, at: p): r.moves.append(.begin(s, at: positionMap[p]))
      case .end: r.moves.append(m)
      }
    }
    return r
  }
}
