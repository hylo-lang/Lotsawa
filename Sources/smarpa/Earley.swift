public protocol AnyEarleyGrammar {
  /// A terminal or nonterminal in the grammar
  associatedtype Symbol: Equatable

  /// A suffix of a grammar rule's RHS, from which the rule's LHS symbol can also be identified.
  associatedtype PartialRule: Collection, Hashable where PartialRule.SubSequence == PartialRule

  /// The rules for a given LHS symbol.
  associatedtype Alternatives: Collection where Alternatives.Element == PartialRule

  /// Returns the right-hand side alternatives for lhs, or an empty collection if lhs is a terminal.
  func alternatives(_ lhs: Symbol) -> Alternatives

  /// Returns true iff `s` derives the null string.
  func isNullable(_ s: Symbol) -> Bool

  /// Returns true iff `t` is empty.
  func isComplete(_ t: PartialRule) -> Bool

  /// Returns the LHS symbol for the rule corresponding to `t`.
  func lhs(_ t: PartialRule) -> Symbol

  /// Returns the next expected symbol of `t`, .
  func postdot(_ t: PartialRule) -> Symbol?
}

struct MultiMap<K: Hashable, V> {
  typealias Storage = Dictionary<K, [V]>

  subscript(k: K) -> [V] {
    set { storage[k] = newValue }
    _modify { yield &storage[k, default: []] }
    _read { yield storage[k, default: []] }
  }

  /// The keys in this MultiMap.
  ///
  /// - Note: the order of these keys is incidental.
  var keys: Storage.Keys {
    get { storage.keys }
  }

  /// The sets of values in this MultiMap.
  ///
  /// - Note: the order of these sets is incidental.
  var values: Storage.Values {
    get { storage.values }
  }

  private(set) var storage: Storage = [:]
}

struct EarleyGrammar<Symbol: Hashable>: AnyEarleyGrammar {
  typealias RuleStore = [Symbol]
  typealias PartialRule = Range<RuleStore.Index>
  typealias Alternatives = [PartialRule]

  func alternatives(_ lhs: Symbol) -> Alternatives { rulesByLHS[lhs] }
  func isNullable(_ s: Symbol) -> Bool { nullables.contains(s) }
  func isComplete(_ rhs: PartialRule) -> Bool { rhs.isEmpty }
  func lhs(_ t: PartialRule) -> Symbol { ruleStore[t.upperBound] }
  func postdot(_ t: PartialRule) -> Symbol? { ruleStore[t].first }

  /// Storage for all the rules.
  private let ruleStore: [Symbol]

  /// The right-hand side alternatives for each nonterminal symbol.
  private let rulesByLHS: MultiMap<Symbol, PartialRule>

  /// The set of symbols that can derive the null string.
  private let nullables: Set<Symbol>

  public init<RawRules: Collection, RHS: Collection>(_ rawRules: RawRules)
    where RawRules.Element == (lhs: Symbol, rhs: RHS), RHS.Element == Symbol
  {
    var rulesByLHS = MultiMap<Symbol, PartialRule>()
    var rulesByRHS = MultiMap<Symbol, PartialRule>()

    var ruleStore: [Symbol] = []
    for (lhs, rhs) in rawRules {
      let start = ruleStore.count
      ruleStore.append(contentsOf: rhs)
      let r = start..<ruleStore.endIndex
      ruleStore.append(lhs)

      rulesByLHS[lhs].append(r)
      for s in rhs { rulesByRHS[s].append(r) }
    }
    self.ruleStore = ruleStore
    self.rulesByLHS = rulesByLHS

    var nullables = Set<Symbol>()
    for (lhs, alternatives) in rulesByLHS.storage {
      if !alternatives.allSatisfy({ !$0.isEmpty }) {
        discoverNullable(lhs)
      }
    }
    self.nullables = nullables

    func discoverNullable(_ s: Symbol) {
      nullables.insert(s)
      for r in rulesByRHS[s] {
        let lhs = ruleStore[r.upperBound]
        if !nullables.contains(lhs) && ruleStore[r].allSatisfy(nullables.contains) {
          discoverNullable(lhs)
        }
      }
    }
  }
}

public struct EarleyParser<G: AnyEarleyGrammar> {
  /// A position in the input.
  typealias SourcePosition = Int

  /// A parse rule being matched.
  struct PartialParse: Hashable {
    /// The positions in ruleStore of yet-to-be recognized RHS symbols.
    var rule: G.PartialRule

    /// The position in the token stream where the partially-parsed input begins.
    let start: SourcePosition

    init(expecting expected: G.PartialRule, at start: SourcePosition) {
      self.rule = expected
      self.start = start
    }

    /// Returns `self`, having advanced the forward by one position.
    func advanced() -> Self { Self(expecting: rule.dropFirst(), at: start) }
  }

  func postdot(_ p: PartialParse) -> G.Symbol? { g.postdot(p.rule) }
  func lhs(_ p: PartialParse) -> G.Symbol { g.lhs(p.rule) }
  
  /// all the partial parses
  var S: Array<Set<PartialParse>> = []
  var g: G
}

/// Initialization and algorithm.
extension EarleyParser {
  /// Recognizes the sequence of symbols in `source` as a parse of `start`.
  public mutating func recognize<Source: Collection>(_ start: G.Symbol, as source: Source )
    where Source.Element == G.Symbol
  {
    let n = source.count
    S.removeAll(keepingCapacity: true)
    S.reserveCapacity(n + 1)
    S.append(contentsOf: repeatElement([], count: n + 1))
    
    for r in g.alternatives(start) {
      S[0].insert(PartialParse(expecting: r, at: 0))
    }

    // Recognize each token over its range in the source.
    for (i, t) in source.enumerated() {
      for p in S[i] {
        if let expected = postdot(p) {
          if t == expected {  // scan
            S[i + 1].insert(p.advanced())
          }
          else { // predict
            for predicted_rhs in g.alternatives(expected) {
              S[i].insert(PartialParse(expecting: predicted_rhs, at: i))  
              if g.isNullable(expected) {
                S[i].insert(p.advanced())
              }
            }
          }
        }
        else { // // complete.
          // TODO: avoid a linear search over everything in S[item.start].
          for q in S[p.start] where postdot(q) == lhs(p) {
            S[i].insert(q.advanced()) 
          }
        }
      }
    }
  }
}
