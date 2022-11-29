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
  ///
  /// The first element points to a series of completions of the symbol in the chart.  Each element
  /// thereafter describes a series of potential predecessors of the *first* entry pointed to by the
  /// previous element.  Thus the elements are in some sense stored in reverse. Predictions are
  /// omitted.
  ///
  /// Notional derivation sets are sometimes (temporarily) described by their prefixes; see `extend`
  /// for more details.
  public typealias DerivationSet = [Range<Chart.Entries.Index>]

  /// One parse of a single symbol over a range of source positions, each of whose constituent RHS
  /// symbols may have multiple parses.
  public struct Derivation {
    /// The set of which this represpresents the first element
    let path: DerivationSet

    /// The set of parses in which path was found.
    let domain: Forest

    /// The rule described by this derivation.
    public let rule: RuleID
  }

  /// Extends a derivation set prefix by appending elements describing predecessors until the
  /// position of the first RHS symbol of the set's first derivation is represented.
  ///
  /// - Precondition: `!p.last.isEmpty`
  private func extend(_ p: inout DerivationSet) {
    var e = chart.entries[p.last!.first!]

    while e.predotOrigin != e.item.origin {
      let x = chart.prefixes(of: e, in: grammar).indices
      p.append(x)
      e = chart.entries[x.first!]
    }
  }

  /// Drops the first derivation from `p`, leaving it empty if there are no further derivations.
  public func removeFirst(from p: inout DerivationSet) {
    _ = p[p.index(before: p.endIndex)].popFirst()
    if !p.last!.isEmpty { return }
    repeat {
      p.removeLast()
      if p.isEmpty { return }
      _ = p[p.index(before: p.endIndex)].popFirst()
    } while p.last!.isEmpty
    extend(&p)
  }

  /// Returns the set representing all derivations of `lhs` over `locus`.
  public func derivations(of lhs: Symbol, over locus: Range<SourcePosition>) -> DerivationSet {
    let roots = chart.completions(of: lhs, over: locus).indices
    if roots.isEmpty { return [] }
    var r = [roots]
    extend(&r)
    return r
  }

  /// Returns the first derivation in `d`.
  public func first(of d: DerivationSet) -> Derivation {
    .init(
      path: d, domain: self,
      rule: grammar.rule(containing: chart.entries[d.first!.lowerBound].item.dotPosition))
  }
}

extension Forest.Derivation {
  /// The LHS symbol being derived.
  public var lhs: Symbol { domain.grammar.lhs(rule) }

  /// The RHS symbols of the rule by which `lhs` was derived.
  public var rhs: Grammar<StoredSymbol>.Rule.RHS { domain.grammar.rhs(rule) }

  /// The position in the source where each RHS symbol of this derivation starts.
  public var rhsOrigins:
    LazyMapCollection<ReversedCollection<Forest.DerivationSet>, SourcePosition>
  {
    path.reversed().lazy.map { domain.chart.entries[$0.lowerBound].predotOrigin }
  }
}

extension Forest.Derivation: CustomStringConvertible {
  public var description: String {
    "\(lhs.id) ::= \(rhs.map { String($0.id) }.joined(separator: " ")): \(Array(rhsOrigins))"
  }
}
