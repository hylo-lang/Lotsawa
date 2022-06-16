/// A collection of Backus-Naur Form (BNF) productions, each defining a symbol
/// on its left-hand side in terms of a string of symbols on its right-hand
/// side, where a symbol is an enhanced `RawSymbol` (see `Symbol`).
public struct Grammar<RawSymbol: Hashable> {

  /// A symbol for the nihilist normal form (NNF) of the raw grammar, per Aycock
  /// and Horspool.
  ///
  /// During NNF transformation, each nullable `RawSymbol` is divided into two
  /// versions: `.some,` which never derives the empty string 𝝐, and `.null`,
  /// which always does.  Before NNF transformation, all symbols are stored in
  /// the `.some` form.
  enum Symbol: Hashable {
    /// The non-nulling plain raw symbol
    case some(RawSymbol)
    
    /// The nulling version of the symbol.
    case null(RawSymbol)
  }
  
  /// A type that stores all rules packed end-to-end, with the LHS symbol following the RHS symbols.
  ///
  /// For example A -> B C is stored as the subsequence [B, C, A].
  typealias RuleStore = [Symbol]
  
  /// Storage for all the rules.
  private var ruleStore: [Symbol] = []

  /// A Backus-Naur Form (BNF) production.
  struct Rule: Hashable {
    /// The indices in `rulestore` of this rule's RHS symbols.
    var rhsIndices: Range<RuleStore.Index>

    /// The index in `ruleStore` where the LHS symbol can be found.
    var lhsIndex: Grammar.RuleStore.Index { rhsIndices.upperBound }

    /// A value that can uniquely identify a rule in the grammar.
    struct ID: Hashable { var lhsIndex: RuleStore.Index }

    /// A value that uniquely identifies this rule in the grammar.
    var id: ID { .init(lhsIndex: lhsIndex) }

    /// `self`, with the recognition marker (dot) before its first RHS symbol.
    var dotted: Grammar.DottedRule { .init(postdotIndices: rhsIndices) }

    /// The length of this rule's RHS.
    var rhsCount: Int { rhsIndices.count }
  }

  /// The RHS alternatives for each nonterminal symbol.
  private var rulesByLHS = MultiMap<Symbol, Rule>()

  /// The IDs of all right-recursive rules.
  private var rightRecursive: Set<Rule.ID> = []
}

extension Grammar {
  /// A string of symbols found on the RHS of a rule.
  typealias SymbolString = LazyMapSequence<Range<RuleStore.Index>, Symbol>

  /// A partially-recognized suffix of a grammar rule's RHS, where a notional
  /// “dot” marks the end of the recognized symbols of the RHS.
  struct DottedRule: Hashable {
    /// The indices in `rulestore` of the unrecognized RHS symbols.
    var postdotIndices: Range<RuleStore.Index>

    /// The index in ruleStore where the rule's LHS symbol can be found.
    var lhsIndex: RuleStore.Index { postdotIndices.upperBound }

    /// The index in `ruleStore` of the symbol following the dot.
    var postdotIndex: RuleStore.Index? { postdotIndices.first }

    /// The number of symbols following the dot.
    var postdotCount: Int { postdotIndices.count }

    /// `self`, but with the dot advanced by one position.
    var advanced: Self {
      Self(postdotIndices: postdotIndices.dropFirst())
    }

    /// The identity of the full rule of which `self` is a suffix.
    var ruleID: Rule.ID { .init(lhsIndex: lhsIndex) }

    /// True iff the rule is fully-recognized.
    var isComplete: Bool { postdotIndices.isEmpty }
  }
}

extension Grammar.Symbol {
  /// `true` iff this symbol derives 𝝐 and only 𝝐
  var isNulling: Bool {
    if case .null = self { return true } else { return false }
  }

  /// The underlying raw (client-facing) symbol value.
  var raw: RawSymbol {
    switch self { case let .some(r), let .null(r): return r }
  }

  /// `self`𝝐 (where X𝝐𝝐 ::= X𝝐)
  var asNull: Self { .null(raw) }

  /// Replaces `self` with `self.asNull`.
  mutating func nullify() { self = self.asNull }
}

extension Grammar {
  /// The rules for a given LHS symbol.
  typealias Alternatives = [Rule]

  /// Returns the right-hand side alternatives for lhs, or an empty collection if lhs is a terminal.
  func alternatives(_ lhs: Symbol) -> Alternatives { rulesByLHS[lhs] }

  /// Returns the LHS symbol for the rule corresponding to `t`.
  func lhs(_ t: DottedRule) -> Symbol { ruleStore[t.lhsIndex] }

  /// Returns the LHS symbol of `r`.
  func lhs(_ r: Rule) -> Symbol { ruleStore[t.lhsIndex] }

  /// Returns the next expected symbol of `t`, or `nil` if `t.isComplete`.
  func postdot(_ t: DottedRule) -> Symbol? { ruleStore[t.postdotIndices].first }

  /// Creates an preprocessed version of `rawRules` suitable for use by a
  /// `Recognizer`, where `rawRules` is a BNF grammar of `RawSymbol`s.
  init<RawRules: Collection, RHS: Collection>(_ rawRules: RawRules)
    where RawRules.Element == (lhs: RawSymbol, rhs: RHS), RHS.Element == RawSymbol
  {
    // Build an organized representation of the raw rules.
    for (s, rhs) in rawRules {
      let start = ruleStore.count
      ruleStore.append(contentsOf: rhs.lazy.map { s in .some(s) } )
      let r = Rule(rhsIndices: start..<ruleStore.endIndex)
      ruleStore.append(.some(s))
      rulesByLHS[.some(s)].append(r)
    }

    // Preprocessing steps.
    enterNihilistNormalForm()
    identifyRightRecursions()
  }

  /// Puts the grammar in nihilist normal form (NNF), per Aycock and Horspool.
  mutating func enterNihilistNormalForm() {
    // Create a mapping from symbol to the set of rules on whose RHS the symbol appears.
    var rulesByRHS = MultiMap<Symbol, Rule>()
    for rules in rulesByLHS.values {
      for r in rules {
        for s in rhs(r) { rulesByRHS[s].append(r) }
      }
    }

    // Discover which symbols sometimes derive (nullable) and always (nulling) derive 𝝐.
    let (nullable, nulling) = nullSymbolSets(rulesByRHS: rulesByRHS)
    
    for s in nulling {
      rewriteRules(withNullingLHS: s)
    }

    // Then the rules with nullable symbols on the RHS
    let rulesWithANullableSymbolOnRHS
      = Set(nullable.lazy.map { s in rulesByRHS[s] }.joined())

    for r in rulesWithANullableSymbolOnRHS where !nulling.contains(lhs(r)) {
      clone(r, forNullablesStartingAt: 0)
    }

    /// Replaces rules producing `s` with rules producing `s`𝝐, with each symbol
    /// B on the rhs of such a rule replaced with B𝝐.
    func rewriteRules(withNullingLHS s: Symbol) {
      let rules = rulesByLHS.removeValues(forKey: s)
      rulesByLHS[s.asNull] = rules
      for r in rules {
        for i in r.rhsIndices { ruleStore[i].nullify() }
        ruleStore[r.lhsIndex].nullify()
      }
    }

    /// For each combination K of nullable symbol positions starting at
    /// `rhsOffset` on `r`'s RHS, replicates `r` with symbols in positions K
    /// replaced by their nulling counterparts.
    func clone(_ r: Rule, forNullablesStartingAt rhsOffset: Int) {
      // TODO: consider eliminating recursion
      for i in rhsOffset..<r.rhsCount where nullable.contains(rhs(r).nth(i)) {
        // Reserve storage so source of copy has a stable address.
        ruleStore.amortizedLinearReserveCapacity(ruleStore.count + r.rhsCount + 1)

        // Copy the symbols, remembering where they went.
        let cloneStart = ruleStore.count
        let src = ruleStore.withUnsafeBufferPointer { b in b }
        ruleStore.append(contentsOf: src[r.rhsIndices.lowerBound...r.rhsIndices.upperBound])

        // Replace the ith one with its nulling version.
        ruleStore[cloneStart + i] = rhs(r).nth(i).asNull

        // Register the new rule.
        let r1 = Rule(rhsIndices: cloneStart..<(ruleStore.count - 1))
        rulesByLHS[lhs(r1)].append(r1)

        // Be sure to clone again for any remaining nulling symbols in the clone.
        clone(r1, forNullablesStartingAt: i + 1)
      }
    }
  }

  /// Returns the set of nullable symbols (which derive 𝝐) and the set of
  /// nulling symbols (which always derive 𝝐) in a grammar that is not yet in
  /// nihilist normal form.
  func nullSymbolSets(rulesByRHS: MultiMap<Symbol, Rule>)
    -> (nullable: Set<Symbol>, nulling: Set<Symbol>)
  {
    var nullable = Set<Symbol>()
    var nulling = Set<Symbol>()
    for (s, alternatives) in rulesByLHS.storage {
      let x = alternatives.satisfaction { r in r.rhsCount == 0 }
      if x == .all { discoverNulling(s) }
      else if x != .none { discoverNullable(s) }
    }

    func discoverNulling(_ s: Symbol) {
      if !nullable.contains(s) { discoverNullable(s) }
      nulling.insert(s)
      for r in rulesByRHS[s] {
        let s0 = self.lhs(r)
        if nulling.contains(s0) { continue }
        if rulesByLHS[s0]
             .allSatisfy({ r in rhs(r).allSatisfy(nulling.contains) })
        {
          discoverNulling(s0)
        }
      }
    }

    func discoverNullable(_ s: Symbol) {
      nullable.insert(s)
      for r in rulesByRHS[s] {
        let s0 = lhs(r)
        if !nullable.contains(s0) && rhs(r).allSatisfy(nullable.contains) {
          discoverNullable(s0)
        }
      }
    }
    return (nullable, nulling)
  }

  /// Identifies and memoizes the set of right-recursive rules in `self`.
  mutating func identifyRightRecursions() {
    for rules in rulesByLHS.values {
      for r in rules {
        if computeIsRightRecursive(r) { rightRecursive.insert(r.id) }
      }
    }
  }
}

/// Functions needed for Leo support.
extension Grammar {
  // Note: UNUSED
  /// Returns `true` iff `s` is a terminal symbol.
  func isTerminal(_ s: Symbol) -> Bool { return alternatives(s).isEmpty }

  /// Returns the RHS symbols of `x` that have yet to be recognized.
  func postdotRHS(_ x: DottedRule) -> SymbolString {
    x.postdotIndices.lazy.map { i in ruleStore[i] }
  }

  /// Returns the RHS symbols of `x`.
  func rhs(_ x: Rule) -> SymbolString { postdotRHS(x.dotted) }

  /// Returns the rightmost non-nulling symbol of `r`.
  func rightmostNonNullingSymbol(_ r: Rule) -> Symbol? {
    rhs(r).last { s in !s.isNulling }
  }

  /// Returns `true` iff x is right-recursive.
  ///
  /// - Note: this computation can be costly and the result should be memoized.
  func computeIsRightRecursive(_ x: Rule) -> Bool {
    guard let rnn = rightmostNonNullingSymbol(x) else {
      return false
    }
    if lhs(x) == rnn { return true }
    var visited: Set<Symbol> = []
    var q: Set<Symbol> = [rnn]

    while let s = q.popFirst() {
      visited.insert(s)
      for r in alternatives(s) {
        guard let rnn = rightmostNonNullingSymbol(r) else { continue }
        if rnn == lhs(x) { return true }
        if !visited.contains(rnn) { q.insert(rnn) }
      }
    }
    return false
  }

  /// Returns `postdot(x)` iff it is the rightmost non-nulling symbol, and `nil`
  /// otherwise.
  func penult(_ x: DottedRule) -> Symbol? {
    guard let next = postdot(x) else { return nil }
    return !next.isNulling && postdotRHS(x.advanced).allSatisfy { s in s.isNulling }
      ? next : nil
  }

  /// Returns true iff `x`'s underlying rule is right-recursive.
  func isRightRecursive(_ x: DottedRule) -> Bool {
    rightRecursive.contains(x.ruleID)
  }
}

extension Grammar {
  func description(_ x: DottedRule) -> String {
    var r = "\(lhs(x)) ->\t"
    let fullRule = alternatives(lhs(x)).first { $0.id == x.ruleID }!
    var toPrint = fullRule.rhsIndices
    if toPrint.isEmpty { r += "•" }
    while let i = toPrint.popFirst() {
      r += "\(ruleStore[i]) "
      if toPrint.count == x.postdotCount { r += "• " }
    }
    return r
  }
}

extension Grammar.Symbol: CustomStringConvertible {
  /// A string representation of `self`.
  var description: String {
    switch self {
    case let .some(r): return "\(r)"
    case let .null(r): return "\(r)𝜀"
    }
  }
}

