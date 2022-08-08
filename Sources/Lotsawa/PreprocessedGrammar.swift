public struct PreprocessedGrammar<Config: GrammarConfig> {
  typealias Position = Grammar<Config>.Position

  let base: Grammar<Config>
  let rawPosition: DiscreteMap<Position, Position>

  init(_ raw: Grammar<Config>) {
    (base, rawPosition) = raw.eliminatingNulls()
  }
}

extension PreprocessedGrammar {
  internal init(base: Grammar<Config>, rawPosition: DiscreteMap<Position, Position>) {
    self.base = base
    self.rawPosition = rawPosition
  }

  func serialized() -> String {
    """
    PreprocessedGrammar<\(Config.self)>(
      base: \(base.serialized()),
      rawPosition: \(rawPosition.serialized()))
    """
  }
}
