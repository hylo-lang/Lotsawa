public struct PreprocessedGrammar<StoredSymbol: SignedInteger & FixedWidthInteger> {
  typealias Position = Grammar<StoredSymbol>.Position

  let base: Grammar<StoredSymbol>
  let rawPosition: DiscreteMap<Position, Position>
  let rulesByLHS: MultiMap<Symbol, RuleID>
  /// The position, for each right-recursive rule, of its last RHS symbol.
  let leoPositions: Set<Position>
  let isNullable: Bool

  public init(_ raw: Grammar<StoredSymbol>) {
    (base, rawPosition, isNullable) = raw.eliminatingNulls()
    rulesByLHS = MultiMap(grouping: base.ruleIDs, by: base.lhs)
    leoPositions = base.leoPositions()
  }
}

extension PreprocessedGrammar {
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
