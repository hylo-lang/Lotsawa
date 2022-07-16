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
  private var maxSymbol: Config.Symbol = -1

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
}

/// A configuration that can be used to represent just about any logical grammar, but may waste
/// storage space and thus cost some performance due to poor locality-of-reference.
public struct DefaultGrammarConfig: GrammarConfig {}

/// A grammar type that represent just about any logical grammar, but may waste
/// storage space and thus cost some performance due to poor locality-of-reference.
public typealias DefaultGrammar = Grammar<DefaultGrammarConfig>
