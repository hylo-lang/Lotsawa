public struct EarleyParser {
  /// Terminals and nonterminals are identified by a symbol ID.
  public typealias SymbolID = Int

  /// The symbols of all rules, stored end-to-end.
  typealias RuleStore = [SymbolID]

  /// The RHS symbols of a parse rule followed by the rule's LHS symbol.
  typealias Rule = RuleStore.SubSequence

  /// A range of positions in `ruleStore` denoting a suffix of a rule's RHS.
  typealias RHSTail = Range<RuleStore.Index>

  /// A position in the input.
  typealias SourcePosition = Int

  /// A range of positions in the input.
  typealias SourceRegion = Range<SourcePosition>

  /// A parse rule being matched.
  struct PartialParse: Hashable {
    /// The positions in ruleStore of yet-to-be recognized RHS symbols.
    var expected: RHSTail

    /// The position in the token stream where the partially-parsed input begins.
    var start: SourcePosition

    /// True iff the entire RHS has been recognized.
    var isComplete: Bool { expected.isEmpty }
  }
  typealias Item = PartialParse

  /// Storage for all the rules.
  var ruleStore: RuleStore = []

  /// The right-hand side alternatives for each nonterminal symbol.
  var rulesByLHS: [SymbolID: [RHSTail]] = [:]

  /// all the partial parses
  var S: Array<Set<Item>> = []

  /// The items with which to initialize S[0]
  var initialItems: Set<Item> = []
}

/// Initialization and algorithm.
extension EarleyParser {
  /// Creates a parser for the given grammar.
  public init<Grammar: Collection, RHS: Collection>(_ grammar: Grammar, recognizing start: SymbolID)
    where Grammar.Element == (lhs: SymbolID, rhs: RHS),
          RHS.Element == SymbolID
  {
    for r in grammar {
      let start = ruleStore.count
      ruleStore.append(contentsOf: r.rhs)
      let rhs = start..<ruleStore.count
      ruleStore.append(r.lhs)
      rulesByLHS[r.lhs, default: []].append(rhs)

      if r.lhs == start {
        initialItems.insert(Item(expected: rhs, start: 0))
      }
    }
  }

  /// Parses the sequence of symbols in `source`.
  public mutating func parse<Source: Collection>(_ source: Source) where Source.Element == SymbolID {
    let n = source.count
    S.removeAll(keepingCapacity: true)
    S.reserveCapacity(n + 1)
    S.append(initialItems)
    S.append(contentsOf: repeatElement([], count: n))

    // Recognize each token over its range in the source.
    for (i, t) in source.enumerated() {
      for var item in S[i] {
        if let x = item.expected.popFirst() {
          let expected: SymbolID = ruleStore[x]
          if t == expected {
            S[i + 1].insert(item) // scan
          }
          else {
            for rhs in rulesByLHS[expected, default: []] {
              S[i].insert(Item(expected: rhs, start: i))  // predict
            }
          }
        }
        else {
          let lhs = ruleStore[item.expected.upperBound]
          // TODO: avoid a linear search over everything in S[item.start].
          for var parent in S[item.start] where ruleStore[parent.expected].first == lhs {
            _ = parent.expected.popFirst()
            S[i].insert(parent) // complete.
          }
        }
      }
    }
  }
}
