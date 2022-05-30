public protocol AnyLeoGrammar: AnyEarleyGrammar where Symbol: Hashable {
  func isRightRecursive(_ r: PartialRule) -> Bool
  func penult(_ x: PartialRule) -> Symbol?
}

struct ALeoGrammar<Symbol: Hashable>: AnyLeoGrammar {
  typealias Base = EarleyGrammar<Symbol>
  let base: Base

  typealias PartialRule = Base.PartialRule
  typealias Alternatives = Base.Alternatives
  typealias Symbol = Base.Symbol

  func alternatives(_ lhs: Symbol) -> Alternatives { base.alternatives(lhs) }
  func isNullable(_ s: Symbol) -> Bool { base.isNullable(s) }
  func isComplete(_ rhs: PartialRule) -> Bool { base.isComplete(rhs) }
  func lhs(_ t: PartialRule) -> Symbol { base.lhs(t) }
  func postdot(_ t: PartialRule) -> Symbol? { base.postdot(t) }

  func isRightRecursive(_ r: PartialRule) -> Bool { fatalError() }
  func penult(_ x: PartialRule) -> Symbol? { fatalError() }
}

extension Collection {
  func hasUniqueItem(where condition: (Element)->Bool) -> Bool {
    guard let j = firstIndex(where: condition)
    else { return false }
    return self[index(after: j)...].allSatisfy { p in !condition(p) }
  }
}

public struct LeoParser<Grammar: AnyLeoGrammar>: AnyEarleyParser {
  public typealias PartialParse = PartialParse_<Grammar>

  /// Creates an instance for the given grammar.
  public init(_ g: Grammar) { self.g = g }

  /// A position in the input.
  public typealias SourcePosition = Int

  /// All the partial parses, grouped by earleme.
  public var partials: [PartialParse] = []

  /// The position in `partials` where each earleme begins.
  public var earlemeStart: [Array<PartialParse>.Index] = []

  /// The grammar
  public var g: Grammar

  public var leoItems: [[Grammar.Symbol: PartialParse]] = []

  mutating func reduce(_ p: PartialParse, at i: Int) {
    let lhs = self.lhs(p)

    if p.start < leoItems.count,
       let predecessor = leoItems[p.start][lhs]
    {
      insert(PartialParse(expecting: predecessor.rule, at: predecessor.start))
    }
    else {
      earleyReduce(p)
    }
  }

  func leoPredecessor(_ b: PartialParse) -> PartialParse? {
    if b.start >= leoItems.count { return nil }
    let s = lhs(b)
    return leoItems[b.start][s]
  }

  func isPenultUnique(_ x: Grammar.Symbol) -> Bool {
    return partials[earlemeStart.last!...]
      .hasUniqueItem { p in g.penult(p.rule) == x }
  }

  func isLeoUnique(_ x: Grammar.PartialRule) -> Bool {
    if let p = g.penult(x) { return isPenultUnique(p) }
    return false
  }

  func isLeoEligible(_ x: Grammar.PartialRule) -> Bool {
    g.isRightRecursive(x) && isLeoUnique(x)
  }

  public mutating func inferenceHook(_ b: PartialParse) {
    let i = earlemeStart.count - 1
    leoItems.append([:])
    if !isLeoEligible(b.rule) { return }
    let p = g.penult(b.rule)!
    if let predecessor = leoPredecessor(b) {
      leoItems[i][p] = predecessor
    }
    else {
      leoItems[i][p] = b.advanced()
    }
  }
}
