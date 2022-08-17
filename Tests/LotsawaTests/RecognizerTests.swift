import Lotsawa

import XCTest

class RecognizerTests: XCTestCase {
  func testLeftRecursiveArithmetic() throws {
    let g = try """
      sum ::= sum additive product | product
      product ::= product multiplicative factor | factor
      factor ::= '(' sum ')' | number
      number ::= number digit | digit
      digit ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
      additive ::= '+' | '-'
      multiplicative ::= '*' | '/'
      """
      .asTestGrammar()
    var r = TestRecognizer(g, startSymbol: "sum")
    let unrecognized = r.recognize("42+(9/3-20)")

    XCTAssertNil(unrecognized, "\n\(r)")
  }

  func testRightRecursiveArithmetic() throws {
    let g = try """
      sum ::= sum additive product | product
      product ::= product multiplicative factor | factor
      factor ::= '(' sum ')' | number
      number ::= digit number | digit
      digit ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
      additive ::= '+' | '-'
      multiplicative ::= '*' | '/'
      """
      .asTestGrammar()
    var r = TestRecognizer(g, startSymbol: "sum")
    let unrecognized = r.recognize("42+(9/3-20)")

    XCTAssertNil(unrecognized, "\n\(r)")

    // Intended parse tree:
    //
    // (sum
    //
    //  (sum
    //   (product
    //    (factor
    //     (number
    //      (digit "4")
    //      (number (digit "2"))))))
    //
    //  (additive "+")
    //
    //  (product
    //
    //   (factor
    //    "("
    //
    //    (sum
    //
    //     (sum
    //      (product
    //       (product (factor (number (digit "9"))) )
    //       (multiplicative "/")
    //       (factor (number (digit "3")))))
    //
    //     (additive "-")
    //
    //     (product
    //      (factor
    //       (number
    //        (digit "2")
    //        (number (digit "0")))))
    //
    //     ")"
    //     ))))
  }
}
