@testable import smarpa
import XCTest

/// Grammar definition
class EarleyTest: XCTestCase {
  func testArithmetic() {
    enum Symbol: Int {
      case PLUS_MINUS, TIMES_DIVIDE, LPAREN, RPAREN, DIGIT
      case Sum, Product, Factor, Number
    }

    let arithmetic = EarleyGrammar<Symbol>(
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

    var parser = EarleyParser(arithmetic)

    parser.recognize(
      [.DIGIT, .PLUS_MINUS, .LPAREN, .DIGIT, .TIMES_DIVIDE, .DIGIT, .PLUS_MINUS, .DIGIT, .RPAREN],
      as: .Sum)

    print(parser)
  }

  func testEmptyRules() {
    enum Symbol: Int {
      case A, B
    }

    let empty = EarleyGrammar<Symbol>(
      [
        (lhs: .A, rhs: []),
        (lhs: .A, rhs: [.B]),
        (lhs: .B, rhs: [.A]),
      ]
    )
    var parser = EarleyParser(empty)

    parser.recognize([], as: .A)

    print(parser)
  }

  func testRightRecursion() {
    enum Symbol: Int {
      case a, A
    }

    let rightRecursive = EarleyGrammar<Symbol>(
      [
        (lhs: .A, rhs: [.a, .A]),
        (lhs: .A, rhs: []),
      ]
    )
    var parser = EarleyParser(rightRecursive)

    parser.recognize(repeatElement(.a, count: 5), as: .A)

    print(#file, #function)
    print(parser)
  }

  func testRightRecursion2() {
    enum Symbol: Int {
      case a, A
    }

    let rightRecursive = EarleyGrammar<Symbol>(
      [
        (lhs: .A, rhs: [.a, .A]),
        (lhs: .A, rhs: [.a]),
      ]
    )
    var parser = EarleyParser(rightRecursive)

    parser.recognize(repeatElement(.a, count: 5), as: .A)

    print(#file, #function)
    print(parser)
  }
}
