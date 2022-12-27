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
}

extension Forest {
  /// A subset of the parses of a single symbol over a range of source positions.
  public struct DerivationSet {
    /// The internal representation of a DerivationSet independent of Chart or Grammar.
    ///
    /// The first element points to a series of completions of the symbol in the chart.  Each
    /// element thereafter describes a series of potential mainstems of the *first* entry pointed
    /// to by the previous element.  Thus the elements are in some sense stored in
    /// reverse. Predictions are omitted.
    ///
    /// Notional derivation sets are sometimes (temporarily) described by their prefixes; see `extend`
    /// for more details.
    struct Storage {
      var completions: Array<Chart.Entry>.SubSequence
      var mainstems: [Range<Chart.Entries.Index>]
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
    var e = p.mainstems.isEmpty
      ? p.completions.first!
      : chart.entries[p.mainstems.last!.first!]

    while e.predotOrigin != e.item.origin {
      let x = chart.mainstemDerivations(of: e, in: grammar).indices
      p.mainstems.append(x)
      e = chart.entries[x.first!]
    }
  }

  /// Drops the first derivation from `p`, leaving it empty if there are no further derivations.
  func removeFirst(from p: inout DerivationSet.Storage) {
    func step() -> Bool {
      if p.mainstems.isEmpty {
        _ = p.completions.popFirst()
        return false
      }
      return mutate(&p.mainstems[p.mainstems.index(before: p.mainstems.endIndex)]) {
        _ = $0.popFirst()
        return $0.isEmpty
      }
    }

    while step() {
      p.mainstems.removeLast()
    }

    if !p.completions.isEmpty {
      extend(&p)
    }
  }

  /// Returns the set representing all derivations of `lhs` over `locus`.
  public func derivations(of lhs: Symbol, over locus: Range<SourcePosition>) -> DerivationSet {
    var roots = DerivationSet.Storage(
      completions: Array(chart.completions(of: lhs, over: locus))[...],
      mainstems: [])

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
    Index(remainder: .init(completions: [], mainstems: []))
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
    r.reserveCapacity(path.mainstems.count + 1)
    r.append(
      contentsOf:
        path.mainstems.reversed().lazy.map { domain.chart.entries[$0.lowerBound].predotOrigin })
    r.append(path.completions.first!.predotOrigin)
    return r
  }
}

extension Forest.Derivation: CustomStringConvertible {
  public var description: String {
    "\(lhs.id) ::= \(rhs.map { String($0.id) }.joined(separator: " ")): \(Array(rhsOrigins))"
  }
}
