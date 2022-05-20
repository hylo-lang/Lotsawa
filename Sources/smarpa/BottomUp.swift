/// A simple bottom-up chart parser.
///
/// - The chart is a lookup table of sets of partial parses (a.k.a. dotted
///   rules), indexed by (predicted-symbol, source-location) pairs.
///
/// - A partial parse is a triple (B, R, N) where:
///   - B is the position in the token stream where the partially-parsed input begins.
///   - R is the partially-recognized BNF rule.
///   - N is the number of RHS symbols of R that have been recognized.
///
/// - A chart location L is described by a pair (S, E) where, for all partial
///   parses P = (B, R, N) at L
///   - E is the position in the token stream where the input corresponding to P ends.
///   - The Nth RHS symbol of R is S
///
public struct BottomUpChartParser {
  /// Terminals and nonterminals are identified by a symbol ID.
  public typealias SymbolID = Int

  /// The symbols of all rules, stored end-to-end.
  typealias RuleStore = [SymbolID]

  /// The RHS symbols of a parse rule followed by the rule's LHS symbol.
  typealias Rule = RuleStore.SubSequence

  /// A range of positions in `ruleStore` denoting a suffix of a rule's RHS.
  typealias RuleTail = Range<RuleStore.Index>

  /// A position in the input.
  typealias SourcePosition = Int

  /// A range of positions in the input.
  typealias SourceRegion = Range<SourcePosition>

  /// A location in the parse chart.
  struct ChartLocation: Hashable {
    let expecting: SymbolID
    let at: SourcePosition
  }

  /// A parse rule being matched.
  struct PartialParse {
    /// The positions in ruleStore of yet-to-be recognized RHS symbols.
    var expected: Range<RuleStore.Index>

    /// The position in the token stream where the partially-parsed input begins.
    var start: SourcePosition

    /// True iff the entire RHS has been recognized.
    var isComplete: Bool { expected.isEmpty }
  }

  /// Storage for all the rules.
  var ruleStore: RuleStore = []

  /// Rule right-hand-sides indexed by their first RHS symbol.
  var rulesByRHSStart: [SymbolID: [RuleTail]] = [:]

  /// All the partial parses so far.
  var chart: [ChartLocation: [PartialParse]] = [:]
}

/// Initialization and algorithm.
extension BottomUpChartParser {
  /// Creates a parser for the given grammar.
  public init<Grammar: Collection, RHS: Collection>(_ grammar: Grammar)
    where Grammar.Element == (lhs: SymbolID, rhs: RHS),
          RHS.Element == SymbolID
  {
    for r in grammar {
      let start = ruleStore.count
      ruleStore.append(contentsOf: r.rhs)
      rulesByRHSStart[r.rhs.first!, default: []].append(start..<ruleStore.count)
      ruleStore.append(r.lhs)
    }
  }

  /// Parses the sequence of symbols in `source`.
  public mutating func parse<S: Collection>(_ source: S) where S.Element == SymbolID {
    // print("parse:", source.map(symbolName))
    // Recognize each token over its range in the source.
    for (i, s) in source.enumerated() {
      recognize(s, spanningInput: i ..< i + 1)
    }
  }

  private func lhs(_ r: RuleTail) -> SymbolID {
    ruleStore[r.upperBound]
  }

  private func next(_ r: RuleTail) -> SymbolID {
    ruleStore[r.first!]
  }

  /// Recognizes the expected (post-dot) symbol of `r`, ending at `l`.
  private mutating func advance(_ r: PartialParse, to l: SourcePosition) {
    // print("\(r.start..<l): advance\t", ruleString(r.expected), "to", l)
    var p = r
    _ = p.expected.popFirst()
    if p.isComplete {
      recognize(lhs(p.expected), spanningInput: p.start..<l)
    }
    else {
      let postdot = next(p.expected)
      chart[ChartLocation(expecting: postdot, at: l), default: []].append(p)
    }
  }

  /// Recognizes `s` over `g` in the input.
  private mutating func recognize(_ s: SymbolID, spanningInput g: SourceRegion) {
    // print("\(g): recognize\t", symbolName(s))

    // Advance all rules that are expecting s at g.lowerBound.
    if let advancingRules = chart[ChartLocation(expecting: s, at: g.lowerBound)] {
      for p in advancingRules {
        advance(p, to: g.upperBound)
      }
    }

    // Initiate all rules that start by expecting s.
    for r in rulesByRHSStart[s, default: []] {
      // print("\(g): initiate\t", ruleString(r))
      advance(PartialParse(expected: r, start: g.lowerBound), to: g.upperBound)
    }
  }
}
