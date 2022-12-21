@testable import Lotsawa

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

    generateNonterminal(start, at: size) { receiver(parse) }

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

    func generateString(_ s: Grammar.Rule.RHS, then onward: ()->()) {
      if s.isEmpty { return onward() }
      let depthMark = depth
      generateSymbol(at: GrammarSize(s.startIndex)) {
        depth = depthMark // Return to same depth between symbols of a string.
        generateString(s.dropFirst(), then: onward)
      }
    }
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

  var symbol: Symbol {
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
    greaterThan maxSymbol: Symbol,
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
