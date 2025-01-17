struct Prediction: Comparable, Hashable {
  let original: Chart.ItemID
  let advanced: Chart.ItemID

  static func == (l: Self, r: Self) -> Bool { l.original == r.original }
  static func < (l: Self, r: Self) -> Bool { l.original < r.original }

  func hash(into hasher: inout Hasher) {
    original.hash(into: &hasher)
  }
}

typealias PredictionSet = UnsafeBufferPointer<Prediction>.SubSequence

internal struct PredictionMemo: Hashable {

  typealias SetStorage = [Prediction]
  typealias PredictionSetID = Range<SetStorage.Index>
  var setStorage: SetStorage = []
  // Where each earleme's set starts/ends.
  var setInEarleme: [PredictionSetID] = []
  var predictionsFromSymbols: [Set<Symbol>: PredictionSetID] = [:]
  var identity: [Set<Prediction>: PredictionSetID] = [:]
  var predictedSymbolsInCurrentEarleme: Set<Symbol> = []

  init<StoredSymbol: SignedInteger & FixedWidthInteger>(
    grammar g: Grammar<StoredSymbol>,
    rulesByLHS: MultiMap<Symbol, RuleID>,
    first: [RuleID: Symbol]
  ) {
    let allSymbols = g.allSymbols()
    // Start with an empty set for each symbol
    var p = Dictionary<Symbol, Set<Prediction>>(
      uniqueKeysWithValues: allSymbols.map { ($0, Set<Prediction>()) })

    var foundPrediction = false
    repeat {
      foundPrediction = false
      for s0 in allSymbols {
        let s = s0
        for r in rulesByLHS[s0] {
          let oldCount = p[s]!.count
          let x = Chart.ItemID(predicting: r, in: g, at: 0, first: first[r]!)
          p[s]!.insert(.init(original: x, advanced: x.advanced(in: g)))
          p[s]!.formUnion(p[first[r]!]!)
          if p[s]!.count != oldCount { foundPrediction = true }
        }
      }
    }
    while foundPrediction

    for (k, v) in p {
      _ = remember(Set(k), predicts: v)
    }
  }

  private mutating func remember(_ predictor: Set<Symbol>, predicts predicted: Set<Prediction>) -> PredictionSetID {
    if let id = identity[predicted] {
      predictionsFromSymbols[predictor] = id
      return id
    }
    let start = setStorage.count
    setStorage.append(contentsOf: predicted.sorted())
    let newID = start..<setStorage.count
    predictionsFromSymbols[predictor] = newID
    identity[predicted] = newID
    return newID
  }

  mutating func reset() {
    predictedSymbolsInCurrentEarleme = []
    setInEarleme.removeAll(keepingCapacity: true)
  }

  mutating func predict(_ s: Symbol) {
    predictedSymbolsInCurrentEarleme.insert(s)
  }

  func predictions(for s: Set<Symbol>) -> PredictionSet? {
    guard let storageRegion = predictionsFromSymbols[s] else { return nil }
    return setStorage.withUnsafeBufferPointer { $0[storageRegion] }
  }

  func predictions(inEarleme i: Int) -> PredictionSet {
    return setStorage.withUnsafeBufferPointer { $0[setInEarleme[i]] }
  }

  func predictions(inEarleme i: Int, startingWith transitionSymbol: Symbol) -> PredictionSet {
    let ithSet = predictions(inEarleme: i)
    let k = Chart.ItemID.transitionKey(transitionSymbol)

    let j = ithSet.partitionPoint { d in d.original.transitionKey >= k }
    let items = ithSet[j...]
    return items.prefix(while: { x in x.original.symbolKey == transitionSymbol.id })
  }

  mutating func finishEarleme() {
    defer {  predictedSymbolsInCurrentEarleme.removeAll(keepingCapacity: true) }

    if let currentPredictions = predictionsFromSymbols[predictedSymbolsInCurrentEarleme] {
      setInEarleme.append(currentPredictions)
      return
    }

    let currentPredictions: Set<Prediction> = predictedSymbolsInCurrentEarleme.map {
      predictions(for: Set($0))!
    }.reduce(into: Set()) { $0.formUnion($1) }

    let newID = remember(predictedSymbolsInCurrentEarleme, predicts: currentPredictions)
    setInEarleme.append(newID)
  }
}
