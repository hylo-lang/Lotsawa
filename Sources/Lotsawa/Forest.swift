/// A result of recognition from which parses can be extracted.
public struct Forest<StoredSymbol: SignedInteger & FixedWidthInteger> {
  /// The information produced by the recognizer.
  private let chart: Chart

  /// The language being recognized.
  private let grammar: Grammar<StoredSymbol>

  /// Creates an instance representing the parses stored in `chart` for the given `grammar`.
  init(chart: Chart, grammar: Grammar<StoredSymbol>) {
    self.chart = chart
    self.grammar = grammar
  }

  struct LeoCompletionKey: Hashable {
    let locus: Range<SourcePosition>
    let lhs: Symbol
  }

  private var leoCompletions: [LeoCompletionKey: [Chart.Entry]] = [:]
}

extension Forest {
  /// A subset of the parses of a single symbol over a range of source positions.
  public struct DerivationSet {
    /// The internal representation of a DerivationSet independent of Chart or Grammar.
    ///
    /// A notional multi-“digit” counter describing the derivation set.  Each time the counter is
    /// advanced, the first derivation is effectively removed from the set.
    ///
    /// `completions` stores the remaining values for the most significant digit of the counter,
    /// with the current value of that digit being `completions.first`.
    ///
    /// Each *element* of `tails` corresponds to another digit, in least-to-most-significant order.
    ///
    /// An element of `tails` is the range of values remaining for its corresponding digit *given
    /// the current values of all more significant digits*, with the first element of the range
    /// being the current value of the digit.
    ///
    /// When a digit d0 runs out of values, the first value is removed from the
    /// next-more-significant digit d1 and whether d0 is even needed given the new value of d1
    /// depends on d1 and the forest.  In general, how many digits less significant than d1 are
    /// needed, and their representations, need to be discovered newly in the forest.  That
    /// discovery is implemented by the `extend` operation.
    struct Storage {
      /// The completions of all derivations in the set; the most significant digit of the counter
      var completions: Array<Chart.Entry>.SubSequence

      /// A series of mainstems of the first element of `completions`,
      var tails: [Range<Chart.Entries.Index>]
    }

    init(storage: Storage, domain: Forest) {
      self.storage = storage
      self.domain = domain
    }

    private var storage: Storage
    private var domain: Forest
  }

  /// One parse of a single symbol over a range of source positions, each of whose constituent RHS
  /// symbols may have multiple parses.
  public struct Derivation {
    /// The set of which this represpresents the first element
    let path: DerivationSet.Storage

    /// The set of parses in which path was found.
    let domain: Forest

    /// The rule described by this derivation.
    public let rule: RuleID
  }

  /// Extends a derivation set prefix by appending elements describing mainstems until the
  /// position of the first RHS symbol of the set's first derivation is represented.
  ///
  /// - Precondition: `!p.last.isEmpty`
  private func extend(_ p: inout DerivationSet.Storage) {
    var e = p.tails.isEmpty
      ? p.completions.first!
      : chart.entries[p.tails.last!.first!]

    while let x = Optional(chart.earleyMainstem(of: e)),
          let head = x.first,
          head.mainstemIndex != nil
    {
      p.tails.append(x.indices)
      e = x.first!
    }
  }

  /// Drops the first derivation from `p`, leaving it empty if there are no further derivations.
  func removeFirst(from p: inout DerivationSet.Storage) {
    func step() -> Bool {
      if p.tails.isEmpty {
        _ = p.completions.popFirst()
        return false
      }
      return mutate(&p.tails[p.tails.index(before: p.tails.endIndex)]) {
        _ = $0.popFirst()
        return $0.isEmpty
      }
    }

    while step() {
      p.tails.removeLast()
    }

    if !p.completions.isEmpty {
      extend(&p)
    }
  }

  public mutating func requireCompletion(
    _ c: Chart.Entry, inEarleme i: SourcePosition
  ) -> Bool {
    assert(c.item.isCompletion, "requiring non-completion \(c)")
    let setI = chart.earleySet(i)
    let p = setI.partitionPoint { $0 >= c }
    /// Derivation already in the chart?  We're done
    if setI[p...].first == c { return true }

    // Item already in the chart? Return true eventually.
    let r0 = setI[p...].first?.item == c.item || setI[..<p].last?.item == c.item

    return mutate(
      &leoCompletions[.init(locus: c.item.origin..<i, lhs: c.item.lhs!), default: []]
    ) { leoSet in
      let q = leoSet.partitionPoint { $0 >= c }
      // Derivation already in the leoSet?  We're done
      if leoSet[q...].first == c { return true }

      // Item already in the leoSet? Return true eventually
      let r1 = leoSet[q...].first?.item == c.item || leoSet[..<q].last?.item == c.item
      leoSet.insert(c, at: q)
      return r1
    } || r0
  }

  public mutating func collectLeoCompletions(
    causing top: Chart.Entry, endingAt endEarleme: SourcePosition
  ) {
    assert(top.item.isCompletion, "collecting leo completions on non-completion \(top)")
    guard let lim0Index = top.mainstemIndex, chart.entries[lim0Index].item.isLeo else { return }
    var workingLIMIndex = lim0Index
    while true {
      let workingBaseIndex = workingLIMIndex + 1
      let workingBase = chart.entries[workingBaseIndex].item
      let newCompletion = Chart.Entry(
        item: workingBase.advanced(in: grammar), mainstemIndex: workingBaseIndex)
      if requireCompletion(newCompletion, inEarleme: endEarleme) { break }
      guard let previousLIMIndex = chart.entries[workingLIMIndex].mainstemIndex else { break }
      workingLIMIndex = previousLIMIndex
    }
  }

  /// Returns the set representing all derivations of `lhs` over `locus`.
  public mutating func derivations(of lhs: Symbol, over locus: Range<SourcePosition>)
    -> DerivationSet
  {
    let storedCompletions = chart.completions(of: lhs, over: locus)
    for top in storedCompletions {
      collectLeoCompletions(causing: top, endingAt: locus.upperBound)
    }
    let storedCompletionsWithEarleyMainstem
      = storedCompletions.lazy.filter { [chart] in chart.entries[$0.mainstemIndex!].item.isEarley }

    let leos = leoCompletions[.init(locus: locus, lhs: lhs), default: []]

    var roots = DerivationSet.Storage(
      completions: storedCompletionsWithEarleyMainstem.merged(with: leos)[...], tails: []
    )

    if !roots.completions.isEmpty { extend(&roots) }
    return DerivationSet(storage: roots, domain: self)
  }

  /// Returns the first derivation in `d`.
  func first(of d: DerivationSet.Storage) -> Derivation {
    .init(
      path: d, domain: self,
      rule: grammar.rule(containing: d.completions.first!.item.dotPosition))
  }
}

extension Forest.DerivationSet {
  public var isEmpty: Bool { storage.completions.isEmpty }
  public var first: Forest.Derivation? {
    isEmpty ? nil : domain.first(of: storage)
  }
  public mutating func removeFirst() {
    domain.removeFirst(from: &storage)
  }
}

extension Forest.DerivationSet: Collection {
  public struct Index: Comparable {
    var offset: Int

    fileprivate var remainder: Storage
    public static func < (l: Self, r: Self) -> Bool {
      UInt(bitPattern: l.offset) < UInt(bitPattern: r.offset)
    }

    public static func == (l: Self, r: Self) -> Bool {
      l.offset == r.offset
    }

    init(remainder: Storage) {
      self.remainder = remainder
      offset = remainder.completions.isEmpty ? -1 : 0
    }
  }

  public var startIndex: Index { Index(remainder: self.storage) }
  public var endIndex: Index {
    Index(remainder: .init(completions: [], tails: []))
  }

  public func formIndex(after x: inout Index) {
    domain.removeFirst(from: &x.remainder)
    x.offset = x.remainder.completions.isEmpty ? -1 : x.offset + 1
  }

  public func index(after x: Index) -> Index {
    var y = x
    formIndex(after: &y)
    return y
  }

  public subscript(p: Index) -> Forest.Derivation {
    domain.first(of: p.remainder)
  }
}

extension Forest.Derivation {
  /// The LHS symbol being derived.
  public var lhs: Symbol { domain.grammar.lhs(rule) }

  /// The RHS symbols of the rule by which `lhs` was derived.
  public var rhs: Grammar<StoredSymbol>.Rule.RHS { domain.grammar.rhs(rule) }

  /// The position in the source where each RHS symbol of this derivation starts.
  public var rhsOrigins: some BidirectionalCollection<SourcePosition> {
    var r: [SourcePosition] = []
    r.reserveCapacity(path.tails.count + 1)
    r.append(
      contentsOf:
        path.tails.reversed().lazy.map {
          domain.chart.earleme(ofEntryIndex: domain.chart.entries[$0.lowerBound].mainstemIndex!)
        })
    r.append(domain.chart.earleme(ofEntryIndex: path.completions.first!.mainstemIndex!))
    return r
  }
}

extension Forest.Derivation: CustomStringConvertible {
  public var description: String {
    "\(lhs.id) ::= \(rhs.map { String($0.id) }.joined(separator: " ")): \(Array(rhsOrigins))"
  }
}
