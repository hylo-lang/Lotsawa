// 2. Preliminaries

protocol Rule: Hashable {
  associatedtype RHS: Collection where RHS.Element: Hashable, RHS.Index: Hashable
  typealias SYM = RHS.Element
  var lhs: SYM { get }
  var rhs: RHS { get }

  init<R: Collection>(lhs: SYM, rhs: R) where R.Element == SYM
}

func LHS<R: Rule>(_ r: R) -> R.RHS.Element { r.lhs }
func RHS<R: Rule>(_ r: R) -> R.RHS.SubSequence { r.rhs[...] }

infix operator ==>: ComparisonPrecedence
infix operator ==>+: ComparisonPrecedence
infix operator ==>*: ComparisonPrecedence

// Derivation:
//
// symbol X, string S
//
// X ==> S    ::= Rule r exists s.t. LHS(r) == X and RHS(r) == S
// X ==>+ S   ::= X ==> S, or
//                W ==> T0 . T1 . T2 ... TN and
//                   Ti ==>+ Ri for all i and
//                   S == R0 . R1 . R2 ... RN
// X ==>* S   ::= X == S or X ==>+ S


protocol AnyGrammar {
  typealias SYM = RULE.SYM
  // A set of the symbols
  associatedtype Vocabulary: Collection where Vocabulary.Element == SYM
  associatedtype RULE: Rule

  associatedtype Rules: Collection where Rules.Element == RULE
  typealias STR = RULE.RHS.SubSequence
  associatedtype Accept: SetAlgebra where Accept.Element == SYM
  associatedtype Nullable: SetAlgebra where Nullable.Element == SYM
  associatedtype RulesByLHS: Collection where RulesByLHS.Element == RULE

  typealias ORIGIN = Int
  typealias LOC = ORIGIN

  typealias EIMT = TraditionalEarleyItem<RULE, LOC>

  /// An Earley Set
  associatedtype ES: SetAlgebra, Collection
    where ES.Element == EIMT, ES.ArrayLiteralElement == EIMT

  var vocab: Vocabulary { get }
  var rules: Rules { get }

  // it is assumed that there is a dedicated acceptancerule, acceptRULE and a
  // dedicated acceptancesymbol, acceptSYM = LHS(acceptRULE)
  var acceptRULE: RULE { get }

  /// Returns `true` iff `x` ⟹⃰ 𝜖
  func isNullable(_ x: SYM) -> Bool

  /// Returns the rightmost non-null symbol of x
  func Right_NN(_ x: STR) -> SYM
  func Right_NN(_ r: RULE) -> SYM

  func rulesByLHS(_ x: SYM) -> RulesByLHS

  /// Returns the set of symbols that begin any string derived by s.
  func initialSymbolsOfStringsDerivedStar(by s: SYM) -> InitialSymbolSet
  associatedtype InitialSymbolSet: Collection where InitialSymbolSet.Element == SYM
}

extension AnyGrammar {
  func isNonnull(_ x: SYM) -> Bool { !isNullable(x) }

  /// The unique accepting symbol.
  var acceptSYM: SYM { LHS(acceptRULE) }

  func invariant() {
    // acceptSYM is not on the RHS of any rule
    precondition(rules.allSatisfy { x in !RHS(x).contains(acceptSYM) })

    // only acceptRULE has acceptSYM as its LHS
    precondition(
      rules.allSatisfy { x in acceptSYM != LHS(x) || x == acceptRULE })
  }

  /// Returns the rightmost non-null symbol of x
  func Right_NN(_ x: STR) -> SYM?
    where STR: BidirectionalCollection
  {
    return x.reversed().first { !isNullable($0) }
  }

  /// Returns the rightmost non-null symbol of r
  func Right_NN(_ r: RULE) -> SYM?
    where STR: BidirectionalCollection
  {
    return Right_NN(RHS(r))
  }

  func isDirectlyRightRecursive(_ x: RULE) -> Bool {
    return LHS(x) == Right_NN(x)
  }

  /// xRULE is indirectly right-recursive if and only if
  /// ∃ySTR |Right-NN(xRULE) ⇒+ ySTR ∧Right-NN(ySTR) = LHS(xRULE).
  ///
  /// i.e. some string y derived by Right_NN(x)
  func isIndirectlyRightRecursive(_ x: RULE) -> Bool {
    var visited: Set<SYM> = []
    var q: Set<SYM> = [Right_NN(x)]

    while let s = q.popFirst() {
      visited.insert(s)
      for r in rulesByLHS(s) {
        let s1 = Right_NN(r)
        if s1 == LHS(x) { return true }
        if !visited.contains(s1) {
          q.insert(s1)
        }
      }
    }
    return false
  }

  func isRightRecursive(_ x: RULE) -> Bool {
    isDirectlyRightRecursive(x) || isIndirectlyRightRecursive(x)
  }

  func isNullable(_ x: STR) -> Bool {
    x.allSatisfy { s in isNullable(s) }
  }
}

// 3. Rewriting the grammar
//
// Following Aycock and Horspool[2], all nullable symbols in grammar g are
// nulling – every symbol which can derive the null string always derives the
// null string.  The elimination of empty rules and proper nullables is done by
// rewriting the grammar. [2] shows how to do this without loss of generality.

struct Dotted<R: Rule>: Hashable {
  let rule: R
  var dot: R.RHS.Index
}

func LHS<R: Rule>(_ r: Dotted<R>) -> R.SYM { LHS(r.rule) }

/// A traditional Earley item
struct TraditionalEarleyItem<R: Rule, Origin: Hashable>: Hashable {
  var dr: Dotted<R>
  var origin: Origin
}

/// 4. Earley's Algorithm
extension AnyGrammar {
  typealias DR = Dotted<RULE>

  func postdotSTR(_ x: DR) -> STR { RHS(x.rule)[x.dot...] }

  func Postdot(_ x: DR) -> SYM? { postdotSTR(x).first }

  func Next(_ x: DR) -> DR? {
    x.dot == RHS(x.rule).endIndex ? nil
      : DR(rule: x.rule, dot: RHS(x.rule).index(after: x.dot))
  }

  func Penult(_ x: DR) -> SYM? {
    guard let next = Postdot(x) else { return nil }
    let post = postdotSTR(Next(x)!)
    return !isNullable(next) && isNullable(post) ? next : nil
  }

  /// A penult is a dotted rule dDR such that Penult(d) ≠ Λ.
  func isPenult(_ x: DR) -> Bool { Penult(x) != nil }

  /// The unique start symbol.  In an Earley grammar, RHS(acceptRULE).count == 1
  var startSYM: SYM { RHS(acceptRULE).first! }

  /// The initial dotted rule is initialDR =[acceptSYM → •startSYM]
  var initialDR: DR { .init(rule: acceptRULE, dot: RHS(acceptRULE).startIndex) }

  /// A predicted dotted rule is a dotted rule, other than the initial dotted
  /// rule, with a dot position of zero,
  func isPredicted(_ r: DR) -> Bool {
    r != initialDR && r.dot == RHS(r.rule).startIndex
  }

  /// A confirmed dotted rule is the initial dotted rule, or a dotted rule with
  /// a dot position greater than zero.
  func isConfirmed(_ r: DR) -> Bool {
    return r == initialDR || r.dot != RHS(r.rule).startIndex
  }

  /// A completed dotted rule is a dotted rule with its dot position after the
  /// end of its RHS.
  func isCompleted(_ r: DR) -> Bool {
    return r.dot == RHS(r.rule).endIndex
  }

  /// A position in the input
  typealias ORIGIN = Int
  typealias LOC = ORIGIN

  typealias EIMT = TraditionalEarleyItem<RULE, LOC>

  /// An Earley Set
//  associatedtype ES: SetAlgebra where Element == EIMT

  typealias Table = [LOC: ES]

  /// ||table[Recce]|| is the total number of Earley items in all Earley sets
  /// for Recce. For example, ||table[Marpa]|| is the total number of Earley
  /// items in all the Earley sets of a Marpa parse.
  func cardinality(_ t: Table) -> Int {
    t.values.joined().count
  }

  func hasAccepted(_ table: Table, _ inputLength: Int) -> Bool {
    table[inputLength]?.contains(EIMT(dr: Next(initialDR)!, origin: 0))
      ?? false
  }
}

/// 5. Operations of the Earley algorithm
///
/// Each location starts with an empty Earley set. For the purposes of this
/// description of Earley, the order of the Earley operations when building an
/// Earley set is non-deterministic. After each Earley operation is performed,
/// its result is unioned with the current Earley set. When no more Earley items
/// can be added, the Earley set is complete. The Earley sets are built in order
/// from 0 to |w|.
extension AnyGrammar {

  /// 5.1 Initialization
  var initialTable: Table {
    [0: [.init(dr: initialDR, origin: 0)]]
  }

  /// 5.2 Scanning
  func scan(
    token: SYM, at previous: LOC, into table: inout Table, predecessor: EIMT
  ) {
    // tokenSYM =w[previousLOC]

    // currentLOC > 0
    // previousLOC = currentLOC − 1
    assert(previous >= 0)
    let current = previous + 1

    // predecessorEIMT = [beforeDR,predecessorORIG]
    let before = predecessor.dr

    // predecessorEIMT ∈previousES
    assert(table[previous, default: []].contains(predecessor))

    // Postdot(beforeDR) = tokenSYM
    assert(Postdot(before) == token)

    // insert: {[Next(beforeDR),predecessorORIG]}
    table[current, default: []]
      .insert(EIMT(dr: Next(before)!, origin: predecessor.origin))
  }

  /// 5.3 Reduction
  func reduceEarley(
    _ component: EIMT, at current: LOC, into table: inout Table, predecessor: EIMT
  ) {
    // componentEIMT = [[lhsSYM →rhsSTR•],component-origLOC]
    let lhs = LHS(component.dr)
    assert(Next(component.dr) == nil)

    // componentEIMT ∈ currentES
    assert(table[current, default: []].contains(component))

    // predecessorEIMT = [beforeDR,predecessorORIG]
    let before = predecessor.dr

    // predecessorEIMT ∈ component-origES
    assert(table[component.origin, default: []].contains(predecessor))

    // Postdot(beforeDR) = lhsSYM
    assert(Postdot(before) == lhs)

    // insert: {[Next(beforeDR),predecessorORIG]}
    table[current, default: []]
      .insert(EIMT(dr: Next(before)!, origin: predecessor.origin))
  }

  /// 5.4 Prediction
  func predict(
    predecessor: EIMT, at current: LOC, into table: inout Table
  ) {

    // predecessorEIMT =[predecessorDR,predecessorORIG]
    // predecessorEIMT ∈currentES
    assert(table[current, default: []].contains(predecessor))

    // insert: {
    //   [[LSYM → •rhSTR],currentLOC] such that
    //   [LSYM →rhSTR] ∈ rules
    //   ∧ ∃ (zSTR | Postdot(predecessorDR) ⇒∗ LSYM .zSTR)
    // }

    if let nextSymbol = Postdot(predecessor.dr) {
      for l in initialSymbolsOfStringsDerivedStar(by: nextSymbol) {
        for r in rulesByLHS(l) {
          table[current, default: []]
            .insert(EIMT(dr: Dotted(rule: r, dot: RHS(r).startIndex), origin: current))
        }
      }
    }
  }
}

/// A traditional Leo item
struct TraditionalLeoItem<R: Rule, Origin: Hashable>: Hashable {
  var topDR: Dotted<R>
  var transition: R.SYM
  var origin: Origin
}

/// Earley sets enhanced with traditional Leo items.
protocol LeoEarleySet: SetAlgebra, Collection {
  associatedtype RULE: Rule
  associatedtype LOC: Hashable

  /// - In each Earley set, there is at most one Leo item per symbol.
  var leoItem: [RULE.SYM: TraditionalLeoItem<RULE, LOC>] { get }
}

/// 6. The Leo Algorithm.
///
/// - Summary: spotting unambiguous potential right recursions and memoizing them by Earley set.
///
protocol LeoGrammar: AnyGrammar where ES: LeoEarleySet, ES.LOC == ORIGIN, ES.RULE == RULE
{
  typealias LIMT = TraditionalLeoItem<RULE, LOC>
}

extension Collection {
  var hasUniqueElement: Bool { !isEmpty && dropFirst().isEmpty }
}

extension LeoGrammar {

  /// Define containment of a dotted rule in a Earley set of EIMT’s as
  ///
  ///   Contains(iES,dDR) ≝ ∃bEIMT,jORIG |
  ///       bEIMT = [dDR,jORIG] ∧ bEIMT ∈iES.
  ///
  func Contains(_ i: ES, _ d: DR) -> Bool {
    i.contains { b in b.dr == d }
  }

  /// A dotted rule dDR is Leo unique in the Earley set at iES if and only if
  ///
  /// Penult(dDR) ≠̸ Λ
  ///   ∧ ∀d2DR (
  ///      Contains(iES,d2DR) ⇒
  ///      Postdot(dDR) = Postdot(d2DR) ⇒ dDR = d2DR).
  ///
  /// i.e. if it is the only rule in iES with its postdot symbol.
  func isLeoUnique(_ d: DR, in iES: ES) -> Bool {
    if Penult(d) == nil { return false }
    let s = Postdot(d)
    return iES.lazy.map { $0.dr }.filter { dr2 in Postdot(dr2) == s }
      .elementsEqual(CollectionOfOne(d))
  }

  /// If dDR is Leo unique, then the symbol Postdot(dDR) is also said to be Leo unique.
  func isLeoUnique(_ s: SYM, in iES: ES) -> Bool {
    iES.lazy.filter { item in Postdot(item.dr) == s }.hasUniqueElement
  }

  /// In cases where a symbol transitionSYM is Leo unique in iES, we can speak
  /// of the dotted rule for transitionSYM.
  func dottedRuleForUnique(_ transitionSYM: SYM, in iES: ES) -> DR {
    var postdotItems = iES.lazy.filter { item in Postdot(item.dr) == transitionSYM }
      .makeIterator()
    let r = postdotItems.next()
    precondition(postdotItems.next() == nil, "Non-unique transition symbol \(transitionSYM)")
    return r!.dr
  }

  /// In Leo’s original algorithm, any penult was treated as a potential right-
  /// recursion. Marpa applies the Leo memoizations in more restricted
  /// circumstances. For Marpa to consider a dotted rule
  ///
  ///    candidateDR = [candidateRULE,i]
  ///
  /// for Leo memoization, candidateDR must be a penult and candidateRULE must
  /// be right-recursive.
  func isMarpaLeoMemoizationCandidate(_ candidate: DR) -> Bool {
    isPenult(candidate) && isRightRecursive(candidate.rule)
  }

  /// 6.1. Leo reduction.
  func leoReduce(
    _ component: EIMT, at current: LOC, into table: inout Table, predecessor: LIMT
  ) {
    // componentEIMT = [[lhsSYM →rhsSTR•],component-origLOC]
    let lhsSYM = LHS(component.dr)
    assert(Next(component.dr) == nil)

    // componentEIMT ∈ currentES
    assert(table[current, default: []].contains(component))

    // predecessorLIMT = [topDR,lhsSYM,topORIG]
    assert(predecessor.transition == lhsSYM)

    // predecessorLIMT ∈ component-origES
    assert(table[component.origin, default: []].leoItem.values.contains(predecessor))

    // insert: {[topDR, topORIG]}
    table[current, default: []].insert(EIMT(dr: predecessor.topDR, origin: predecessor.origin))
  }

  /// 6.2 Changes to Earley reduction.
  ///
  /// Earley reduction still applies, with an additional premise:
  ///
  ///   ¬∃xLIMT | xLIMT ∈ component-origES
  ///                       ∧xLIMT =[xDR,lhsSYM,xORIG]
  func reduceLeo(
    _ component: EIMT, at current: LOC, into table: inout Table, predecessor: EIMT
  ) {
    // componentEIMT = [[lhsSYM →rhsSTR•],component-origLOC]
    let lhs = LHS(component.dr)

    let component_orig = table[component.origin, default: []]
    if let p = component_orig.leoItem[lhs] {
      leoReduce(component, at: current, into: &table, predecessor: p)
    }
    else {
      reduceEarley(component, at: current, into: &table, predecessor: predecessor)
    }
  }
}
