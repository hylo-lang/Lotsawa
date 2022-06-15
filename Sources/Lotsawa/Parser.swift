typealias Grammar_<RawSymbol: Hashable> = Grammar<RawSymbol>
typealias SourcePosition = Int

struct Parser<RawSymbol: Hashable> {
  typealias Grammar = Grammar_<RawSymbol>

  /// A partially-completed parse (AKA an Earley item).
  public struct PartialParse {
    /// The positions in ruleStore of yet-to-be recognized RHS symbols.
    let rule: Grammar.DottedRule

    /// The position in the token stream where the partially-parsed input begins.
    let start: SourcePosition
  }

  /// The grammar being recognized.
  let g: Grammar

  typealias Partials = [PartialParse]
  typealias Leos = [(transition: Grammar.Symbol, parse: PartialParse)]

  /// All the partial parses, grouped by earleme.
  var partials: [PartialParse] = []

  /// The position in `partials` where each earleme begins.
  var earlemeStart: [(earley: Partials.Index, leo: Leos.Index)] = []

  /// Leo items, per the MARPA paper.
  var leos: Leos = []
}

extension Parser.PartialParse: Hashable {
  /// Creates an instance attempting to recognize `g.lhs(expected)` with
  /// `g.postdotRHS(expected)` remaining to be parsed.
  init(expecting expected: Grammar<RawSymbol>.DottedRule, at start: SourcePosition) {
    self.rule = expected
    self.start = start
  }

  /// Returns `self`, having advanced the forward by one position.
  func advanced() -> Self { Self(expecting: rule.advanced, at: start) }

  /// `true` iff there are no symbols left to recognize on the RHS of `self.rule`.
  var isComplete: Bool { return rule.isComplete }
}

// TODO: store Leo items more efficiently.
extension Parser {
  /// Creates an instance for the given grammar.
  public init(_ g: Grammar) { self.g = g }

  /// A position in the input.
  public typealias SourcePosition = Int

  func postdot(_ p: PartialParse) -> Grammar.Symbol? { g.postdot(p.rule) }
  func lhs(_ p: PartialParse) -> Grammar.Symbol { g.lhs(p.rule) }

  /// Adds `p` to the latest earleme if it is not already there.
  mutating func insertEarley(_ p: PartialParse) {
    if !partials[currentEarlemeStart...].contains(p) { partials.append(p) }
  }

  /// Adds the Leo item (`s`, `p`) to the latest earleme if it is not already there.
  mutating func insertLeo(_ p: PartialParse, transition s: Grammar.Symbol) {
    if let i = leos[currentLeoStart...].firstIndex(where: { l in l.transition == s }) {
      assert(leos[i].parse == p)
      return
    }
    leos.append((s, p))
  }

  func leoItems(at l: SourcePosition) -> Leos.SubSequence {
    l == currentEarleme ? leos[earlemeStart[l].leo...]
      : leos[earlemeStart[l].leo..<earlemeStart[l+1].leo]
  }

  func leoParse(at i: SourcePosition, transition: Grammar.Symbol) -> PartialParse? {
    leoItems(at: i).first { l in l.transition == transition }?.parse ?? nil
  }

  /// The earleme to which we're currently adding items.
  var currentEarleme: Int { earlemeStart.count - 1 }

  /// The index in `partials` at which the items in the current earleme begin.
  var currentEarlemeStart: Partials.Index { earlemeStart.last!.earley }
  var currentLeoStart: Leos.Index { earlemeStart.last!.leo }

  /// Prepares `self` to recognize an input of length `n`.
  mutating func initialize(inputLength n: Int) {
    partials.removeAll(keepingCapacity: true)
    earlemeStart.removeAll(keepingCapacity: true)
    leos.removeAll(keepingCapacity: true)
    earlemeStart.reserveCapacity(n + 1)
    partials.reserveCapacity(n + 1)
    earlemeStart.append((earley: 0, leo: 0))
  }

  /// Recognizes the sequence of symbols in `source` as a parse of `start`.
  public mutating func recognize<Source: Collection>(_ source: Source, as start: RawSymbol)
    where Source.Element == RawSymbol
  {
    let start = Grammar.Symbol.some(start)
    let source = source.lazy.map { s in Grammar.Symbol.some(s) }
    initialize(inputLength: source.count)

    for r in g.alternatives(start) {
      partials.append(PartialParse(expecting: r.dotted, at: 0))
    }

    // Recognize each token over its range in the source.
    var tokens = source.makeIterator()

    var i = 0
    while i != earlemeStart.count {
      var j = earlemeStart[i].earley // The partial parse within the current earleme

      while j < partials.count {
        let p = partials[j]
        if !p.isComplete {
          predict(p)
        }
        else {
          reduce(p)
        }
        addLeoItem(p)
        j += 1
      }

      // scans
      if let t = tokens.next() { scan(t) }
      i += 1
    }
  }

  /// Adds partial parses initiating recognition of `postdot(p)` at the current earleme.
  public mutating func predict(_ p: PartialParse) {
    let s = postdot(p)!
    for rhs in g.alternatives(s) {
      insertEarley(PartialParse(expecting: rhs.dotted, at: currentEarleme))
      if s.isNulling { insertEarley(p.advanced()) }
    }
  }

  /// Performs Leo reduction on `p`
  public mutating func reduce(_ p: PartialParse) {
    if let predecessor = leoParse(at: p.start, transition: lhs(p)) {
      insertEarley(PartialParse(expecting: predecessor.rule, at: predecessor.start))
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
      if postdot(p0) == s0 { insertEarley(p0.advanced()) }
    }

    if p.start != currentEarleme {
      for k in earlemeStart[p.start].earley..<earlemeStart[p.start + 1].earley {
        advanceIfPostdotS0(k)
      }
    }
    else { // TODO: can we eliminate this branch?
      var k = earlemeStart[p.start].earley
      while k < partials.count {
        advanceIfPostdotS0(k)
        k += 1
      }
    }
  }

  /// Advances any partial parses expecting `t` at the current earleme.
  mutating func scan(_ t: Grammar.Symbol) {
    var found = false
    for j in partials[currentEarlemeStart...].indices {
      let p = partials[j]
      if postdot(p) == t {
        if !found { earlemeStart.append((partials.count, leos.count)) }
        found = true
        insertEarley(p.advanced())
      }
    }
  }

  public mutating func addLeoItem(_ b: PartialParse) {
    if !isLeoEligible(b.rule) { return }
    let s = g.penult(b.rule)!
    insertLeo(leoPredecessor(b) ?? b.advanced(), transition: s)
  }

  func leoPredecessor(_ b: PartialParse) -> PartialParse? {
    return leoParse(at: b.start, transition: lhs(b))
  }

  func isPenultUnique(_ x: Grammar.Symbol) -> Bool {
    return partials[currentEarlemeStart...]
      .hasUniqueElement { p in g.penult(p.rule) == x }
  }

  func isLeoUnique(_ x: Grammar.DottedRule) -> Bool {
    if let p = g.penult(x) { return isPenultUnique(p) }
    return false
  }

  func isLeoEligible(_ x: Grammar.DottedRule) -> Bool {
    g.isRightRecursive(x) && isLeoUnique(x)
  }
}

extension Parser: CustomStringConvertible {
  public var description: String {
    var lines: [String] = []
    var i = -1
    for j in partials.indices {
      if earlemeStart.count > i + 1 && j == earlemeStart[i + 1].earley {
        i += 1
        lines.append("\n=== \(i) ===")
        for (k, v) in leoItems(at: i) {
          lines.append("  Leo \(k): \(description(v))")
        }
      }
      lines.append(description(partials[j]))
    }
    return lines.joined(separator: "\n")
  }

  func description(_ p: PartialParse) -> String {
    "\(g.description(p.rule))\t(\(p.start))"
  }
}
