/// A wrapped `Forest` with conveniences for testing and debugging.
public struct DebugForest {
  /// The underlying forest.
  public var base: Forest<Symbol.ID>

  /// The language recognized.
  public let language: DebugGrammar

  /// The recognizer used.
  public let recognizer: DebugRecognizer

  /// A wrapped `Forest.Derivation` with conveniences for testing and debugging.
  public struct Derivation {
    /// The underlying derivation.
    public let base: Forest<Symbol.ID>.Derivation

    /// The language recognized.
    public let language: DebugGrammar

    /// A textual representation of the BNF rule recognized.
    public var ruleName: String {
      "\(language.text(base.lhs)) ::= \(base.rhs.map { language.text($0) }.joined(separator: " "))"
    }

    /// The position at which each constituent RHS symbol of the rule was recognized.
    public var rhsOrigins: [SourcePosition] { Array(base.rhsOrigins) }
  }

  public mutating func derivations(of lhsName: String, over locus: Range<SourcePosition>) -> [Derivation] {
    base.derivations(of: language.symbols[lhsName]!, over: locus).map {
      Derivation(base: $0, language: language)
    }
  }
}

extension DebugForest.Derivation: CustomStringConvertible {

  public var description: String { "\(ruleName)@\(rhsOrigins)" }

}

public extension DebugRecognizer {
  var forest: DebugForest {
    DebugForest(base: base.forest, language: language, recognizer: self)
  }
}
