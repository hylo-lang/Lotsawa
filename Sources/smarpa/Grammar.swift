enum AllSomeNone { case all, some, none }

extension Collection {
  /// Returns an indication of whether all, some, or no elements satisfy `predicate`.
  func whichSatisfy(_ predicate: (Element)->Bool) -> AllSomeNone {
    guard let i = firstIndex(where: predicate) else { return .none }
    if i == startIndex && dropFirst().allSatisfy(predicate) { return .all }
    return .some
  }
}

public struct Grammar<RawSymbol: Hashable> {

  /// Symbols for the nihilist normal form (NNF) of the raw grammar, per Aycock and Horspool
  enum Symbol: Hashable {
    /// The plain raw symbol
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

  /// A suffix of a grammar rule's RHS, from which the rule's LHS symbol can also be identified.
  typealias PartialRule = Range<RuleStore.Index>

  /// The right-hand side alternatives for each nonterminal symbol.
  private var rulesByLHS = MultiMap<Symbol, PartialRule>()

  /// The lhsIndex of all right-recursive rules.
  private var rightRecursive: Set<RuleStore.Index> = []
}

extension Grammar.Symbol {
  /// `true` iff this symbol derives 𝝐 and only 𝝐
  var isNulling: Bool {
    if case .null = self { return true } else { return false }
  }

  var raw: RawSymbol {
    switch self { case let .some(r), let .null(r): return r }
  }

  mutating func makeNull() {
    self = .null(raw)
  }
}

extension Grammar {
  /// The rules for a given LHS symbol.
  typealias Alternatives = [PartialRule]

  /// Returns the right-hand side alternatives for lhs, or an empty collection if lhs is a terminal.
  func alternatives(_ lhs: Symbol) -> Alternatives { rulesByLHS[lhs] }

  /// Returns `true` iff `rhs` is empty.
  func isComplete(_ rhs: PartialRule) -> Bool { rhs.isEmpty }

  /// Returns the index of the LHS symbol of `t` in `ruleStore`.
  func lhsIndex(_ t: PartialRule) -> RuleStore.Index { t.upperBound }

  /// Returns the LHS symbol for the rule corresponding to `t`.
  func lhs(_ t: PartialRule) -> Symbol { ruleStore[lhsIndex(t)] }

  /// Returns the next expected symbol of `t`, .
  func postdot(_ t: PartialRule) -> Symbol? { ruleStore[t].first }

  init<RawRules: Collection, RHS: Collection>(_ rawRules: RawRules)
    where RawRules.Element == (lhs: RawSymbol, rhs: RHS), RHS.Element == RawSymbol
  {
    for (s, rhs) in rawRules {
      let start = ruleStore.count
      ruleStore.append(contentsOf: rhs.lazy.map { s in .some(s) } )
      let r = start..<ruleStore.endIndex
      ruleStore.append(.some(s))
      rulesByLHS[.some(s)].append(r)
    }

    // Put the grammar in nihilist normal form (NNF), per Aycock and Horspool
    enterNihilistNormalForm()
    findRightRecursions()
  }

  mutating func enterNihilistNormalForm() {
    var rulesByRHS = MultiMap<Symbol, PartialRule>()
    for rules in rulesByLHS.values {
      for r in rules {
        for s in rhs(r) { rulesByRHS[s].append(r) }
      }
    }

    let (nullable, nulling) = discoverNulls(rulesByRHS: rulesByRHS)
    
    // First the nulling symbols
    for s in nulling {
      let firstRule = rulesByLHS[s].first!
      rulesByLHS.removeKey(s)
      // Change the LHS symbol
      let nullS = Symbol.null(s.raw)
      ruleStore[firstRule.upperBound] = nullS
      // Register it in the new place
      rulesByLHS[nullS].append(firstRule)
    }

    // Then the rules with nullable symbols on the RHS
    let rulesToClone
      = Set(nullable.lazy.map { s in rulesByRHS[s] }.joined())

    for r in rulesToClone {
      clone(r, forNullablesStartingAt: r.startIndex)
    }

    // TODO: make this nicer.  Perhaps an nth(3) function/subscript?
    func clone(_ r: PartialRule, forNullablesStartingAt i_: PartialRule.Index) {
      var i = i_
      while let j = r[i...].first(where: { j in nullable.contains(ruleStore[j]) }) {
        let r1Start = ruleStore.count
        // Copy the symbols, substituting the null symbol for the one found
        for k in r {
          ruleStore.append(k == j ? .null(ruleStore[k].raw) : ruleStore[k])
        }
        let r1 = r1Start..<ruleStore.count
        ruleStore.append(lhs(r))
        rulesByLHS[lhs(r)].append(r1)
        i = j + 1
        clone(r1, forNullablesStartingAt: i - r.startIndex + r1.startIndex)
      }
    }
  }

  func discoverNulls(rulesByRHS: MultiMap<Symbol, PartialRule>)
    -> (nullable: Set<Symbol>, nulling: Set<Symbol>)
  {
    var nullable = Set<Symbol>()
    var nulling = Set<Symbol>()
    for (s, alternatives) in rulesByLHS.storage {
      let x = alternatives.whichSatisfy { $0.isEmpty }
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
             .allSatisfy({ r in ruleStore[r].allSatisfy(nulling.contains) })
        {
          discoverNulling(s0)
        }
      }
    }

    func discoverNullable(_ s: Symbol) {
      nullable.insert(s)
      for r in rulesByRHS[s] {
        let s0 = lhs(r)
        if !nullable.contains(s0) && ruleStore[r].allSatisfy(nullable.contains) {
          discoverNullable(s0)
        }
      }
    }
    return (nullable, nulling)
  }

  mutating func findRightRecursions() {
    for rules in rulesByLHS.values {
      for r in rules {
        if computeIsRightRecursive(r) { rightRecursive.insert(lhsIndex(r)) }
      }
    }
  }
}

/// Leo support
extension Grammar {
  // Note: UNUSED
  /// Returns `true` iff `s` is a terminal symbol.
  func isTerminal(_ s: Symbol) -> Bool { return alternatives(s).isEmpty }

  /// Returns the sequence of symbols in `x` that has yet to be recognized.
  typealias RHSSymbols = LazyMapSequence<PartialRule, Symbol>
  func postdotRHS(_ x: PartialRule) -> RHSSymbols {
    x.lazy.map { s in ruleStore[s] }
  }

  typealias FullRule = PartialRule
  func rhs(_ x: FullRule) -> RHSSymbols { postdotRHS(x) }

  func rightmostNonNullingSymbol(_ r: FullRule) -> Symbol? {
    rhs(r).last { s in !s.isNulling }
  }

  func computeIsRightRecursive(_ x: FullRule) -> Bool {
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

  func penult(_ x: PartialRule) -> Symbol? {
    guard let next = postdot(x) else { return nil }
    return !next.isNulling && postdotRHS(x.dropFirst()).allSatisfy { s in s.isNulling }
      ? next : nil
  }

  func isRightRecursive(_ x: PartialRule) -> Bool {
    rightRecursive.contains(lhsIndex(x))
  }
}

// typealias SourcePosition = Int
