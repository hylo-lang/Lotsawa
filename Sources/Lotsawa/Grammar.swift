/// A collection of parameter types for configuring a grammar.
public protocol GrammarConfig {
  /// A type that can represent the size of the grammar (the total length of all right-hand sides
  /// of the rules plus the number of rules. Requires `Size.max <= Int.max`.
  associatedtype Size: FixedWidthInteger = Int

  /// A type that can represent the number of symbols used in the grammar. Requires `Size.max <=
  /// Int.max`.
  associatedtype Symbol: SignedInteger & FixedWidthInteger = Int
}

/// A collection of Backus-Naur Form (BNF) rules, each defining a symbol
/// on its left-hand side in terms of a string of symbols on its right-hand
/// side.
public struct Grammar<Config: GrammarConfig> {
  /// Storage for all the rules.
  ///
  /// Rules are packed end-to-end, with the RHS symbols in order, followed by the LHS symbol with
  /// its high bit set.
  ///
  /// For example A -> B C is stored as the subsequence [B, C, A | *highbit*].
  private var ruleStore: [Config.Symbol] = []

  /// Where each rule begins in `ruleStore`, in sorted order, plus a sentinel that marks the end of
  /// rule storage.
  private var ruleStart: [Config.Size] = [0]

  /// The greatest symbol value in any rule, or -1 if there are no rules.
  private(set) var maxSymbol: Config.Symbol = -1

  /// Creates an empty instance.
  public init() {  }
}

extension Grammar {
  /// The symbol identifier type (positive values only).
  public typealias Symbol = Config.Symbol

  /// The grammar size representation.
  public typealias Size = Config.Size

  /// A location in the grammar; e.g. the position of a dot in a partially-recognized rule.
  public typealias Position = Config.Size

  /// Returns the size of `self` (the sum of the length of each rule's RHS plus the number of rules,
  /// to account for left-hand side symbols).
  public var size: Int {
    ruleStore.count
  }

  /// A rule identifier for public consumption.
  public struct RuleID: Hashable, Comparable {
    public let ordinal: Size // This could sometimes be a smaller type, but is it worthwhile?

    public static func <(l: Self, r: Self) -> Bool { l.ordinal < r.ordinal }
  }

  /// The identifiers of all rules.
  public var ruleIDs: LazyMapSequence<Range<Int>, RuleID> {
    ruleStart.indices.dropLast().lazy.map { i in RuleID(ordinal: Size(i)) }
  }

  /// A Backus-Naur Form (BNF) rule, or production.
  public struct Rule {
    /// The RHS symbols followed by the LHS symbol, with its high bit set.
    internal let storage: Array<Symbol>.SubSequence

    /// The symbol to be recognized.
    public var lhs: Symbol { storage.last! & ~Symbol.min }

    /// The sequence of symbols that lead to recognition of the `lhs`.
    public var rhs: Array<Symbol>.SubSequence { storage.dropLast() }
  }

  /// A random-access collection of Rules.
  public typealias Rules = LazyMapSequence<Range<Int>, Rule>

  /// The collection of all rules in the grammar.
  public var rules: Rules {
    ruleStart.indices.dropLast().lazy.map {
      i in Rule(storage: ruleStore[Int(ruleStart[i])..<Int(ruleStart[i + 1])])
    }
  }

  /// Adds a rule recognizing `rhs` as `lhs`.
  ///
  /// - Precondition: `lhs` and all elements of `rhs` are non-negative; the resulting size of the
  ///   grammar is representable by `Size`.
  @discardableResult
  public mutating func addRule<RHS: Collection>(lhs: Symbol, rhs: RHS) -> RuleID
    where RHS.Element == Symbol
  {
    precondition(lhs >= 0)
    precondition(rhs.allSatisfy { s in s >= 0 })
    maxSymbol = max(maxSymbol, max(lhs, rhs.max() ?? -1))
    ruleStore.amortizedLinearReserveCapacity(ruleStore.count + rhs.count + 1)
    ruleStore.append(contentsOf: rhs)
    ruleStore.append(lhs | Symbol.min)
    ruleStart.append(Size(ruleStore.count))
    return RuleID(ordinal: Size(ruleStart.count - 2))
  }
}

extension Grammar {
  /// Returns the LHS of `r`.
  func lhs(_ r: RuleID) -> Symbol {
    rules[Int(r.ordinal)].lhs
  }

  /// Returns the RHS of `r`.
  func rhs(_ r: RuleID) -> Array<Symbol>.SubSequence {
    rules[Int(r.ordinal)].rhs
  }

  /// Returns the dot position at the beginning of `r`'s RHS.
  func rhsStart(_ r: RuleID) -> Position {
    Position(rules[Int(r.ordinal)].rhs.startIndex)
  }

  /// Returns the ID of the rule containing `p`.
  public func containingRule(_ p: Position) -> RuleID {
    RuleID(ordinal: Size(ruleStart.partitionPoint { y in y > p } - 1))
  }

  /// Adds a new unique symbol to self and returns it.
  ///
  /// - Precondition: `maxSymbol < Symbol.max`
  mutating func newSymbol() -> Symbol {
    maxSymbol += 1
    return maxSymbol
  }

  /// Returns the postdot symbol corresponding to a dot at `p`, or nil if represents a completion.
  func postdot(at p: Position) -> Symbol? {
    ruleStore[Int(p)] < 0 ? nil : ruleStore[Int(p)]
  }

  /// Returns the LHS recognized when a dot appears at `p`, or nil if `p` doesn't represent a
  /// completion.
  func recognized(at p: Position) -> Symbol? {
    ruleStore[Int(p)] >= 0 ? nil : ruleStore[Int(p)] & ~Symbol.min
  }
}

/// A configuration that can be used to represent just about any logical grammar, but may waste
/// storage space and thus cost some performance due to poor locality-of-reference.
public struct DefaultGrammarConfig: GrammarConfig {}

/// A grammar type that represent just about any logical grammar, but may waste
/// storage space and thus cost some performance due to poor locality-of-reference.
public typealias DefaultGrammar = Grammar<DefaultGrammarConfig>

/// Preprocessing support
extension Grammar {
  /// A non-nulling symbol involved in rule rewriting, including its position in the original rule
  /// and whether it is a nullable symbol.
  typealias RewriteSymbol = (position: Int, symbol: Symbol, isNullable: Bool)

  /// A sequence of symbols with auxilliary information used in rewriting grammar rules.
  typealias RewriteFragment = Array<RewriteSymbol>.SubSequence

  /// Returns a version of `self` with all nullable symbols removed, along with a mapping from
  /// positions in the rewritten grammar to corresponding positions in `self`.
  ///
  /// - Nulling symbols in `self` do not appear in the result:
  /// - All other symbols in `self` appear in the result, and derive the same non-empty terminal
  ///   strings.
  /// - Naturally, no symbols in the result derive the empty string.
  /// - The result contains some newly-synthesized symbols whose values are greater than
  ///   `self.maxSymbol`.
  /// - Each position in the result that is not at the end of a RHS corresponds to a position in
  ///   `self` where the same prefix of a given `self`-rule's non-nulling RHS elements have been
  ///   recognized.
  func eliminatingNulls() -> (Self, DiscreteMap<Position, Position>) {
    var cooked = Self()
    cooked.maxSymbol = maxSymbol
    var mapBack = DiscreteMap<Position, Position>()
    let n = nullSymbolSets()

    var buffer: [RewriteSymbol] = []

    for r in rules {
      // Initialize the buffer to the LHS plus non-nulling symbols on the RHS (with positions).
      let nonNullingRHS
        = r.rhs.indices.lazy.map { i in
          (position: i, symbol: r.rhs[i], isNullable: n.nullable.contains(r.rhs[i]))
        }
        .filter { e in !n.nulling.contains(e.symbol) }
      if nonNullingRHS.isEmpty { continue }

      buffer.replaceSubrange(
        buffer.startIndex...,
        with: CollectionOfOne((position: 0, symbol: r.lhs, isNullable: false)))

      buffer.append(contentsOf: nonNullingRHS)
      cooked.addDenullified(buffer[...], updating: &mapBack)
    }
    return (cooked, mapBack)
  }

  /// Given a non-nulling rule from a raw grammar with its LHS in `rawRule.first` and the
  /// non-nulling symbols of its RHS in `rawRule.dropFirst()`, adds a denullified rewrite to self,
  /// updating `rawPositions` to reflect the correspondences.
  mutating func addDenullified(
    _ rawRule: RewriteFragment,
    updating rawPositions: inout DiscreteMap<Position, Position>
  ) {
    // FIXME (efficiency): this function currently allocates and concatenates new fragments.  It
    // would be better do all that work directly in the `RewriteBuffer`, even if that meant
    // sometimes growing it.  That would complicate this code a bit, so might not be worth it.

    // Using fragments even when we know we have a single symbol (e.g. lhs) simplifies some code.
    var lhs = rawRule.prefix(1)
    var rhs = rawRule.dropFirst()

    // The longest suffix of nullable symbols.
    let nullableSuffix = rhs.suffix(while: \.isNullable)

    // Rewrite chunks of the RHS
    while !rhs.isEmpty {
      guard let qStart = rhs.firstIndex(where: \.isNullable ) else {
        // Trivial case; there are no nullable symbols
        addRewrittenRule(lhs: lhs, rhs: rhs, updating: &rawPositions)
        return
      }

      // Break the RHS into (`head`, `anchor`, `q`, `tail`)
      //
      // where:
      // 1. `q` is the leftmost nullable symbol.
      // 2. `anchor` is 1 symbol iff `q` is not the leftmost symbol and `tail` is nullable;
      //    otherwise `anchor` is empty.
      //
      //    Explanation: When `head` is nonempty, we'll factor out a common prefix, creating [`lhs`
      //    -> `head` `lhs1`] where `lhs1` is a synthesized continuation symbol, which must not
      //    itself be nullable (since our goal is to eliminate those). If a non-nullable `anchor`
      //    can be found, it must therefore be included in `lhs1`.  However, when `q` is the
      //    leftmost symbol and `tail` is nullable, no anchor is needed, because `lhs` itself
      //    started out nullable, and the case where `lhs1` would have been null is dealt with by
      //    omitting `lhs` on the RHS of other rewritten rules.
      let tailIsNullable = qStart >= nullableSuffix.startIndex
      let anchorWidth = qStart > rhs.startIndex && tailIsNullable ? 1 : 0
      let head = rhs[..<(qStart - anchorWidth)]
      let anchor = rhs[..<qStart].suffix(anchorWidth)
      let q = rhs[qStart...].prefix(1)
      let tail = rhs[qStart...].dropFirst()

      // If head is non-empty synthesize a symbol in lhs1 for head's continuation, adding
      // lhs -> head lhs1.  Otherwise, just use lhs as lhs1.
      let lhs1: RewriteFragment
      if head.isEmpty { lhs1 = lhs }
      else {
        lhs1 = synthesizedLHS(for: rhs[anchor.startIndex...])
        addRewrittenRule(lhs: lhs, rhs: head + lhs1, updating: &rawPositions)
      }

      // If tail length > 1, synthesize a symbol in lhs2 for tail.  Otherwise, lhs2 is tail itself.
      let lhs2 = tail.count > 1 ? synthesizedLHS(for: tail) : tail

      if tailIsNullable {
        if !anchor.isEmpty {
          addRewrittenRule(lhs: lhs1, rhs: anchor, updating: &rawPositions)
        }
        addRewrittenRule(lhs: lhs1, rhs: anchor + q, updating: &rawPositions)
      }
      if !lhs2.isEmpty {
        addRewrittenRule(lhs: lhs1, rhs: anchor + q + lhs2, updating: &rawPositions)
        addRewrittenRule(lhs: lhs1, rhs: anchor + lhs2, updating: &rawPositions)
      }
      if tail.count <= 1 { break }
      lhs = lhs2
      rhs = tail
    }

    /// Returns a single-symbol fragment appropriate for the LHS of a rule having `rhs` as its RHS.
    func synthesizedLHS(for rhs: RewriteFragment) -> RewriteFragment {
      [(position: rhs.first!.position, symbol: newSymbol(), isNullable: false)][...]
    }
  }

  /// Adds a rule deriving `rhs` from `lhs`.
  ///
  /// - Precondition: `lhs` contains exactly one symbol.
  mutating func addRewrittenRule(
    lhs: RewriteFragment, rhs: RewriteFragment,
    updating rawPositions: inout DiscreteMap<Position, Position>)
  {
    precondition(lhs.count == 1)
    ruleStore.amortizedLinearReserveCapacity(ruleStore.count + rhs.count + 1)
    var remainder = rhs
    while let s = remainder.popFirst() {
      rawPositions.appendMapping(from: .init(ruleStore.count), to: .init(s.position))
      ruleStore.append(s.symbol)
    }
    // TODO: think about whether we want to append positions for before/after the lhs.
    ruleStore.append(lhs.first!.symbol | Symbol.min)
    ruleStart.append(Size(ruleStore.count))
  }

  func symbols() -> (terminals: Set<Symbol>, nonTerminals: Set<Symbol>) {
    let nonTerminals = Set(rules.lazy.map(\.lhs))
    let terminals = Set(rules.lazy.map(\.rhs).joined()).subtracting(nonTerminals)
    return (terminals, nonTerminals)
  }
}

extension Grammar {
  internal init(ruleStore: [Config.Symbol], ruleStart: [Config.Size], maxSymbol: Config.Symbol) {
    self.ruleStore = ruleStore
    self.ruleStart = ruleStart
    self.maxSymbol = maxSymbol
  }

  func serialized() -> String {
    """
    Grammar<\(Config.self)>(
      ruleStore: \(ruleStore),
      ruleStart: \(ruleStart),
      maxSymbol: \(maxSymbol))
    """
  }
}

extension Grammar {
  /// Returns the position, for each right-recursive rule, of its last RHS symbol.
  ///
  /// - Precondition: `self` contains no nullable symbols.
  func leoPositions() -> Set<Position> {
    var result = Set<Position>()
    var rightmostDerivable = AdjacencyMatrix()

    for r in rules {
      rightmostDerivable.addEdge(from: Int(r.lhs), to: Int(r.rhs.last!))
    }
    rightmostDerivable.formTransitiveClosure()
    for r in rules {
      if rightmostDerivable.hasEdge(from: Int(r.rhs.last!), to: Int(r.lhs)) {
        result.insert(Position(r.rhs.dropLast().endIndex))
      }
    }
    return result
  }
}
