import Lotsawa
import XCTest

/// A wrapped `Forest` with conveniences for testing and debugging.
struct DebugForest {
  /// The underlying forest.
  var base: Forest<Symbol.ID>

  /// The language recognized.
  let language: DebugGrammar

  /// The recognizer used.
  let recognizer: DebugRecognizer

  /// A wrapped `Forest.Derivation` with conveniences for testing and debugging.
  struct Derivation {
    /// The underlying derivation.
    let base: Forest<Symbol.ID>.Derivation

    /// The language recognized.
    let language: DebugGrammar

    /// A textual representation of the BNF rule recognized.
    var ruleName: String {
      "\(language.text(base.lhs)) ::= \(base.rhs.map { language.text($0) }.joined(separator: " "))"
    }

    /// The position at which each constituent RHS symbol of the rule was recognized.
    var rhsOrigins: [SourcePosition] { Array(base.rhsOrigins) }
  }

  mutating func derivations(of lhsName: String, over locus: Range<SourcePosition>) -> [Derivation] {
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

extension DebugForest {
  /// `XCTAssert`s that `self` is the only derivation of its LHS symbol over `locus`, that its rule
  /// has the textual representation `expectedRule`, and that its RHS symbols start at `rhsOrigins`,
  /// failing with `message` otherwise.
  mutating func checkUniqueDerivation(
    ofLHS expectedRule: String,
    over locus: Range<SourcePosition>,
    rhsOrigins expectedRHSOrigins: [SourcePosition],
    _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line
  ) throws {
    let d0 = derivations(of: String(expectedRule.split(separator: " ").first!), over: locus)
    let d = try d0.checkedOnlyElement(message() + "\n\(recognizer)", file: file, line: line)
    XCTAssertEqual(
      d.ruleName, expectedRule, "ruleName mismatch " + message() + "\n\(recognizer)",
      file: file, line: line)
    XCTAssertEqual(
      d.rhsOrigins, expectedRHSOrigins, "rhsOrigin mismatch " + message() + "\n\(recognizer)",
      file: file, line: line)
  }
}
