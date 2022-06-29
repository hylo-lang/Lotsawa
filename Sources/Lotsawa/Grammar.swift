/// A collection of Backus-Naur Form (BNF) rules, each defining a symbol
/// on its left-hand side in terms of a string of symbols on its right-hand
/// side.
///
/// - Parameters:
///   - Size: a type that can represent the size of this grammar (the total length of all right-hand
///     sides of the rules plus the number of rules.
///
///   - SymbolID: a type that can represent the number of symbols used in this grammar.
public struct Grammar<SymbolCount: BinaryInteger, Size: BinaryInteger>
  where Size.Stride: SignedInteger
{
  /// The possible right-hand sides for each nonterminal symbol.
  private var rulesByLHS = MultiMap<Symbol, Rule>()

  /// The IDs of all right-recursive rules.
  private var rightRecursive: Set<Rule.ID> = []

  /// Storage for all the rules.
  private var ruleStore: RuleStore = []

  /// Where each rule begins in `ruleStore`, in sorted order, plus a sentinel that is the start of
  /// the next rule to be added.
  private var ruleStart: [RuleStore.Index] = [0]

  /// The number of symbols, and ID of the next symbol to be added.
  public private(set) var symbolCount: SymbolCount = 0
}

/// A grammar symbol (see https://en.wikipedia.org/wiki/Context-free_grammar).
public struct Symbol<ID: BinaryInteger>: Hashable {
  /// An ordinal identifier for this symbol
  let id: ID
}

extension Grammar {
  public typealias Symbol = Lotsawa.Symbol<SymbolCount>

  /// A type that stores all rules packed end-to-end, with the LHS symbol following the RHS symbols.
  ///
  /// For example A -> B C is stored as the subsequence [B, C, A].
  typealias RuleStore = [Symbol]

  /// A production rule (see https://en.wikipedia.org/wiki/Context-free_grammar).
  public struct Rule: Hashable {
    /// The indices in `rulestore` of this rule's RHS symbols.
    var rhsIndices: Range<Size>

    /// The index in `ruleStore` where the LHS symbol can be found.
    var lhsIndex: RuleStore.Index { RuleStore.Index(rhsIndices.upperBound) }

    /// A type that can uniquely identify a rule in the grammar.
    public struct ID: Hashable { var lhsIndex: Size }

    /// A value that uniquely identifies this rule in the grammar.
    public var id: ID { ID(lhsIndex: rhsIndices.upperBound) }

    /// `self`, with the recognition marker (dot) before its first RHS symbol.
    var dotted: DottedRule { .init(postdotIndices: rhsIndices) }

    /// The length of this rule's RHS.
    public var rhsCount: Int { rhsIndices.count }
  }

  /// Returns the RHS symbols of `x`.
  func rhs(_ x: Rule) -> SymbolString { string(x.rhsIndices) }

  /// The sum, over all rules `r`, of `r.rhsCount + 1`.
  public var size: Size {
    return Size(ruleStore.count)
  }
}

extension Grammar {
  /// A string of symbols found on the RHS of a rule.
  typealias SymbolString = RuleStore.SubSequence

  func string(_ indices: Range<Size>) -> SymbolString {
    ruleStore[RuleStore.Index(indices.lowerBound)..<RuleStore.Index(indices.upperBound)]
  }

  /// A partially-recognized suffix of a grammar rule's RHS, where a notional
  /// “dot” marks the end of the recognized symbols of the RHS.
  struct DottedRule: Hashable {
    /// The indices in `rulestore` of the unrecognized RHS symbols.
    var postdotIndices: Range<Size>

    /// The index in ruleStore where the rule's LHS symbol can be found.
    var lhsIndex: RuleStore.Index { RuleStore.Index(postdotIndices.upperBound) }

    /// The index in `ruleStore` of the symbol following the dot.
    var postdotIndex: RuleStore.Index? { postdotIndices.first.map(RuleStore.Index.init) }

    /// The number of symbols following the dot.
    var postdotCount: Int { postdotIndices.count }

    /// `self`, but with the dot advanced by one position.
    var advanced: Self {
      Self(postdotIndices: postdotIndices.dropFirst())
    }

    /// The identity of the full rule of which `self` is a suffix.
    var ruleID: Rule.ID { .init(lhsIndex: postdotIndices.upperBound) }

    /// True iff the rule is fully-recognized.
    var isComplete: Bool { postdotIndices.isEmpty }
  }

  /// Returns the RHS symbols of `x` that have yet to be recognized.
  func postdotRHS(_ x: DottedRule) -> SymbolString {
    string(x.postdotIndices)
  }

}

extension Grammar {
  /// Returns the right-hand side definitions for lhs, or an empty collection if lhs is a terminal.
  func definitions(_ lhs: Symbol) -> [Rule] { rulesByLHS[lhs] }

  /// Returns the LHS symbol for the rule corresponding to `t`.
  func lhs(_ t: DottedRule) -> Symbol { ruleStore[t.lhsIndex] }

  /// Returns the LHS symbol of `r`.
  func lhs(_ r: Rule) -> Symbol { ruleStore[r.lhsIndex] }

  /// Returns the next expected symbol of `t`, or `nil` if `t.isComplete`.
  func postdot(_ t: DottedRule) -> Symbol? { string(t.postdotIndices).first }

  /// The number of rules and the ordinal of the next rule to be added.
  public var ruleCount: Int { ruleStart.count - 1 }

  /// Returns a new symbol.
  ///
  /// Repeated calls return `Symbol`s with a consecutive series of ordinals starting at zero.
  ///
  /// - Precondition: `symbolCount < Config.SymbolNumber.max`.
  public mutating func addSymbol() -> Symbol {
    defer { symbolCount += 1 }
    return Symbol(id: symbolCount)
  }

  /// Returns a new rule deriving the given `rhs` from `lhs`.
  ///
  /// Repeated calls return `Rules`s with an increasing (but nonconsecutive) series of `id`s.
  ///
  /// - Precondition: `ruleCount < Config.SymbolNumber.max`.
  public mutating func addRule<RHS: Collection>(lhs: Symbol, rhs: RHS) -> Rule
    where RHS.Element == Symbol
  {
    assert(ruleStore.count == ruleStart.last)
    ruleStore.amortizedLinearReserveCapacity(rhs.count + 1)
    let start = ruleStore.count
    ruleStore.append(contentsOf: rhs)
    let end = ruleStore.count
    ruleStore.append(lhs)
    ruleStart.append(ruleStore.count)
    return Rule(rhsIndices: Size(start)..<Size(end))
  }

  /// Returns the ordinal of the rule identified by `r`.
  ///
  /// Added rules are assigned consecutive ordinal values, starting from zero.
  ///
  /// - Complexity: O(log `ruleCount`).
  public func ordinal(_ r: Rule.ID) -> Int {
    let nextOrdinal = ruleStart.partitionPoint { i in i > r.lhsIndex }
    precondition(nextOrdinal > 0, "rule not found.")
    if nextOrdinal < ruleCount {
      precondition(ruleStart[nextOrdinal] == r.lhsIndex + 1, "rule not found.")
    }
    return nextOrdinal - 1
  }

  /// Returns the rule with ordinal `n`.
  ///
  /// - Precondition: `n >= 0 && n < ruleCount`
  public func nthRule(_ n: Int) -> Rule {
    return Rule(rhsIndices: Size(ruleStart[n])..<Size(ruleStart[n + 1]))
  }
}

extension Grammar {
  struct Preprocessed {
    var content = Grammar()
    /// Sorted mapping from positions in `self` into corresponding positions in the raw grammar from
    /// which `self` was derived.
    ///
    /// Many cooked positions need not be represented explicitly, as any unrepresented position `u`
    /// maps to `p.raw + (u - p.cooked)` where `p` is the previous representation in the positionMap.
    var positionMap: [(cooked: RuleStore.Index, raw: RuleStore.Index)] = []

    /// Constructs a preprocessed version of a raw grammar.
    init(_ raw: Grammar) {
      fatalError()
    }
  }
}

extension Grammar {
  /// Returns a mapping from symbol to the set of rules on whose RHS the symbol appears.
  func rulesByRHS() -> MultiMap<Symbol, Rule> {
    var result = MultiMap<Symbol, Rule>()

    for rules in rulesByLHS.values {
      for r in rules {
        for s in rhs(r) { result[s].append(r) }
      }
    }
    return result
  }

  /// Returns the set of nullable symbols (which sometimes derive 𝝐) and the subset of nulling
  /// symbols (which always derive 𝝐) in a grammar that is not yet in nihilist normal form.
  func nullSymbolSets(rulesByRHS: MultiMap<Symbol, Rule>)
    -> (nullable: Set<Symbol>, nulling: Set<Symbol>)
  {
    // Note: Warshall's algorithm for transitive closure can help here.
    var nullable = Set<Symbol>()
    var nulling = Set<Symbol>()
    for (lhs, definitions) in rulesByLHS.storage {
      let x = definitions.satisfaction { r in r.rhsCount == 0 }
      if x == .all { discoverNulling(lhs) }
      else if x != .none { discoverNullable(lhs) }
    }

    /// Marks `s` as nulling, and draws any consequent conlusions.
    func discoverNulling(_ s: Symbol) {
      // Every nulling symbol is nullable
      if !nullable.contains(s) { discoverNullable(s) }
      nulling.insert(s)
      // We may be able to conclude that other symbols are also nulling.
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

    /// Marks `s` as nullable, and draws any consequent conlusions.
    func discoverNullable(_ s: Symbol) {
      nullable.insert(s)
      // We may be able to conclude that other symbols are nullable.
      for r in rulesByRHS[s] {
        let s0 = lhs(r)
        if !nullable.contains(s0) && rhs(r).allSatisfy(nullable.contains) {
          discoverNullable(s0)
        }
      }
    }
    return (nullable, nulling)
  }
}
/*
    // Discover which symbols sometimes derive (nullable) and always (nulling) derive 𝝐.
    let (nullableSymbols, nullingSymbols) = nullSymbolSets(rulesByRHS: rulesByRHS)

    // Rules for nulling symbols have a simple rewrite.
    for s in nullingSymbols { rewriteRules(withNullingLHS: s) }

    // Other rules with nullable symbols on the RHS
    let rulesWithNullableParts = Set(nullableSymbols.lazy.map { s in rulesByRHS[s] }.joined())

    for r in rulesWithNullableParts where !nullingSymbols.contains(lhs(r)) {
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
      for i in rhsOffset..<r.rhsCount where nullableSymbols.contains(rhs(r).nth(i)) {
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
  func isTerminal(_ s: Symbol) -> Bool { return definitions(s).isEmpty }

  /// Returns the rightmost non-nulling symbol of `r`.
  ///
  /// - Precondition: `self` is in nihilist normal form.
  func rightmostNonNullingSymbol(_ r: Rule) -> Symbol? {
    rhs(r).last { s in !s.isNulling }
  }

  /// Returns `true` iff x is right-recursive.
  ///
  /// - Note: this computation can be costly and the result should be memoized.
  /// - Precondition: `self` is in nihilist normal form.
  func computeIsRightRecursive(_ x: Rule) -> Bool {
    // Warshall works here.
    guard let rnn = rightmostNonNullingSymbol(x) else {
      return false
    }
    if lhs(x) == rnn { return true }
    var visited: Set<Symbol> = []
    var q: Set<Symbol> = [rnn]

    while let s = q.popFirst() {
      visited.insert(s)
      for r in definitions(s) {
        guard let rnn = rightmostNonNullingSymbol(r) else { continue }
        if rnn == lhs(x) { return true }
        if !visited.contains(rnn) { q.insert(rnn) }
      }
    }
    return false
  }

  /// Returns `postdot(x)` iff it is the rightmost non-nulling symbol and `nil` otherwise.
  ///
  /// - Precondition: `self` is in nihilist normal form.
  func penult(_ x: DottedRule) -> Symbol? {
    guard let next = postdot(x) else { return nil }
    return !next.isNulling && postdotRHS(x.advanced).allSatisfy { s in s.isNulling }
      ? next : nil
  }

  /// Returns true iff `x`'s underlying rule is right-recursive.
  ///
  /// - Precondition: `self`'s right recursions have been computed.
  func isRightRecursive(_ x: DottedRule) -> Bool {
    rightRecursive.contains(x.ruleID)
  }
}

extension Grammar {
  /// A string representation of `self`.
  func description(_ x: DottedRule) -> String {
    var r = "\(lhs(x)) ->\t"
    let fullRule = definitions(lhs(x)).first { $0.id == x.ruleID }!
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
*/
