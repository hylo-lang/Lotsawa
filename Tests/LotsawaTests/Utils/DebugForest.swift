import Lotsawa
import XCTest

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

extension DebugForest {
  func checkUniqueDerivation(
    ofLHS expectedRule: String,
    over locus: Range<SourcePosition>,
    rhsOrigins expectedRHSOrigins: [SourcePosition],
    _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line
  ) throws {
    let d0 = derivations(of: String(expectedRule.split(separator: " ").first!), over: locus)
    let d = try d0.checkedOnlyElement(message() + "\n\(recognizer)", file: file, line: line)
    XCTAssertEqual(
      d.ruleName, expectedRule, "ruleName mismatch" + message() + "\n\(recognizer)",
      file: file, line: line)
    XCTAssertEqual(
      d.rhsOrigins, expectedRHSOrigins, "rhsOrigin mismatch" + message() + "\n\(recognizer)",
      file: file, line: line)
  }
}
