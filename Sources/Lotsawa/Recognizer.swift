/// A process that creates the parse forest for a token stream with respect to a `Grammar`.
public struct Recognizer<StoredSymbol: SignedInteger & FixedWidthInteger>
{
  public typealias Grammar = Lotsawa.Grammar<StoredSymbol>

  /// The grammar being recognized.
  private let g: Grammar

  /// True iff the raw grammar from which g was derived was nullable.
  private let acceptsNull: Bool

  private let rulesByLHS: MultiMap<Symbol, RuleID>

  private let leoPositions: Set<Grammar.Position>

  /// Storage for all DerivationGroups, grouped by Earleme and sorted within each Earleme.
  public private(set) var chart = Chart()

  /// True iff at least one Leo candidate item was added to the current earley set.
  private var leoCandidateFound = false
}

/// applies `f` to `x`.
///
/// Useful for making certain constructs more readable
func mutate<T, R>(_ x: inout T, applying f: (inout T)->R) -> R {
  f(&x)
}

extension Recognizer {
  /// Creates an instance that recognizes `start` in `g`.
  public init(_ g: PreprocessedGrammar<StoredSymbol>) {
    self.g = g.base
    self.rulesByLHS = g.rulesByLHS
    self.leoPositions = g.leoPositions
    self.acceptsNull = g.isNullable
    initialize()
  }

  /// Prepares `self` to recognize an input of length `n`.
  public mutating func initialize() {
    chart.removeAll()
    predict(g.startSymbol)
  }

  public var currentEarleme: UInt32 { chart.currentEarleme }

  /// Returns the chart entry that predicts the start of `r`.
  private func prediction(_ r: RuleID) -> Chart.Entry {
    .init(item: .init(predicting: r, in: g, at: currentEarleme), predotOrigin: 0)
  }

  /// Seed the current item set with rules implied by the predicted recognition of `s` starting at
  /// the current earleme.
  mutating func predict(_ s: Symbol) {
    for r in rulesByLHS[s] {
      if insert(prediction(r)) {
        predict(g.rhs(r).first!)
      }
    }
  }

  mutating func insert(_ newEntry: Chart.Entry) -> Bool {
    if !chart.insert(newEntry) { return false }
    if leoPositions.contains(newEntry.item.dotPosition) {
      self.leoCandidateFound = true
    }
    return true
  }

  /// Respond to the discovery of `s` starting at `origin` and ending in the current earleme.
  public mutating func discover(_ s: Symbol, startingAt origin: SourcePosition) {
    // The set containing potential mainstem derivations to be paired with the one for s.
    let mainstems = chart.transitionEntries(on: s, inEarleySet: origin)

    if let head = mainstems.first,
       let d = head.item.leoMemo(in: g)
    {
      derive(.init(item: d, predotOrigin: origin))
    }
    else {
      assert(
        mainstems.allSatisfy(\.item.isEarley),
        "Leo item is not first in mainstems.")

      for p in mainstems {
        derive(.init(item: p.item.advanced(in: g), predotOrigin: origin))
      }
    }
  }

  func leoPredecessor(_ x: Chart.Item) -> Chart.Entry? {
    assert(g.recognized(at: x.dotPosition) == nil, "unexpectedly complete item")
    let s = g.recognized(at: x.dotPosition + 1)!

    let mainstems = chart.transitionEntries(on: s, inEarleySet: x.origin)
    if let head = mainstems.first, head.item.isLeo {
      return head
    }
    return nil
  }

  /// Ensures that `x` is represented in the current derivation set, and draws any consequent
  /// conclusions.
  private mutating func derive(_ x: Chart.Entry) {
    assert(!x.item.isLeo)
    if !insert(x) { return }

    if let t = x.item.transitionSymbol {
      predict(t)
    }
    else { // it's complete
      discover(g.recognized(at: x.item.dotPosition)!, startingAt: x.item.origin)
    }
  }

  /// Creates the Leo items indicated for the current set.
  ///
  /// - Precondition: the current set is otherwise complete.
  mutating func createLeoItems() {
    var i = chart.currentEarleySet.startIndex
    while i != chart.currentEarleySet.endIndex {
      let x = chart.currentEarleySet[i].item
      guard let t: Symbol = x.transitionSymbol
      else { break } // items with no transition Symbol are completions, at the end of the set.

      // Skip over multiple derivations of the same item
      let endOfItem = chart.currentEarleySet[i...].dropFirst().prefix {
        $0.item == x
      }.endIndex

      // If the dot is in a Leo position and the transition symbol was unique in this set
      if leoPositions.contains(x.dotPosition)
           && (endOfItem == chart.currentEarleySet.endIndex
               || chart.currentEarleySet[endOfItem].item.transitionSymbol != t)
      {
        let memo = leoPredecessor(x)
          ?? Chart.Entry(item: x.advanced(in: g), predotOrigin: chart.currentEarleme)

        let inserted = chart.insertLeoMemo(of: memo, at: i, triggeredBy: t)
        i = endOfItem + (inserted ? 1 : 0)
      }
      else {
        // Else skip over everything with this transition symbol
        i = chart.currentEarleySet[endOfItem...].prefix {
          $0.item.transitionSymbol == t
        }.endIndex
      }
    }
  }

  /// Completes the current earleme and moves on to the next one, returning `true` unless no
  /// progress was made in the current earleme.
  public mutating func finishEarleme() -> Bool {
    if leoCandidateFound {
      createLeoItems()
      leoCandidateFound = false
    }
    return chart.finishEarleme()
  }

  /// Returns `true` iff there is at least one complete parse of the input through the last finished
  /// earleme.
  public func hasCompleteParse() -> Bool {
    if currentEarleme == 0 { return false }
    if currentEarleme == 1 && acceptsNull { return true }

    let completions = chart.completions(of: g.startSymbol, over: 0..<(currentEarleme - 1))

    return !completions.isEmpty
  }

  func earleySet(_ i: UInt32) -> Chart.EarleySet {
    return i < currentEarleme ? chart.earleySet(i) : chart.currentEarleySet
  }

  public var forest: Forest<StoredSymbol> {
    Forest(chart: chart, grammar: g)
  }
}
