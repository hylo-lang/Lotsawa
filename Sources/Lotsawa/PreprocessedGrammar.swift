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
  typealias RewriteSymbol = (position: Position, symbol: Symbol, isNullable: Bool)
  typealias RewriteBuffer = [RewriteSymbol]

  /// Given a non-nulling rule from a raw grammar with its LHS in `rawRule.first` and the
  /// non-nulling symbols of its RHS in `rawRule.dropFirst()`, adds a denullified rewrite to self,
  /// updating `rawPositions` to reflect the correspondences.
  mutating func addDenullified(
    rawRule: RewriteBuffer,
    rawPositions: inout DiscreteMap<Position, Position>
  ) {
    var lhs = rawRule.prefix(1)
    var rhs = rawRule.dropFirst()

    // The longest suffix of nullable symbols.
    let nullableSuffix = rhs.suffix(while: \.isNullable)

    func addRewrite(lhs: RewriteBuffer.SubSequence, rhs: RewriteBuffer.SubSequence) {
      addRewrittenRule(lhs: lhs.first!.symbol, rhs: rhs, updating: &rawPositions)
    }

    func synthesizedSymbol(for r: RewriteBuffer.SubSequence) -> RewriteBuffer.SubSequence {
      [(position: r.first!.position, symbol: newSymbol(), isNullable: false)][...]
    }

    while !rhs.isEmpty {
      guard let qStart = rhs.firstIndex(where: \.isNullable ) else {
        // Trivial case; there are no nullable symbols
        addRewrite(lhs: lhs, rhs: rhs)
        return
      }
      // Break the RHS into pieces as follows:
      //
      // head | anchor | q | tail
      //
      // where:
      // 1. q is the leftmost nullable
      //
      // 2. anchor is 1 symbol iff q is not the leftmost symbol and tail contains only nullable
      //    symbols; otherwise anchor is empty.
      //
      // Why anchor? We may factor out a common prefix, creating [lhs -> head lhs1] where lhs1 is a
      // synthesized continuation symbol.  Including anchor in lhs1 ensures that lhs1 doesn't itself
      // need to be a nullable symbol.
      let hasAnchor = qStart > rhs.startIndex && qStart >= nullableSuffix.startIndex
      let head = hasAnchor ? rhs[..<qStart].dropLast() : rhs[..<qStart]
      let anchor = rhs[..<qStart].suffix(hasAnchor ? 1 : 0)
      let q = rhs[qStart...].prefix(1)
      let tail = rhs[qStart...].dropFirst()

      // If head is non-empty synthesize a symbol in lhs1 for head's continuation, adding
      // lhs -> head lhs1.  Otherwise, just use lhs as lhs1.
      let lhs1 = head.isEmpty ? lhs : synthesizedSymbol(for: rhs[anchor.startIndex...])
      if !head.isEmpty {
        addRewrite(lhs: lhs, rhs: head + lhs1)
      }

      // If tail length > 1, synthesize a symbol in tail1 for tail.  Otherwise, tail1 is tail.
      let tail1 = tail.count > 1 ? synthesizedSymbol(for: tail) : tail

      // Create each distinct rule having a non-empty RHS in:
      //   lhs1 -> anchor
      //   lhs1 -> anchor q
      //   lhs1 -> anchor tail1
      //   lhs1 -> anchor q tail1
      if !anchor.isEmpty { addRewrite(lhs: lhs1, rhs: anchor) }
      if !q.isEmpty {
        addRewrite(lhs: lhs1, rhs: anchor + q)
        if !tail1.isEmpty { addRewrite(lhs: lhs1, rhs: anchor + q + tail1) }
      }
      if !tail1.isEmpty { addRewrite(lhs: lhs1, rhs: anchor + tail1) }
      if tail.count <= 1 { break }
      lhs = tail1.prefix(1)
      rhs = tail
    }
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
