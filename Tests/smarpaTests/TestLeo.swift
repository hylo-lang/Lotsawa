@testable import smarpa
import XCTest

/// Grammar definition
class LeoTest: XCTestCase {
  func testArithmetic() {
    enum Symbol: Int {
      case PLUS_MINUS, TIMES_DIVIDE, LPAREN, RPAREN, DIGIT
      case Sum, Product, Factor, Number
    }

    let base = EarleyGrammar<Symbol>(
      [
        (lhs: .Sum, rhs: [.Sum, .PLUS_MINUS, .Product]),
        (lhs: .Sum, rhs: [.Product]),
        (lhs: .Product, rhs: [.Product, .TIMES_DIVIDE, .Factor]),
        (lhs: .Product, rhs: [.Factor]),
        (lhs: .Factor, rhs: [.LPAREN, .Sum, .RPAREN]),
        (lhs: .Factor, rhs: [.Number]),
        (lhs: .Number, rhs: [.DIGIT, .Number]),
        (lhs: .Number, rhs: [.DIGIT]),
      ])

    let arithmetic = MyLeoGrammar(base: base)
    var parser = LeoParser(arithmetic)

    parser.recognize(
      [.DIGIT, .PLUS_MINUS, .LPAREN, .DIGIT, .TIMES_DIVIDE, .DIGIT, .PLUS_MINUS, .DIGIT, .RPAREN],
      as: .Sum)

    print(parser)
  }

  func testRightRecursion() {
    enum Symbol: Int {
      case a, A
    }

    let base = EarleyGrammar<Symbol>(
      [
        (lhs: .A, rhs: [.a, .A]),
        (lhs: .A, rhs: []),
      ]
    )
    let rightRecursive = MyLeoGrammar(base: base)
    var parser = LeoParser(rightRecursive)

    parser.recognize(repeatElement(.a, count: 5), as: .A)

    print(parser)
  }
}
