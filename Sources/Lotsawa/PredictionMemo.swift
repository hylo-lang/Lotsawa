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
typealias PredictionSetID = Int

let emptyPredictionSetID: PredictionSetID = 0
struct PredictionMemo: Hashable {

  typealias SetStorage = [Prediction]
  typealias StorageRegion = Range<SetStorage.Index>
  var setStorage: SetStorage = []
  // Where each earleme's set starts/ends.
  var setStart: [Int] = [0, 0]
  var predictionsFromSymbols: [Set<Symbol>: PredictionSetID] = [[]:0]
  var identity: [Set<Prediction>: PredictionSetID] = [[]: emptyPredictionSetID]
  var predictedSymbolsInCurrentEarleme: Set<Symbol> = []
  var language: Incidental<DebugGrammar?>

  init<StoredSymbol: SignedInteger & FixedWidthInteger>(
    grammar g: Grammar<StoredSymbol>,
    rulesByLHS: MultiMap<Symbol, RuleID>,
    first: [RuleID: Symbol],
    language: DebugGrammar? = nil
  ) {
    self.language = .init(language)
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
    print(
      "memoizing predictions for {",
      predictor.sorted().map { s in
        language.value.map { $0.text(s) } ?? "\(s.id)" }
        .joined(separator: ", "), "} = {\n ",
      predicted.sorted().map(\.original.dotPosition)
        .map { dot in language.value.map { $0.dottedText(dot) } ?? "\(dot)"}
        .joined(separator: "\n  "),
      "}\n"
    )
    if let id = identity[predicted] {
      predictionsFromSymbols[predictor] = id
      return id
    }
    let newID = setStart.count
    setStorage.append(contentsOf: predicted.sorted())
    setStart.append(setStorage.count)
    predictionsFromSymbols[predictor] = newID
    identity[predicted] = newID
    assert(predictions(newID).elementsEqual(predicted.sorted()))
    return newID
  }

  mutating func reset() {
    predictedSymbolsInCurrentEarleme = []
  }

  mutating func predict(_ s: Symbol) {
    predictedSymbolsInCurrentEarleme.insert(s)
  }

  func predictions(for s: Set<Symbol>) -> PredictionSet? {
    guard let id = predictionsFromSymbols[s] else { return nil }
    return predictions(id)
  }

  func predictions(_ id: PredictionSetID) -> PredictionSet {
    assert(id + 1 < setStart.count)
    let storageRegion = setStart.withUnsafeBufferPointer { $0[id]..<$0[id + 1]  }
    assert(setStorage.indices.contains(storageRegion))
    return setStorage.withUnsafeBufferPointer { $0[storageRegion] }
  }

  func predictions(
    _ id: PredictionSetID, startingWith transitionSymbol: Symbol
  ) -> PredictionSet {
    let ithSet = predictions(id)
    let k = Chart.ItemID.transitionKey(transitionSymbol)

    let j = ithSet.partitionPoint { d in d.original.transitionKey >= k }
    let items = ithSet[j...]
    return items.prefix(while: { x in x.original.symbolKey == transitionSymbol.id })
  }

  mutating func finishEarleme() -> Chart.ItemID {
    defer {  predictedSymbolsInCurrentEarleme.removeAll(keepingCapacity: true) }

    if let currentPredictions = predictionsFromSymbols[predictedSymbolsInCurrentEarleme] {
      return .init(predictionSet: currentPredictions)
    }

    let currentPredictions: Set<Prediction> = predictedSymbolsInCurrentEarleme.map {
      predictions(for: Set($0))!
    }.reduce(into: Set()) { $0.formUnion($1) }

    let newID = remember(predictedSymbolsInCurrentEarleme, predicts: currentPredictions)
    return .init(predictionSet: newID)
  }
}
