typealias PredictionSet = [Symbol: [Chart.ItemID]]
typealias PredictionsFromSymbols = [Set<Symbol>: PredictionSet]

extension PredictionSet {
  mutating func formUnion(_ other: Self) {
    for (k, v) in other {
      self[k] = Array(Set(v).union(self[k] ?? [])).sorted()
    }
  }
}

internal struct PredictionMemo: Hashable {
  var setInEarleme: [PredictionSet] = []
  var predictionsFromSymbols: PredictionsFromSymbols
  private var interned: Set<PredictionSet> = []
  var predictedSymbolsInCurrentEarleme: Set<Symbol> = []

  init(seed: PredictionsFromSymbols) {
    predictionsFromSymbols = seed
  }

  mutating func predict(_ s: Symbol) {
    predictedSymbolsInCurrentEarleme.insert(s)
  }

  mutating func finishEarleme() {
    defer {  predictedSymbolsInCurrentEarleme.removeAll(keepingCapacity: true) }

    if let currentPredictions = predictionsFromSymbols[predictedSymbolsInCurrentEarleme] {
      setInEarleme.append(currentPredictions)
      return
    }

    var currentPredictions = predictedSymbolsInCurrentEarleme.map {
      predictionsFromSymbols[Set($0)]!
    }.reduce(into: PredictionSet()) { $0.formUnion($1) }

    currentPredictions = interned.insert(currentPredictions).memberAfterInsert
    predictionsFromSymbols[predictedSymbolsInCurrentEarleme] = currentPredictions
    setInEarleme.append(currentPredictions)
  }
}
