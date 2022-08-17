/// A process that creates the parse forest for a token stream with respect to a `Grammar`.
public struct Recognizer<GConf: GrammarConfig>
{
  public typealias Grammar = Lotsawa.Grammar<GConf>

  private typealias Chart = [DerivationGroup]

  /// The grammar being recognized.
  private let g: Grammar

  private let rulesByLHS: MultiMap<Grammar.Symbol, Grammar.RuleID>

  private let leoPositions: Set<Grammar.Position>

  /// Storage for all DerivationGroups, grouped by Earleme and sorted within each Earleme.
  private var chart: Chart = []

  /// The position in `chart` where each earleme begins, plus a sentinel for the end of the last
  /// complete set.
  private var derivationSetBounds: [Array<DerivationGroup>.Index] = [0]

  /// A mapping from transition symbol to either a unique Leo candidate item, or to `nil` indicating
  /// that there were multiple candidates for that symbol.
  private var leoCandidate: [Symbol: DerivationGroup?] = [:]

  private var start: Grammar.Symbol
}

extension Recognizer {
  public typealias Symbol = Grammar.Symbol
  typealias DotPosition = Grammar.Position
  public typealias SourcePosition = UInt32

  /// The item set under construction.
  var currentDerivationSet: Array<DerivationGroup>.SubSequence {
    chart[derivationSetBounds.last!...]
  }

  /// Returns the item set describing recognitions through earleme `i`.
  func derivationSet(_ i: SourcePosition) -> Array<DerivationGroup>.SubSequence {
    chart[derivationSetBounds[Int(i)]..<derivationSetBounds[Int(i) + 1]]
  }

  /// An Earley item or a Leo “transitional item.”
  struct Item: Hashable {
    /// FIXME: compress the storage here.  It probably fits in 64 bits.

    /// The start Earleme of this partial recognition.
    let origin: SourcePosition

    /// The position in the Grammar of the dot between recognized and unrecognized symbols on the RHS.
    let dotPosition: DotPosition

    /// If `isLeo` is true, the transition symbol; otherwise, the postdot symbol, or `nil` if
    /// `self` is part of a completion.
    var transitionSymbol: Symbol?

    /// `true` iff `self` is part of a “transitional item” per Joop Leo.
    var isLeo: Bool

    func advanced(in g: Grammar) -> Item {
      Item(
        origin: origin, dotPosition: dotPosition + 1,
        transitionSymbol: g.postdot(at: dotPosition + 1), isLeo: false)
    }
  }

  /// The representative of a Earley or Leo item for its derivations with a given predot origin.
  ///
  /// Because a set of predot symbol origins is sufficient to efficiently reconstruct all
  /// derivations of any Earley or Leo item, and the non-derivation information is small, and
  /// ambiguity in useful grammars is low, each such item is represented as one or more
  /// consecutively stored `DerivationGroup`s, each representing one predot symbol origin.
  struct DerivationGroup: Hashable, Comparable {
    /// FIXME: compress the storage here.  It probably fits in 96 bits.

    /// The Earley or Leo item to which this derivation group belongs.
    var item: Item

    /// The start Earleme of the predot symbol, or `nil` if this is a prediction.
    let predotOrigin: SourcePosition?

    /// Returns `true` iff `lhs` must be sorted before `rhs` in the item store.
    static func < (lhs: Self, rhs: Self) -> Bool {
      lhs.sortKey < rhs.sortKey
    }

    /// A tuple that can be compared to yield the sort order (see `<` above).
    private var sortKey: (Symbol, UInt8, DotPosition, SourcePosition, SourcePosition) {
      (item.transitionSymbol ?? -1, item.isLeo ? 0 : 1, item.dotPosition,
       item.origin, predotOrigin ?? 0)
    }

    init(_ item: Item, predotOrigin: SourcePosition?) {
      self.item = item
      self.predotOrigin = predotOrigin
    }
  }
}

extension Recognizer {
  /// Creates an instance that recognizes `start` in `g`.
  public init(_ start: GConf.Symbol, in g: PreprocessedGrammar<GConf>) {
    self.start = start
    self.g = g.base
    self.rulesByLHS = g.rulesByLHS
    self.leoPositions = g.leoPositions
    initialize()
  }

  /// Prepares `self` to recognize an input of length `n`.
  public mutating func initialize() {
    chart.removeAll(keepingCapacity: true)
    derivationSetBounds.removeAll(keepingCapacity: true)
    derivationSetBounds.append(0)

    predict(start)
  }

  var currentEarleme: SourcePosition {
    SourcePosition(derivationSetBounds.count - 1)
  }

  /// Returns the chart entry that predicts the start of `r`.
  func prediction(_ r: Grammar.RuleID) -> DerivationGroup {
    .init(
        Item(
          origin: currentEarleme, dotPosition: g.rhsStart(r),
          transitionSymbol: g.rhs(r).first!, isLeo: false),
        predotOrigin: nil)
  }

  private func positionInCurrentSet(_ d: DerivationGroup) -> Chart.Index {
    currentDerivationSet.partitionPoint { y in y >= d }
  }

  /// Inserts `d` into the current derivation set, returning `true` iff it was not already present.
  @discardableResult
  private mutating func addToCurrentSet(_ d: DerivationGroup) -> Bool {
    let i = positionInCurrentSet(d)
    if chart.at(i) == d { return false }
    chart.insert(d, at: i)
    return true
  }

  /// Seed the current item set with rules implied by the predicted recognition of `s` starting at
  /// the current earleme.
  mutating func predict(_ s: Symbol) {
    for r in rulesByLHS[s] {
      if addToCurrentSet(prediction(r)) {
        predict(g.rhs(r).first!)
      }
    }
  }

  public mutating func discover(_ s: Symbol, startingAt origin: SourcePosition) {
    // The set containing potential prefixes of derivations paired with s.
    let prefixSource = derivationSet(origin)

    // The position where prefixes might be found
    let i = prefixSource.partitionPoint { g in g.item.transitionSymbol ?? -1 >= s  }

    // Prefixes must be in the source set and have the right transition symbol.
    guard let head = prefixSource.at(i), head.item.transitionSymbol == s else { return }

    if head.item.isLeo { // Handle the Leo item, of which there can be only one
      derive(
        .init(
          Item(
            origin: head.item.origin, dotPosition: head.item.dotPosition,
            transitionSymbol: g.postdot(at: head.item.dotPosition), isLeo: false),
          predotOrigin: origin)
      )
      return;
    }

    for prefix in prefixSource[i...].lazy.map(\.item)
          .droppingAdjacentDuplicates()
          .prefix(while: { x in x.transitionSymbol == s})
    {
      derive(.init(prefix.advanced(in: g), predotOrigin: origin))
    }
  }

  func leoPredecessor(_ x: Item) -> Item? {
    let source = derivationSet(x.origin)
    let s = g.lhs(ofRuleWithPenultimatePosition: x.dotPosition)
    if let l = source.at(source.partitionPoint { g in g.item.transitionSymbol ?? -1 >= s  }),
       l.item.isLeo
    { return l.item }
    return nil
  }

  /// Ensures that `x` is represented in the current derivation set, and draws any consequent
  /// conclusions.
  mutating func derive(_ x: DerivationGroup) {
    let i = positionInCurrentSet(x)
    let next = currentDerivationSet.at(i)
    // Bail if the derivation group is already known.
    if next == x { return }

    chart.insert(x, at: i)  // Add the derivation group

    // Bail if the item is already known.
    if next?.item == x.item { return }
    let prior = currentDerivationSet[..<i].last
    if prior?.item == x.item { return }

    if let t = x.item.transitionSymbol {
      // Check incomplete items for leo candidate-ness.
      if leoPositions.contains(x.item.dotPosition) {
        { v in v = v == nil ? x : .some(nil) }(&leoCandidate[t])
      }
      predict(t)
    }
    else { // it's complete
      discover(g.recognized(at: x.item.dotPosition)!, startingAt: x.item.origin)
    }
  }

  /// Add the leo items indicated for the current set.
  ///
  /// - Precondition: the current set is otherwise complete.
  mutating func addLeoItems() {
    for case let (t, .some(d)) in leoCandidate {
      var x = leoPredecessor(d.item) ?? d.item.advanced(in: g)
      x.isLeo = true
      x.transitionSymbol = t
      addToCurrentSet(DerivationGroup(x, predotOrigin: d.predotOrigin))
    }
    leoCandidate.removeAll(keepingCapacity: true)
  }

  /// Completes the current earleme and moves on to the next one, returning `true` unless no
  /// progress was made in the current earleme.
  public mutating func finishEarleme() -> Bool {
    let result = !currentDerivationSet.isEmpty
    addLeoItems()
    derivationSetBounds.append(chart.count)
    return result
  }
}
