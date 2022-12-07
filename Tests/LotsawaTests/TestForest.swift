import Lotsawa

struct TestForest {
  let base: Forest<Symbol.ID>
  let language: TestGrammar
  let recognizer: TestRecognizer

  struct Derivation {
    let base: Forest<Symbol.ID>.Derivation
    let language: TestGrammar

    var ruleName: String {
      "\(language.text(base.lhs)) ::= \(base.rhs.map { language.text($0) }.joined(separator: " "))"
    }

    var rhsOrigins: [SourcePosition] { Array(base.rhsOrigins) }
  }

  func derivations(of lhsName: String, over locus: Range<SourcePosition>) -> [Derivation] {
    base.derivations(of: language.symbols[lhsName]!, over: locus).map {
      Derivation(base: $0, language: language)
    }
  }
}

extension TestForest.Derivation: CustomStringConvertible {
  var description: String { "\(ruleName)@\(rhsOrigins)" }
}

extension TestRecognizer {
  public var forest: TestForest {
    TestForest(base: base.forest, language: language, recognizer: self)
  }
}
