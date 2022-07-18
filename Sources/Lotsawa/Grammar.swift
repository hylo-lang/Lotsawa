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

internal extension Grammar {
  func lhs(_ r: RuleID) -> Symbol {
    rules[Int(r.ordinal)].lhs
  }

  func rhs(_ r: RuleID) -> Array<Symbol>.SubSequence {
    rules[Int(r.ordinal)].rhs
  }

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
  typealias RewriteSymbol = (position: Int, symbol: Symbol, isNullable: Bool)
  typealias RewriteBuffer = [RewriteSymbol]

  func eliminatingNulls() -> (Self, DiscreteMap<Position, Position>) {
    var cooked = Self()
    cooked.maxSymbol = maxSymbol
    var mapBack = DiscreteMap<Position, Position>()
    let n = nullSymbolSets()

    var buffer: RewriteBuffer = []

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
      cooked.addDenullified(buffer, updating: &mapBack)
    }
    return (cooked, mapBack)
  }

  /// Given a non-nulling rule from a raw grammar with its LHS in `rawRule.first` and the
  /// non-nulling symbols of its RHS in `rawRule.dropFirst()`, adds a denullified rewrite to self,
  /// updating `rawPositions` to reflect the correspondences.
  mutating func addDenullified(
    _ rawRule: RewriteBuffer,
    updating rawPositions: inout DiscreteMap<Position, Position>
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

      // If tail length > 1, synthesize a symbol in lhs2 for tail.  Otherwise, lhs2 is tail.
      let lhs2 = tail.count > 1 ? synthesizedSymbol(for: tail) : tail

      // Create each distinct rule having a non-empty RHS in:
      //   lhs1 -> anchor
      //   lhs1 -> anchor q
      //   lhs1 -> anchor lhs2
      //   lhs1 -> anchor q lhs2
      if !anchor.isEmpty { addRewrite(lhs: lhs1, rhs: anchor) }
      if !q.isEmpty {
        addRewrite(lhs: lhs1, rhs: anchor + q)
        if !lhs2.isEmpty { addRewrite(lhs: lhs1, rhs: anchor + q + lhs2) }
      }
      if !lhs2.isEmpty { addRewrite(lhs: lhs1, rhs: anchor + lhs2) }
      if tail.count <= 1 { break }
      lhs = lhs2
      rhs = tail
    }
  }

  mutating func addRewrittenRule(
    lhs: Symbol, rhs: RewriteBuffer.SubSequence,
    updating rawPositions: inout DiscreteMap<Position, Position>)
  {
    ruleStore.amortizedLinearReserveCapacity(ruleStore.count + rhs.count + 1)
    var remainder = rhs
    while let s = remainder.popFirst() {
      rawPositions.appendMapping(from: .init(ruleStore.count), to: .init(s.position))
      ruleStore.append(s.symbol)
    }
    // FIXME: think about whether we want to append positions for before/after the lhs.
    ruleStore.append(lhs | Symbol.min)
    ruleStart.append(Size(ruleStore.count))
  }

  func symbols() -> (terminals: Set<Symbol>, nonTerminals: Set<Symbol>) {
    let nonTerminals = Set(rules.lazy.map(\.lhs))
    let terminals = Set(rules.lazy.map(\.rhs).joined()).subtracting(nonTerminals)
    return (terminals, nonTerminals)
  }
}
