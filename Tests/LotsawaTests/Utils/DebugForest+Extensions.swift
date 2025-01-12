import Lotsawa
import XCTest

public extension DebugForest {
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
