protocol GrammarConfiguration {
  associatedtype SymbolNumber: BinaryInteger
  associatedtype RuleNumber: BinaryInteger
}

public struct Symbol<Ordinal: BinaryInteger>: Hashable {
  let ordinal: Ordinal
}

public struct Rule<Ordinal: BinaryInteger>: Hashable {
  let ordinal: Ordinal
}

extension GrammarConfiguration {
  typealias Symbol = Lotsawa.Symbol<SymbolNumber>
  typealias Rule = Lotsawa.Rule<RuleNumber>
}

/// A collection of Backus-Naur Form (BNF) productions, each defining a symbol
/// on its left-hand side in terms of a string of symbols on its right-hand
/// side.
public struct Grammar<Config: GrammarConfiguration> {

  public typealias Symbol = Config.Symbol
  public typealias Rule = Config.Rule

  /// The number of symbols in this grammar.
  private var symbolCount: Config.SymbolNumber

  /// A type that stores all rules packed end-to-end, with the LHS symbol following the RHS symbols.
  ///
  /// For example A -> B C is stored as the subsequence [B, C, A].
  typealias ProductionStore = [Symbol]

  /// Storage for all the productions.
  private var productionStore: RuleStore = []

  /// Where each numbered rule begins in `ruleStore`, in sorted order.
  private var ruleStart: [RuleStore.Index]

  /// A CFG production.
  struct Production: Hashable {
    /// The indices in `productionstore` of this production's RHS symbols.
    var rhsIndices: Range<ProductionStore.Index>

    /// The index in `productionStore` where the LHS symbol can be found.
    var lhsIndex: Grammar.ProductionStore.Index { rhsIndices.upperBound }

    /// A value that can uniquely identify a production in the grammar.
    struct ID: Hashable { var lhsIndex: ProductionStore.Index }

    /// A value that uniquely identifies this production in the grammar.
    var id: ID { ID(lhsIndex: lhsIndex) }

    /// `self`, with the recognition marker (dot) before its first RHS symbol.
    var dotted: Grammar.DottedRule { .init(postdotIndices: rhsIndices) }

    /// The length of this production's RHS.
    var rhsCount: Int { rhsIndices.count }
  }

  /// The possible right-hand sides for each nonterminal symbol.
  private var productionsByLHS = MultiMap<Symbol, Production>()

  /// The IDs of all right-recursive productions.
  private var rightRecursive: Set<Production.ID> = []
}

extension Grammar {
  /// A string of symbols found on the RHS of a production.
  typealias SymbolString = LazyMapSequence<Range<ProductionStore.Index>, Symbol>

  /// A partially-recognized suffix of a grammar production's RHS, where a notional
  /// “dot” marks the end of the recognized symbols of the RHS.
  struct DottedRule: Hashable {
    /// The indices in `productionstore` of the unrecognized RHS symbols.
    var postdotIndices: Range<ProductionStore.Index>

    /// The index in productionStore where the production's LHS symbol can be found.
    var lhsIndex: ProductionStore.Index { postdotIndices.upperBound }

    /// The index in `productionStore` of the symbol following the dot.
    var postdotIndex: ProductionStore.Index? { postdotIndices.first }

    /// The number of symbols following the dot.
    var postdotCount: Int { postdotIndices.count }

    /// `self`, but with the dot advanced by one position.
    var advanced: Self {
      Self(postdotIndices: postdotIndices.dropFirst())
    }

    /// The identity of the full production of which `self` is a suffix.
    var productionID: Production.ID { .init(lhsIndex: lhsIndex) }

    /// True iff the production is fully-recognized.
    var isComplete: Bool { postdotIndices.isEmpty }
  }
}

extension Grammar {
  /// Returns the right-hand side definitions for lhs, or an empty collection if lhs is a terminal.
  func definitions(_ lhs: Symbol) -> [Production] { productionsByLHS[lhs] }

  /// Returns the LHS symbol for the production corresponding to `t`.
  func lhs(_ t: DottedRule) -> Symbol { productionStore[t.lhsIndex] }

  /// Returns the LHS symbol of `r`.
  func lhs(_ r: Production) -> Symbol { productionStore[r.lhsIndex] }

  /// Returns the next expected symbol of `t`, or `nil` if `t.isComplete`.
  func postdot(_ t: DottedRule) -> Symbol? { productionStore[t.postdotIndices].first }

  /// Returns a new symbol in the grammar.
  public mutating func addSymbol() -> Symbol {
    precondition(symbolCount > Symbol.max, "Symbol capacity of \(Symbol.self) exceeded.")
    defer { symbolCount += 1 }
    return Symbol(truncatingIfNeeded: symbolCount)
  }

  /// Creates an preprocessed version of `rawProductions` suitable for use by a
  /// `Recognizer`, where `rawProductions` is a BNF grammar of `RawSymbol`s.
  public init<RawProductions: Collection, RHS: Collection>(_ rawProductions: RawProductions)
    where RawProductions.Element == (lhs: RawSymbol, rhs: RHS), RHS.Element == RawSymbol
  {
    // Build an organized representation of the raw productions.
    for (s, rhs) in rawProductions {
      let start = productionStore.count
      productionStore.append(contentsOf: rhs.lazy.map { s in .some(s) } )
      let r = Production(rhsIndices: start..<productionStore.endIndex)
      productionStore.append(.some(s))
      productionsByLHS[.some(s)].append(r)
    }

    // Preprocessing steps.
    enterNihilistNormalForm()
    identifyRightRecursions()
  }

  /// Puts the grammar in nihilist normal form (NNF), per Aycock and Horspool.
  mutating func enterNihilistNormalForm() {
    // Build a mapping from symbol to the set of productions on whose RHS the symbol appears.
    var productionsByRHS = MultiMap<Symbol, Production>()
    for productions in productionsByLHS.values {
      for r in productions {
        for s in rhs(r) { productionsByRHS[s].append(r) }
      }
    }

    // Discover which symbols sometimes derive (nullable) and always (nulling) derive 𝝐.
    let (nullableSymbols, nullingSymbols) = nullSymbolSets(productionsByRHS: productionsByRHS)

    // Productions for nulling symbols have a simple rewrite.
    for s in nullingSymbols { rewriteProductions(withNullingLHS: s) }

    // Other productions with nullable symbols on the RHS
    let productionsWithNullableParts = Set(nullableSymbols.lazy.map { s in productionsByRHS[s] }.joined())

    for r in productionsWithNullableParts where !nullingSymbols.contains(lhs(r)) {
      clone(r, forNullablesStartingAt: 0)
    }

    /// Replaces productions producing `s` with productions producing `s`𝝐, with each symbol
    /// B on the rhs of such a production replaced with B𝝐.
    func rewriteProductions(withNullingLHS s: Symbol) {
      let productions = productionsByLHS.removeValues(forKey: s)
      productionsByLHS[s.asNull] = productions
      for r in productions {
        for i in r.rhsIndices { productionStore[i].nullify() }
        productionStore[r.lhsIndex].nullify()
      }
    }

    /// For each combination K of nullable symbol positions starting at
    /// `rhsOffset` on `r`'s RHS, replicates `r` with symbols in positions K
    /// replaced by their nulling counterparts.
    func clone(_ r: Production, forNullablesStartingAt rhsOffset: Int) {
      // TODO: consider eliminating recursion
      for i in rhsOffset..<r.rhsCount where nullableSymbols.contains(rhs(r).nth(i)) {
        // Reserve storage so source of copy has a stable address.
        productionStore.amortizedLinearReserveCapacity(productionStore.count + r.rhsCount + 1)

        // Copy the symbols, remembering where they went.
        let cloneStart = productionStore.count
        let src = productionStore.withUnsafeBufferPointer { b in b }
        productionStore.append(contentsOf: src[r.rhsIndices.lowerBound...r.rhsIndices.upperBound])

        // Replace the ith one with its nulling version.
        productionStore[cloneStart + i] = rhs(r).nth(i).asNull

        // Register the new production.
        let r1 = Production(rhsIndices: cloneStart..<(productionStore.count - 1))
        productionsByLHS[lhs(r1)].append(r1)

        // Be sure to clone again for any remaining nulling symbols in the clone.
        clone(r1, forNullablesStartingAt: i + 1)
      }
    }
  }

  /// Returns the set of nullable symbols (which sometimes derive 𝝐) and the subset of nulling
  /// symbols (which always derive 𝝐) in a grammar that is not yet in nihilist normal form.
  func nullSymbolSets(productionsByRHS: MultiMap<Symbol, Production>)
    -> (nullable: Set<Symbol>, nulling: Set<Symbol>)
  {
    // Note: Warshall's algorithm for transitive closure can help here.
    var nullable = Set<Symbol>()
    var nulling = Set<Symbol>()
    for (lhs, definitions) in productionsByLHS.storage {
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
      for r in productionsByRHS[s] {
        let s0 = self.lhs(r)
        if nulling.contains(s0) { continue }
        if productionsByLHS[s0]
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
      for r in productionsByRHS[s] {
        let s0 = lhs(r)
        if !nullable.contains(s0) && rhs(r).allSatisfy(nullable.contains) {
          discoverNullable(s0)
        }
      }
    }
    return (nullable, nulling)
  }

  /// Identifies and memoizes the set of right-recursive productions in `self`.
  mutating func identifyRightRecursions() {
    for productions in productionsByLHS.values {
      for r in productions {
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

  /// Returns the RHS symbols of `x` that have yet to be recognized.
  func postdotRHS(_ x: DottedRule) -> SymbolString {
    x.postdotIndices.lazy.map { i in productionStore[i] }
  }

  /// Returns the RHS symbols of `x`.
  func rhs(_ x: Production) -> SymbolString { postdotRHS(x.dotted) }

  /// Returns the rightmost non-nulling symbol of `r`.
  ///
  /// - Precondition: `self` is in nihilist normal form.
  func rightmostNonNullingSymbol(_ r: Production) -> Symbol? {
    rhs(r).last { s in !s.isNulling }
  }

  /// Returns `true` iff x is right-recursive.
  ///
  /// - Note: this computation can be costly and the result should be memoized.
  /// - Precondition: `self` is in nihilist normal form.
  func computeIsRightRecursive(_ x: Production) -> Bool {
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

  /// Returns true iff `x`'s underlying production is right-recursive.
  ///
  /// - Precondition: `self`'s right recursions have been computed.
  func isRightRecursive(_ x: DottedRule) -> Bool {
    rightRecursive.contains(x.productionID)
  }
}

extension Grammar {
  /// A string representation of `self`.
  func description(_ x: DottedRule) -> String {
    var r = "\(lhs(x)) ->\t"
    let fullProduction = definitions(lhs(x)).first { $0.id == x.productionID }!
    var toPrint = fullProduction.rhsIndices
    if toPrint.isEmpty { r += "•" }
    while let i = toPrint.popFirst() {
      r += "\(productionStore[i]) "
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
