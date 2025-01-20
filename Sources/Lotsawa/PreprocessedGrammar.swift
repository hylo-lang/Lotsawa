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

  let first: [RuleID: Symbol]

  let predictionMemo: PredictionMemo

  /// Creates a preprocessed version of `raw`, ready for recognition.
  public init(_ raw: Grammar<StoredSymbol>, language: DebugGrammar? = nil) {
    (base, rawPosition, isNullable) = raw.eliminatingNulls()
    rulesByLHS = MultiMap(grouping: base.ruleIDs, by: base.lhs)
    leoPositions = base.leoPositions()
    first = base.firstSymbols()

    /// Returns the chart entry that predicts the start of `r` at earleme 0.
    func prediction(_ r: RuleID) -> Chart.ItemID {
      .init(predicting: r, in: base, at: 0, first: first[r]!)
    }

    predictionMemo = PredictionMemo(grammar: base, rulesByLHS: rulesByLHS, first: first, language: language)
  }
/*
  func rhsStartAndPostdot(_ r: RuleID) -> (Position, Symbol) {
    (base.ruleStart[Int(r.ordinal)], first[r])
  }
 */
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
    first = base.firstSymbols()
    self.predictionMemo = PredictionMemo(grammar: base, rulesByLHS: rulesByLHS, first: first)
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

extension Set {
  init(_ s: Element) { self = .init(CollectionOfOne(s)) }
}
