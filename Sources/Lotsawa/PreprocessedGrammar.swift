/// A grammar after preprocessing for recognition.
public struct PreprocessedGrammar<StoredSymbol: SignedInteger & FixedWidthInteger> {
  /// A position in `Self`.
  typealias Position = Grammar<StoredSymbol>.Position

  /// The underlying raw grammar.
  let base: Grammar<StoredSymbol>

  /// A map from position in `self` to corresponding position in `base`.
  let rawPosition: DiscreteMap<Position, Position>

  /// The grammar rules, grouped by LHS symbol.
  let rulesByLHS: MultiMap<Symbol, RuleID>

  /// The position, for each right-recursive rule, of its last RHS symbol.
  let leoPositions: Set<Position>

  /// True iff the empty string is a complete parse of the start symbol.
  let isNullable: Bool

  /// Creates a preprocessed version of `raw`, ready for recognition.
  public init(_ raw: Grammar<StoredSymbol>) {
    (base, rawPosition, isNullable) = raw.eliminatingNulls()
    rulesByLHS = MultiMap(grouping: base.ruleIDs, by: base.lhs)
    leoPositions = base.leoPositions()
  }
}

extension PreprocessedGrammar {
  /// Creates an instance with the given stored properties.
  internal init(
    base: Grammar<StoredSymbol>,
    rulesByLHS: MultiMap<Symbol, RuleID>,
    leoPositions: Set<Position>,
    rawPosition: DiscreteMap<Position, Position>,
    isNullable: Bool
  ) {
    self.base = base
    self.rulesByLHS = rulesByLHS
    self.leoPositions = leoPositions
    self.rawPosition = rawPosition
    self.isNullable = isNullable
  }

  /// Returns a complete string representation of `self` from which it
  /// could in principle be reconstructed.
  func serialized() -> String {
    """
    PreprocessedGrammar<\(StoredSymbol.self)>(
      base: \(base.serialized()),
      rulesByLHS: \(rulesByLHS.storage),
      rawPosition: \(rawPosition.serialized()),
      leoPositions: \(leoPositions),
      isNullable: \(isNullable)
      )
    """
  }
}
