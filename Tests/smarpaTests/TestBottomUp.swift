@testable import smarpa
import XCTest

/// Diagnostic output
extension BottomUpChartParser {
  /// Returns the name of symbol s
  func symbolName(_ s: SymbolID) -> String {
    "\(Symbol.names[s])"
  }

  func ruleString(_ r: RuleTail) -> String {
    let r1 = rulesByRHSStart.values.lazy.joined().first { $0.upperBound == r.upperBound }!
    let head = "\(symbolName(ruleStore[r.upperBound])) => "
    let rhsPrefix = r1 == r ? ""
      : (ruleStore[r1.lowerBound..<r.lowerBound].map(symbolName) + ["."])
          .joined(separator: " ")
    let tail = ruleStore[r].lazy.map(symbolName).joined(separator: " ")
    return head + rhsPrefix + tail
  }
}

/// Grammar definition
fileprivate enum Symbol: Int, CaseIterable {
  case LPAREN, RPAREN, NUMBER, PLUS, MINUS, TIMES, DIVIDE
  case term, factor, expr

  static let names = Array(allCases)
}

/// A tiny DSL for defining grammar rules.
infix operator => : AssignmentPrecedence
infix operator ~: MultiplicationPrecedence
fileprivate func ~(a: Symbol, b: Symbol) -> [Symbol] { [a, b] }
fileprivate func ~(a: [Symbol], b: Symbol) -> [Symbol] { a + [b] }
fileprivate func =>(lhs: Symbol, rhs: Symbol) -> [Symbol] { [lhs, rhs] }
fileprivate func =>(lhs: Symbol, rhs: [Symbol]) -> [Symbol] { [lhs] + rhs }

class BottomUpTest: XCTestCase {
  func testQuick() {
    let grammar: [[Symbol]] = [
      .expr => .term,
      .expr => .term ~ .PLUS ~ .term,
      .expr => .term ~ .MINUS ~ .term,

      .term => .factor,
      .term => .factor ~ .TIMES ~ .factor,
      .term => .factor ~ .DIVIDE ~ .factor,

      .factor => .NUMBER,
      .factor => .LPAREN ~ .expr ~ .RPAREN,
      .factor => .PLUS ~ .factor,
      .factor => .MINUS ~ .factor,
    ]

    var parser = BottomUpChartParser(
      grammar.lazy.map {
        (lhs: $0.first!.rawValue, rhs: $0.dropFirst().lazy.map { $0.rawValue })
      }
    )

    let input: [Symbol] = [
      .MINUS, .LPAREN, .NUMBER, .PLUS, .NUMBER, .TIMES, .MINUS, .NUMBER, .RPAREN,
      .DIVIDE, .NUMBER,
      .PLUS, .NUMBER]

    parser.parse(input.lazy.map {$0.rawValue})
  }
}
