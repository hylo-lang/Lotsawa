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
  private var chart = Chart()

  /// A mapping from transition symbol to either a unique Leo candidate item, or to `nil` indicating
  /// that there were multiple candidates for that symbol.
  private var leoCandidate: [Symbol: Chart.Item?] = [:]
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
    leoCandidate.removeAll(keepingCapacity: true)

    predict(g.startSymbol)
  }

  public var currentEarleme: UInt32 { chart.currentEarleme }

  /// Returns the chart entry that predicts the start of `r`.
  func prediction(_ r: RuleID) -> Chart.Entry {
    .init(item: .init(predicting: r, in: g, at: currentEarleme), predotOrigin: 0)
  }

  /// Seed the current item set with rules implied by the predicted recognition of `s` starting at
  /// the current earleme.
  mutating func predict(_ s: Symbol) {
    for r in rulesByLHS[s] {
      if chart.insert(prediction(r)) {
        predict(g.rhs(r).first!)
      }
    }
  }

  /// Respond to the discovery of `s` starting at `origin` and ending in the current earleme.
  public mutating func discover(_ s: Symbol, startingAt origin: SourcePosition) {
    // The set containing potential predecessor derivations to be paired with the one for s.
    let predecessors = chart.transitionItems(on: s, inEarleySet: origin)

    if let head = predecessors.first,
       let d = head.leoMemo(in: g)
    {
      derive(.init(item: d, predotOrigin: head.origin))
    }
    else {
      assert(
        predecessors.allSatisfy(\.isEarley),
        "Leo item is not first in predecessors.")

      for p in predecessors {
        derive(.init(item: p.advanced(in: g), predotOrigin: origin))
      }
    }
  }

  func leoPredecessor(_ x: Chart.Item) -> Chart.Item? {
    assert(g.recognized(at: x.dotPosition) == nil, "unexpectedly complete item")
    let s = g.recognized(at: x.dotPosition + 1)!

    let predecessors = chart.transitionItems(on: s, inEarleySet: x.origin)
    if let head = predecessors.first, head.isLeo {
      return head
    }
    return nil
  }

  /// Ensures that `x` is represented in the current derivation set, and draws any consequent
  /// conclusions.
  mutating func derive(_ x: Chart.Entry) {
    assert(!x.item.isLeo)
    if !chart.insert(x) { return }

    if let t = x.item.transitionSymbol {
      // Check incomplete items for leo candidate-ness.
      if leoPositions.contains(x.item.dotPosition) {
        // The first time we find a leo predecessor with transition symbol t, store it as a
        // candidate, but thereafter, store nil.
        mutate(&leoCandidate[t]) { v in v = v == nil ? .some(x.item) : .some(nil) }
      }
      predict(t)
    }
    else { // it's complete
      discover(g.recognized(at: x.item.dotPosition)!, startingAt: x.item.origin)
    }
  }

  /// Adds the leo items indicated for the current set.
  ///
  /// - Precondition: the current set is otherwise complete.
  mutating func addLeoItems() {
    for case let (t, .some(d)) in leoCandidate {
      let memo = leoPredecessor(d) ?? d.advanced(in: g)
      chart.insert(
        .init(
          item: Chart.Item(memoizing: memo, transitionSymbol: t),
          predotOrigin: 0))
    }
    leoCandidate.removeAll(keepingCapacity: true)
  }

  /// Completes the current earleme and moves on to the next one, returning `true` unless no
  /// progress was made in the current earleme.
  public mutating func finishEarleme() -> Bool {
    addLeoItems()
    return chart.finishEarleme()
  }

  /// Returns `true` iff there is at least one complete parse of the input through the last finished
  /// earleme.
  public func hasCompleteParse() -> Bool {
    if currentEarleme == 0 { return false }
    if currentEarleme == 1 && acceptsNull { return true }

    let completions = chart.completions(of: g.startSymbol, inEarleySet: currentEarleme - 1)

    return completions.contains { d in d.item.origin == 0 }
  }

  func earleySet(_ i: UInt32) -> Chart.EarleySet {
    return i < currentEarleme ? chart.earleySet(i) : chart.currentEarleySet
  }
}
