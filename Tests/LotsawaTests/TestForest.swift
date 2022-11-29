import Lotsawa

struct TestForest {
  let base: Forest<Symbol.ID>
  let language: TestGrammar

  struct Derivation {
    let ruleName: String
    let rhsOrigins: [SourcePosition]
  }

  func derivations(of lhsName: String, over locus: Range<SourcePosition>) -> [Derivation] {
    var source = base.derivations(of: language.symbols[lhsName]!, over: locus)
    var r: [Derivation] = []
    while !source.isEmpty {
      let d = base.first(of: source)
      r.append(
        Derivation(
          ruleName: "\(language.text(d.lhs)) ::= "
            + "\(d.rhs.map { language.text($0) }.joined(separator: " "))",
          rhsOrigins: Array(d.rhsOrigins)))
      base.removeFirst(from: &source)
    }
    return r
  }
}

extension TestRecognizer {
  public var forest: TestForest {
    TestForest(base: base.forest, language: language)
  }
}
