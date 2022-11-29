/**/
public struct Forest<StoredSymbol: SignedInteger & FixedWidthInteger> {
  let chart: Chart
  let grammar: Grammar<StoredSymbol>

  public typealias DerivationSet = [Range<Int>]

  func extend(_ p: inout DerivationSet) {
    var e = chart.entries[p.last!.first!]

    while e.predotOrigin != e.item.origin {
      let x = chart.prefixes(of: e, in: grammar).indices
      p.append(x)
      e = chart.entries[x.first!]
    }
  }

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

  public func derivations(of lhs: Symbol, over p: Range<SourcePosition>) -> DerivationSet
  {
    var r = [chart.completions(of: lhs, over: p).indices]
    extend(&r)
    return r
  }

  public struct Derivation {
    let path: DerivationSet
    let domain: Forest
    public let rule: RuleID
  }

  public func first(of d: DerivationSet) -> Derivation {
    .init(
      path: d, domain: self,
      rule: grammar.rule(containing: chart.entries[d.first!.lowerBound].item.dotPosition))
  }
}

extension LazyMapCollection: Hashable, Equatable where Element: Hashable {
  public func hash(into h: inout Hasher) {
    for x in self { x.hash(into: &h) }
  }
  public static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.elementsEqual(rhs)
  }
}

extension Forest.Derivation {
  public var lhs: Symbol { domain.grammar.lhs(rule) }
  public var rhs: Grammar<StoredSymbol>.Rule.RHS { domain.grammar.rhs(rule) }
  public var rhsOrigins: LazyMapCollection<ReversedCollection<Forest.DerivationSet>, UInt32> {
    path.reversed().lazy.map { domain.chart.entries[$0.lowerBound].predotOrigin }
  }
}

extension Forest.Derivation: CustomStringConvertible {
  public var description: String {
    "\(lhs.id) ::= \(rhs.map { String($0.id) }.joined(separator: " ")): \(Array(rhsOrigins))"
  }
}

/*
struct ParseNode<StoredSymbol: SignedInteger & FixedWidthInteger> {
  typealias Grammar = Lotsawa.Grammar<StoredSymbol>
  let chart: Chart
  let grammar: Grammar
  let lhs: Symbol
  let locus: Range<SourcePosition>

  struct Derivations {
    let subject: ParseNode

    /// Indices of the chart Entries marking the parts of this derivation, from last (the completion
    /// of the RHS) to first (the recognition of the first symbol of the RHS)
    var path: DerivationSet = []

    init(_ subject: ParseNode) {
      rulePath.append(subject.chart.completions(of: subject.lhs, over: subject.locus).indices)
      extend()
    }
  }

  struct Derivation {
    let forest: ParseForest

    /// Indices of the chart Entries marking the parts of this derivation, from last (the completion
    /// of the RHS) to first (the recognition of the first symbol of the RHS)
    var rulePath: [Range<Chart.Position>]

    init(firstIn forest: ParseForest) {
      self.forest = forest

      rulePath = []
    }

    mutating func formNext() -> Bool {
      formNext(from: rulePath.count - 1)
    }

    mutating func formNext() ->
  }
}

extension ParseForest {
  struct DerivationIterator<Completions: BidirectionalCollection, Prefixes: Collection>
    where Completions.Element == Chart.Entry, Prefixes.Element == Chart.Entry
  {
    let chart: Chart
    var remainingCompletions: Completions.SubSequence
    var remainingPrefixes: [Prefixes.SubSequence]
    var offset: Int
  }

}

extension ParseForest.DerivationIterator: IteratorProtocol {
  func next() -> Derivation? {
    if remainingCompletions.isEmpty { return nil }
    let r = Derivation(
      chart: chart,
      completion: remainingCompletions.first!,
      prefixes: remainingPrefixes.map { $0.first! })
    offset += 1

    remainingPrefixes.last!.popFirst()
    if remainingPrefixes.last.isEmpty {

    }

    return r
  }
}

extension ParseForest {
  func derivations() -> some Collection<Derivation> {
    let completions = chart.completions(of: top, over: locus)[...]

    var r: [Derivation] = []

    return r
  }
}

*/
