public struct PreprocessedGrammar<Config: GrammarConfig> {
  typealias Position = Grammar<Config>.Position
  typealias RuleID = Grammar<Config>.RuleID
  typealias Symbol = Grammar<Config>.Symbol

  let base: Grammar<Config>
  let rawPosition: DiscreteMap<Position, Position>
  let rulesByLHS: MultiMap<Symbol, RuleID>
  /// The position, for each right-recursive rule, of its last RHS symbol.
  let leoPositions: Set<Position>

  public init(_ raw: Grammar<Config>) {
    (base, rawPosition) = raw.eliminatingNulls()
    rulesByLHS = MultiMap(grouping: base.ruleIDs, by: base.lhs)
    leoPositions = raw.leoPositions()
  }
}

extension PreprocessedGrammar {
  internal init(
    base: Grammar<Config>,
    rulesByLHS: MultiMap<Symbol, RuleID>,
    leoPositions: Set<Position>,
    rawPosition: DiscreteMap<Position, Position>
  ) {
    self.base = base
    self.rulesByLHS = rulesByLHS
    self.leoPositions = leoPositions
    self.rawPosition = rawPosition
  }

  func serialized() -> String {
    """
    PreprocessedGrammar<\(Config.self)>(
      base: \(base.serialized()),
      rulesByLHS: \(rulesByLHS.storage),
      rawPosition: \(rawPosition.serialized()))
      self.leoPositions = \(leoPositions))
    """
  }
}
