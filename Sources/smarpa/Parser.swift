typealias Grammar_<RawSymbol: Hashable> = Grammar<RawSymbol>

struct Parser<RawSymbol: Hashable> {
  typealias Grammar = Grammar_<RawSymbol>

  public struct PartialParse {
    /// The positions in ruleStore of yet-to-be recognized RHS symbols.
    var rule: Grammar.PartialRule

    /// The position in the token stream where the partially-parsed input begins.
    let start: SourcePosition
  }

  let g: Grammar

  /// All the partial parses, grouped by earleme.
  var partials: [PartialParse] = []

  /// The position in `partials` where each earleme begins.
  var earlemeStart: [Array<PartialParse>.Index] = []

  /// Leo items, per the MARPA paper.
  var leoItems: [[Grammar.Symbol: PartialParse]] = []
}

extension Parser.PartialParse: Hashable {
  init(expecting expected: Grammar<RawSymbol>.PartialRule, at start: SourcePosition) {
    self.rule = expected
    self.start = start
  }

  /// Returns `self`, having advanced the forward by one position.
  func advanced() -> Self { Self(expecting: rule.dropFirst(), at: start) }
}

extension Parser {
  /// Creates an instance for the given grammar.
  public init(_ g: Grammar) { self.g = g }

  /// A position in the input.
  public typealias SourcePosition = Int

  func postdot(_ p: PartialParse) -> Grammar.Symbol? { g.postdot(p.rule) }
  func lhs(_ p: PartialParse) -> Grammar.Symbol { g.lhs(p.rule) }

  /// Adds `p` to the latest earleme if it is not already there.
  mutating func insert(_ p: PartialParse) {
    if !partials[earlemeStart.last!...].contains(p) { partials.append(p) }
  }

  var currentEarleme: Int { earlemeStart.count - 1 }
  var currentEarlemeStart: Array<PartialParse>.Index { earlemeStart.last! }

  /// Recognizes the sequence of symbols in `source` as a parse of `start`.
  public mutating func recognize<Source: Collection>(_ source: Source, as start: Grammar.Symbol)
    where Source.Element == Grammar.Symbol
  {
    let n = source.count
    partials.removeAll(keepingCapacity: true)
    earlemeStart.removeAll(keepingCapacity: true)
    leoItems.removeAll(keepingCapacity: true)
    earlemeStart.reserveCapacity(n + 1)
    earlemeStart.reserveCapacity(n + 1)
    partials.reserveCapacity(n + 1)
    earlemeStart.append(0)

    for r in g.alternatives(start) {
      partials.append(PartialParse(expecting: r, at: 0))
    }

    // Recognize each token over its range in the source.
    var tokens = source.makeIterator()

    var i = 0
    while i != earlemeStart.count {
      var j = earlemeStart[i] // The partial parse within the current earleme

      while j < partials.count {
        let p = partials[j]
        if let s = postdot(p) {
          predict(s, in: p)
        }
        else {
          reduce(p)
        }
        addLeoItems(p)
        j += 1
      }

      // scans
      if let t = tokens.next() { scan(t) }
      i += 1
    }
  }

  public mutating func predict(_ s: Grammar.Symbol, in p: PartialParse) {
    for rhs in g.alternatives(s) {
      insert(PartialParse(expecting: rhs, at: currentEarleme))
      if s.isNulling { insert(p.advanced()) }
    }
  }

  public mutating func reduce(_ p: PartialParse) {
    if /*p.start < leoItems.count,*/ let predecessor = leoItems[p.start][lhs(p)] {
      insert(PartialParse(expecting: predecessor.rule, at: predecessor.start))
    }
    else {
      earleyReduce(p)
    }
  }

  /// Performs Earley reduction on p.
  public mutating func earleyReduce(_ p: PartialParse) {
    let s0 = lhs(p)

    /// Inserts partials[k].advanced() iff its postdot symbol is s0.
    func advanceIfPostdotS0(_ k: Int) {
      let p0 = partials[k]
      if postdot(p0) == s0 { insert(p0.advanced()) }
    }

    if p.start != currentEarleme {
      for k in earlemeStart[p.start]..<earlemeStart[p.start + 1] {
        advanceIfPostdotS0(k)
      }
    }
    else { // TODO: can we eliminate this branch?
      var k = earlemeStart[p.start]
      while k < partials.count {
        advanceIfPostdotS0(k)
        k += 1
      }
    }
  }

  mutating func scan(_ t: Grammar.Symbol) {
    var found = false
    for j in partials[currentEarlemeStart...].indices {
      let p = partials[j]
      if postdot(p) == t {
        if !found { earlemeStart.append(partials.count) }
        found = true
        insert(p.advanced())
      }
    }
  }

  public mutating func addLeoItems(_ b: PartialParse) {
    let i = currentEarleme
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

  func leoPredecessor(_ b: PartialParse) -> PartialParse? {
    /*if b.start >= leoItems.count { return nil }*/
    return leoItems[b.start][lhs(b)]
  }

  func isPenultUnique(_ x: Grammar.Symbol) -> Bool {
    return partials[currentEarlemeStart...]
      .hasUniqueItem { p in g.penult(p.rule) == x }
  }

  func isLeoUnique(_ x: Grammar.PartialRule) -> Bool {
    if let p = g.penult(x) { return isPenultUnique(p) }
    return false
  }

  func isLeoEligible(_ x: Grammar.PartialRule) -> Bool {
    g.isRightRecursive(x) && isLeoUnique(x)
  }
}

extension Parser: CustomStringConvertible {
  public var description: String {
    var lines: [String] = []
    var i = -1
    for j in partials.indices {
      if earlemeStart.count > i + 1 && j == earlemeStart[i + 1] {
        i += 1
        lines.append("\n=== \(i) ===")
        for (k, v) in leoItems[i] {
          lines.append("  Leo \(k): \(ruleString(v))")
        }
      }
      lines.append(ruleString(partials[j]))
    }
    return lines.joined(separator: "\n")
  }

  func ruleString(_ p: PartialParse) -> String {
    var r = "\(lhs(p)) ->\t"
    var all = g.alternatives(lhs(p)).first { $0.endIndex == p.rule.endIndex }!
    while !g.isComplete(all) {
      if all.count == p.rule.count { r += "• " }
      r += "\(g.postdot(all)!) "
      _ = all.popFirst()
    }
    if p.rule.isEmpty { r += "•" }
    r += "\t(\(p.start))"
    return r
  }
}
