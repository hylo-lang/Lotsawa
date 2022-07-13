typealias TestGrammar = [TestGrammarRule]
typealias TestGrammarRule = (lhs: TestGrammarToken, alternatives: [TestGrammarRHS])
typealias TestGrammarRHS = [TestGrammarToken]

extension TestGrammar {
  init(_ bnf: String, file: String = #filePath, line: Int = #line) throws {
    var strippedBNF = bnf
    while strippedBNF.last?.isWhitespace == true { _ = strippedBNF.popLast() }

    let tokens = testGrammarScanner.tokens(
      in: strippedBNF, fromFile: file, unrecognizedToken: .ILLEGAL_CHARACTER)
    let parser = TestGrammarParser()
    for (id, text, position) in tokens {
      try parser.consume(token: TestGrammarToken(id, text, at: position), code: id)
    }
    self = try parser.endParsing()
  }
}

//extension Grammar {
//  init(testBNF: String, file: String = __FILEPATH__, line: Int = __LINE__) throws {
//  }
//}
