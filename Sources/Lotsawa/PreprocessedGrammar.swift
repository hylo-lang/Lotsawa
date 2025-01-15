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

  let predictions: MultiMap<Symbol, Chart.Entry>

  /// Creates a preprocessed version of `raw`, ready for recognition.
  public init(_ raw: Grammar<StoredSymbol>) {
    (base, rawPosition, isNullable) = raw.eliminatingNulls()
    rulesByLHS = MultiMap(grouping: base.ruleIDs, by: base.lhs)
    leoPositions = base.leoPositions()
    first = base.firstSymbols()

    /// Returns the chart entry that predicts the start of `r` at earleme 0.
    func prediction(_ r: RuleID) -> Chart.Entry {
      // FIXME: overflow here on 32-bit systems
      .init(
        item: .init(predicting: r, in: base, at: 0, first: first[r]!),
        mainstemIndex: .init(UInt32.max))
    }

    let allSymbols = base.allSymbols()
    var p: [Symbol: Set<Chart.Entry>] = Dictionary(uniqueKeysWithValues: allSymbols.map { ($0, []) })

    var foundPrediction = false
    repeat {
      foundPrediction = false
      for s in allSymbols {
        for r in rulesByLHS[s] {
          let oldCount = p[s]!.count
          // FIXME: overflow here on 32-bit systems
          p[s]!.insert(
            .init(
              item: .init(predicting: r, in: base, at: 0, first: first[r]!),
              mainstemIndex: .init(UInt32.max)))
          p[s]!.formUnion(p[first[r]!]!)
          if p[s]!.count != oldCount { foundPrediction = true }
        }
      }
    }
    while foundPrediction

    predictions = .init(storage: p.mapValues { $0.sorted() })
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
    isNullable: Bool,
    predictions: MultiMap<Symbol, Chart.Entry>
  ) {
    self.base = base
    self.rulesByLHS = rulesByLHS
    self.leoPositions = leoPositions
    self.rawPosition = rawPosition
    self.isNullable = isNullable
    first = base.firstSymbols()
    self.predictions = predictions
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
      isNullable: \(isNullable),
      predictions: \(predictions)
      )
    """
  }
}
