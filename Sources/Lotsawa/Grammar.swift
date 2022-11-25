/// A symbol in the grammar with a 14-bit ID.
public struct Symbol: Hashable, Comparable {
  /// The identity of an instance.
  public typealias ID = Int16

  /// Creates an instance with the given `id`.
  ///
  /// - Precondition: 0 ≤ id < (1 << 14).
  public init(id: ID) {
    precondition(id >= 0 && id <= Self.maxID)
    self.id = id
  }

  /// The ID of `self`.
  public private(set) var id: ID

  /// Returns `true` iff `l` must precede `r` in a sort based on `id`.
  public static func <(l: Self, r: Self) -> Bool { l.id < r.id }

  public static var maxID: ID { (1 << 14) - 1 }
}

// A type that can represent the size of any grammar.
public typealias GrammarSize = UInt16

/// A rule identifier for public consumption.
public struct RuleID: Hashable, Comparable {
  public let ordinal: GrammarSize // This could sometimes be a smaller type, but is it worthwhile?

  /// Returns `true` iff `l` must precede `r` in a sort based on `ordinal`.
  public static func <(l: Self, r: Self) -> Bool { l.ordinal < r.ordinal }
}


/// A collection of Backus-Naur Form (BNF) rules, each defining a symbol
/// on its left-hand side in terms of a string of symbols on its right-hand
/// side.
///
/// - Parameter StoredSymbol: storage representation of `Symbol.id` values in this grammar.
public struct Grammar<StoredSymbol: SignedInteger & FixedWidthInteger> {

  /// Storage for all the rules.
  ///
  /// Rules are packed end-to-end, with the RHS symbols in order, followed by the LHS symbol with
  /// its high bit set.
  ///
  /// For example A -> B C is stored as the subsequence [B, C, A | *highbit*].
  private(set) var ruleStore: [StoredSymbol] = []

  /// Where each rule begins in `ruleStore`, in sorted order, plus a sentinel that marks the end of
  /// rule storage.
  private var ruleStart: [Size] = [0]

  /// The greatest symbol ID value in any rule, or -1 if there are no rules.
  private(set) var maxSymbolID: Symbol.ID = -1

  let startSymbol: Symbol

  /// Creates an empty instance intended (when rules have been added) to recognize `startSymbol`.
  public init(recognizing startSymbol: Symbol) { self.startSymbol = startSymbol }
}

extension Grammar {
  /// A representation of the size of the grammar (the total length of all right-hand sides
  /// of the rules plus the number of rules).
  public typealias Size = GrammarSize

  /// A location in the grammar; e.g. the position of a dot in a partially-recognized rule.
  public typealias Position = GrammarSize

  /// Returns the size of `self` (the sum of the lengths of each rule's RHS and LHS).
  public var size: Size {
    Size(ruleStore.count)
  }

  /// The identifiers of all rules.
  public var ruleIDs: some RandomAccessCollection<RuleID> {
    ruleStart.indices.dropLast().lazy.map { i in RuleID(ordinal: Size(i)) }
  }

  /// Returns the LHS symbol represented by the value `stored` found in `ruleStore`.
  ///
  /// Symbols on the LHS of a rule have a special representation in `ruleStore`.
  static func lhsSymbol(_ stored: StoredSymbol) -> Symbol {
    assert(stored < 0)
    return Symbol(id: ~Symbol.ID(stored))
  }

  /// A Backus-Naur Form (BNF) rule, or production.
  public struct Rule {
    /// The RHS symbols followed by the LHS symbol, with its high bit set.
    internal let storage: Array<StoredSymbol>.SubSequence

    /// The symbol to be recognized.
    public var lhs: Symbol { Grammar.lhsSymbol(storage.last!) }

    public typealias RHS = LazyMapSequence<Array<StoredSymbol>.SubSequence, Symbol>

    /// The sequence of symbols that lead to recognition of the `lhs`.
    public var rhs: RHS {
      storage.dropLast().lazy.map { x in Symbol(id: Symbol.ID(x)) }
    }
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
    maxSymbolID = max(maxSymbolID, max(lhs.id, rhs.lazy.map(\.id).max() ?? -1))
    ruleStore.amortizedLinearReserveCapacity(ruleStore.count + rhs.count + 1)
    ruleStore.append(contentsOf: rhs.lazy.map { s in StoredSymbol(s.id) })
    ruleStore.append(StoredSymbol(~lhs.id))
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
  func rhs(_ r: RuleID) -> Rule.RHS {
    rules[Int(r.ordinal)].rhs
  }

  /// Returns the dot position at the beginning of `r`'s RHS.
  func rhsStart(_ r: RuleID) -> Position {
    Position(rules[Int(r.ordinal)].rhs.startIndex)
  }

  /// Returns the ID of the rule containing `p`.
  public func rule(containing p: Position) -> RuleID {
    RuleID(ordinal: Size(ruleStart.partitionPoint { y in y > p } - 1))
  }

  /// Adds a new unique symbol to self and returns it.
  ///
  /// - Precondition: `maxSymbol < Symbol.max`
  mutating func newSymbol() -> Symbol {
    maxSymbolID += 1
    return Symbol(id: maxSymbolID)
  }

  /// Returns the postdot symbol corresponding to a dot at `p`, or nil if `p` represents a completion.
  func postdot(at p: Position) -> Symbol? {
    let s = ruleStore[Int(p)]
    return s < 0 ? nil : Symbol(id: Symbol.ID(s))
  }

  /// Returns the predot symbol corresponding to a dot at `p`, or nil if `p` represents a prediction.
  func predot(at p: Position) -> Symbol? {
    if p == 0 { return nil }
    return postdot(at: p - 1)
  }

  /// Returns the LHS recognized when a dot appears at `p`, or nil if `p` doesn't represent a
  /// completion.
  func recognized(at p: Position) -> Symbol? {
    let s = ruleStore[Int(p)]
    return s >= 0 ? nil : Self.lhsSymbol(s)
  }
}

/// A grammar type that represent just about any logical grammar, but may waste
/// storage space and thus cost some performance due to poor locality-of-reference.
public typealias DefaultGrammar = Grammar<Symbol.ID>

/// Preprocessing support
extension Grammar {
  /// A non-nulling symbol involved in rule rewriting, including its position in the original rule
  /// and whether it is a nullable symbol.
  typealias RewriteSymbol = (position: Int, symbol: Symbol, isNullable: Bool)

  /// A sequence of symbols with auxilliary information used in rewriting grammar rules.
  typealias RewriteFragment = Array<RewriteSymbol>.SubSequence

  /// Returns a version of `self` with all nullable symbols removed, along with a mapping from
  /// positions in the rewritten grammar to corresponding positions in `self`, and an indication of
  /// whether `self.startSymbol` is nullable.
  ///
  /// - Nulling symbols in `self` do not appear in the result:
  /// - All other symbols in `self` appear in the result, and derive the same non-empty terminal
  ///   strings as in `self`.
  /// - Naturally, no symbols in the result derive the empty string.
  /// - The result contains some newly-synthesized symbols whose values are greater than
  ///   `self.maxSymbol`.
  /// - Each position in the result that is not at the end of a RHS corresponds to a position in
  ///   `self` where the same prefix of a given `self`-rule's non-nulling RHS elements have been
  ///   recognized.
  func eliminatingNulls() -> (Self, DiscreteMap<Position, Position>, isNullable: Bool) {
    var cooked = Self(recognizing: startSymbol)
    cooked.maxSymbolID = maxSymbolID
    var rawPositions = DiscreteMap<Position, Position>()
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
      cooked.addDenullified(buffer[...], updating: &rawPositions)
    }
    return (cooked, rawPositions, n.nullable.contains(startSymbol))
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

  /// Adds a rule deriving `rhs` from `lhs`, registering correspondences between positions in `self`
  /// and those in the un-denullified grammar in `rawPositions`.
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
      rawPositions.appendMapping(from: GrammarSize(ruleStore.count), to: GrammarSize(s.position))
      ruleStore.append(StoredSymbol(s.symbol.id))
    }
    // TODO: think about whether we want to append positions for before/after the lhs.
    ruleStore.append(StoredSymbol(~lhs.first!.symbol.id))
    ruleStart.append(Size(ruleStore.count))
  }

  func symbols() -> (terminals: Set<Symbol>, nonTerminals: Set<Symbol>) {
    let nonTerminals = Set(rules.lazy.map(\.lhs))
    let terminals = Set(rules.lazy.map(\.rhs).joined()).subtracting(nonTerminals)
    return (terminals, nonTerminals)
  }
}

extension Grammar {
  internal init(
    ruleStore: [StoredSymbol], ruleStart: [GrammarSize], maxSymbolID: Symbol.ID, startSymbol: Symbol
  ) {
    self.ruleStore = ruleStore
    self.ruleStart = ruleStart
    self.maxSymbolID = maxSymbolID
    self.startSymbol = startSymbol
  }

  func serialized() -> String {
    """
    Grammar<\(StoredSymbol.self)>(
      ruleStore: \(ruleStore),
      ruleStart: \(ruleStart),
      maxSymbolID: \(maxSymbolID)
      startSymbol: \(startSymbol))
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
      rightmostDerivable.addEdge(from: Int(r.lhs.id), to: Int(r.rhs.last!.id))
    }
    rightmostDerivable.formTransitiveClosure()
    for r in rules {
      if rightmostDerivable.hasEdge(from: Int(r.rhs.last!.id), to: Int(r.lhs.id)) {
        result.insert(Position(r.rhs.dropLast().endIndex))
      }
    }
    return result
  }
}
