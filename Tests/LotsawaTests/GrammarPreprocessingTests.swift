@testable import Lotsawa

import XCTest

class GrammarPreprocessingTests: XCTestCase {

  func test() throws {
    try print(
      TestGrammar(
        """
          a ::=
             _
             a b
             a c

         b ::=
           d 'foo'

         c ::=
           d 'bar'



        """
              ))
  }
}
