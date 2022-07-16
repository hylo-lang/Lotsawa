fileprivate extension BinaryInteger {
  /// Decrements `self`, returning `true` iff the final value is zero.
  mutating func decrementIsZero() -> Bool {
    self -= 1
    return self == 0
  }
}

extension Grammar {
  /// Returns the set of nullable symbols (which sometimes derive 𝝐) and the subset of nulling
  /// symbols (which always derive 𝝐) in a grammar that is not yet in nihilist normal form.
  func nullSymbolSets() -> (nullable: Set<Symbol>, nulling: Set<Symbol>)
  {
    // - Common setup.

    // Mapping from symbol to the set of ruleIDs having that symbol as a LHS.
    let rulesByLHS = MultiMap(grouping: ruleIDs, by: lhs)
    // Mapping from symbol to ruleIDs in whose RHS which that symbol appears.
    let rulesByRHS = self.rulesByRHS()
    // Mapping from symbol x to the LHS symbols of rules having x on the rhs.
    let lhsSymbolsByRHS = Dictionary<Symbol, Set<Symbol>>(
      uniqueKeysWithValues: rulesByRHS.storage.lazy.map { (rhsSymbol, ruleIDs) in
        (key: rhsSymbol, value: Set(ruleIDs.lazy.map { r in lhs(r) }))
      })
    var uniqueCount = UniqueCounter<Symbol>()

    // - Nulling analysis.
    var nulling = Set<Symbol>()

    // For each nonterminal s, tracks the number of distinct symbols not yet known to be nulling
    // that appear on the RHS of any rule with s on the LHS.  Start by assuming all symbols are
    // non-nulling.
    var maybeNonNullingRHSCount = Dictionary(
      uniqueKeysWithValues: rulesByLHS.storage.lazy.map { (lhs, lhsRuleIDs) in
        (lhs, uniqueCount(lhsRuleIDs.lazy.map { r in rhs(r) }.joined()))
      })

    // A work queue for unprocessed discoveries,
    var unprocessed: Array<Symbol>
      // All trivially-nulling symbols (those that only appear on the LHS of rules with empty RHS).
      = maybeNonNullingRHSCount.lazy.filter { (lhs, rhsCount) in rhsCount == 0 }.map(\.key)

    while let s = unprocessed.popLast() {
      let newlyAdded = nulling.insert(s).inserted
      assert(newlyAdded, "expecting to only discover a nulling symbol once")

      for lhs in lhsSymbolsByRHS[s, default: []] {
        if maybeNonNullingRHSCount[lhs]!.decrementIsZero() {
          unprocessed.append(lhs)
        }
      }
    }

    // - Nullable analysis.
    // Start with the trivially nullable symbols (those on the lhs of any rule with an empty RHS).
    var nullable = Set(ruleIDs.lazy.filter { r in rhs(r).isEmpty }.map { r in lhs(r) })

    // For each rule, tracks the number of distinct symbols not yet known to be nullable on its RHS.
    var maybeNonNullableRHSCount: Array = rules.map { r in uniqueCount(r.rhs) }

    // Reset work queue
    unprocessed.append(contentsOf: nullable)
    while let s = unprocessed.popLast() {
      for r in rulesByRHS[s] {
        let i = Int(r.ordinal)
        if maybeNonNullableRHSCount[i].decrementIsZero() {
          let s1 = lhs(r)
          if nullable.insert(s1).inserted { unprocessed.append(s1) }
        }
      }
    }
    return (nullable: nullable, nulling: nulling)
  }

  /*
   Key:
   𝛂_ = zero or more symbols
   𝛂 = zero or more non-nullable symbols
   𝛂- = one or more symbols of which at least one is non-nullable
   𝛂? = zero or more nullable symbols
   (x0 -> 𝛃_) Result of "recursively" processing this rule

   a = one non-nullable symbol
   q? = one nullable symbol

   l -> 𝛂 a        (no RHS symbols are nullable)

       That case is trivial; rewrite as l -> 𝛂 a

   l -> 𝛂 a q? 𝛃?  (a contiguous tail is nullable)
            ^^
       Rewrite as:
       l -> 𝛂 x0 (if 𝛂 is empty, x0 is l)

       if 𝛃? is empty:      x0 -> a | a q

       else:                x0 -> a | a q | a x1 | a q x1
                            if 𝛃? is 1 symbol, x1 is 𝛃; else (x1 -> 𝛃?)


   l -> q? 𝛃?      (all RHS symbols are nullable, thus l is nullable)
        ^^
       Rewrite as:

       (x0 is l for consistency with the prior case where 𝛂 is empty)
       if 𝛃? is empty:      x0 -> q
       else:                x0 -> q | q x1 | x1
                            if 𝛃? is 1 symbol, x1 is 𝛃; else (x1 -> 𝛃?)

   l -> 𝛂 q? 𝛃- (first nullable is not in a contiguous nullable tail)
          ^^
       Rewrite as:

       l -> 𝛂 x0 (if 𝛂 is empty, x0 is l)
       x0 -> q x1 | x1
                           if 𝛃- is 1 symbol, x1 is 𝛃;   else (x1 -> 𝛃-)

   */
  func rewrite(
    lhs: Symbol, rhs allRHS: Symbols, firstNullable: Symbols.Index,
    nullableTailStart: Symbols.Index
  ) {
    var rhs = allRHS[...]
    while !rhs.isEmpty {
      let nonNullablePrefix = rhs.prefix { x in !x.isNullable }
      let alpha = firstNullable >= nullableTailStart ? nonNullablePrefix.dropLast() : nonNullablePrefix
      let a = nonNullablePrefix.suffix(firstNullable >= nullableTailStart ? 1 : 0)
      let beta = rhs[firstNullable...].dropFirst()

      var x0: Symbol = alpha.isEmpty ? lhs : newSymbol()
      if x0 != lhs { addRule(lhs: lhs, rhs: alpha + [x0]) }
      let x1 = beta.count <= 1 ? beta.prefix(1) : [newSymbol()][...]

      if !a.isEmpty { addRule(lhs: x0, rhs: a) }
      if !q.isEmpty {
        addRule(lhs: x0, rhs: a + q)
        if !x1.isEmpty addRule(lhs: x0, rhs: a + q + x1)
      }
      if !x1.isEmpty addRule(lhs: x0, rhs: a + x1)
      if beta.count <= 1 { break }
      rhs = beta
    }
  }

  func eliminatingNulls() -> (DefaultGrammar, DiscreteMap<DefaultGrammar.Position, Position>) {
    var cooked = DefaultGrammar()
    var mapBack = DiscreteMap<DefaultGrammar.Position, Position>()
    let n = nullSymbolSets()

    typealias BufferElement = (position: Position, symbol: Symbol, isNullable: Bool)
    var buffer: [BufferElement] = []

    for r in rules where !n.nulling.contains(r.lhs) {
      // Initialize the buffer to the non-nulling symbols on the RHS (with positions).
      let nonNullingRHS
        = r.rhs.indices.lazy.map { i in
          (position: i, symbol: r.rhs[i], isNullable: n.isNullable.contains(r.rhs[i]))
        }
        .filter { e in !nulling.contains(e.symbol) }
      buffer.replaceRange(..., with: nonNullingRHS)

      guard let firstNullable = buffer.firstIndex(where: { e in e.isNullable }) else {
        cooked.addRule(lhs: r.lhs, rhs: buffer.map(\.symbol))
        continue
      }

      // Find the position at which symbols are nullable until the end of the buffer.
      let nullableTailStart = buffer.dropLast { e in e.isNullable }.endIndex


    }
    return (cooked, mapBack)
  }
/*
  func preprocessed() -> Grammar {

    enum Category: Int { case nullable = 0, nulling = 1 }

    var ruleSets = (nulling: Set<RuleID>, nullable: Set<RuleID>)
    var symbolSets = (nulling: Set<Symbol>, nullable: Set<Symbol>)

    // The number of distinct symbols on the RHS of each rule.
    var knownRHS = rhsUniqueSymbolCounts()

    var work: [(Symbol, Category)] = []

    func discoverNulling(r: RuleID) {
      nullingRules.insert(r)
      if nullableSymbols.insert(lhs).inserted {
        work.append(lhs)
      }
    }

    for r in ruleIDs where potentiallyNonNullableRHSSymbolCount[r.ordinal] == 0 {
      discoverNulling(r)
    }

    while let nextNullable = work.popLast() {
      for r in rulesByRHS[s] {
        potentiallyNonNullableRHSSymbolCount[r.ordinal] -= 1
        if potentiallyNonNullableRHSSymbolCount[r.ordinal] == 0 {
          nullingRules.insert(r)
          if nullableSymbols rules[r.ordinal].lhs
        }
      }
    }
    var nullingSymbols = Set<Symbol>()

    var knownNullable
    return self // FIXME!
  }

  func nullSymbol
    */

  /// Returns a dictionary mapping each symbol that appears on the RHS of a rule to
  func rulesByRHS() -> MultiMap<Symbol, RuleID> {
    var result = MultiMap<Symbol, RuleID>()
    for (i, r) in zip(ruleIDs, rules) {
      for s in r.rhs {

        result[s].append(i)
      }
    }
    return result
  }
}
/*
struct PreprocessedGrammar<Configuration: GrammarConfiguration> {
  var cooked: Grammar<Configuration>

  init(_ raw: Grammar<Configuration>) {
  }
}
*/
