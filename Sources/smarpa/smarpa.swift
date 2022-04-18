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

  /// A penult is a dotted rule dDR such that Penult(d) ̸= Λ.
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
  /// end of its RHS
  func isCompleted(_ r: DR) -> Bool {
    return r.dot == RHS(r.rule).endIndex
  }

  /// A position in the input
  typealias ORIGIN = Int
  typealias LOC = ORIGIN

  typealias EIMT = TraditionalEarleyItem<RULE, LOC>
  /// An Earley Set
  typealias ES = Set<EIMT>

  typealias Table = [LOC: ES]

  /// ||table[Recce]|| is the total number of Earley items in all Earley sets
  /// for Recce. For example, ||table[Marpa]|| is the total number of Earley
  /// items in all the Earley sets of a Marpa parse.
  func cardiality(_ t: Table) -> Int {
    t.values.joined().count
  }

  func hasAccepted(_ table: Table, _ inputLength: Int) -> Bool {
    table[inputLength]?.contains(EIMT(dr: Next(initialDR)!, origin: 0))
      ?? false
  }
}

/// 5. Operations of the Earley algorithm
extension AnyGrammar {

  /// 5.1 Initialization
  var initialTable: Table {
    [0: [.init(dr: initialDR, origin: 0)]]
  }

  /// 5.2 Scanning
  func scan(
    token: SYM, at previousLOC: LOC, into table: inout Table, predecessor: EIMT
  ) {
    assert(previousLOC >= 0)
    let currentLOC = previousLOC + 1
    assert(table[previousLOC]!.contains(predecessor))
    let beforeDR = predecessor.dr
    assert(Postdot(beforeDR) == token)
    table[currentLOC, default: []]
      .insert(EIMT(dr: Next(beforeDR)!, origin: predecessor.origin))
  }
}
