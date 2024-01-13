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

    // A work queue for unprocessed discoveries.
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

  /// Returns a dictionary mapping each symbol that appears on the RHS of any rule to the rules on
  /// whose RHS the symbol appears.
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
