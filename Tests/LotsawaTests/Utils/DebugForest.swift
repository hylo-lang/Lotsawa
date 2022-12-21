import Lotsawa

struct DebugForest {
  let base: Forest<Symbol.ID>
  let language: DebugGrammar
  let recognizer: DebugRecognizer

  struct Derivation {
    let base: Forest<Symbol.ID>.Derivation
    let language: DebugGrammar

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

extension DebugForest.Derivation: CustomStringConvertible {
  var description: String { "\(ruleName)@\(rhsOrigins)" }
}

extension DebugRecognizer {
  public var forest: DebugForest {
    DebugForest(base: base.forest, language: language, recognizer: self)
  }
}
