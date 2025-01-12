import Lotsawa

extension DebugGrammar {
  /// Representation produced by Citron parser from the string.
  enum AST {
    /// The rules extracted from BNF.
    public typealias RuleList = [Rule]

    /// A parse rule.
    public typealias Rule = (lhs: Token, alternatives: [RHS])

    /// The RHS of a rule.
    public typealias RHS = [Token]
  }

  /// Creates an instance by parsing `bnf`, or throws an error if `bnf` can't be parsed.
  init(
    recognizing startSymbol: String, per bnf: String,
    file: String = #filePath, line: Int = #line
  ) throws {
    self.init()
    symbols[startSymbol] = Symbol(0)
    symbolName[0] = startSymbol
    let tokens = testGrammarScanner.tokens(
      in: bnf, fromFile: file, unrecognizedCharacter: .ILLEGAL_CHARACTER)
    let parser = DebugGrammarParser()
    for (id, text, position) in tokens {
      try parser.consume(token: AST.Token(id, text, at: position), code: id)
    }
    let rules: AST.RuleList = try parser.endParsing()

    /// Translates t into a raw grammar symbol, memoizing name/symbol relationships.
    func demandSymbol(_ t: AST.Token) -> Symbol {
      let name = String(t.text)
      if let r = symbols[name] { return r }
      let s = Symbol(symbolName.count)
      nameSymbol(s, name)
      return s
    }

    for (lhsToken, alternatives) in rules {
      let lhs = demandSymbol(lhsToken)
      for a in alternatives {
        raw.addRule(lhs: lhs, rhs: a.map(demandSymbol))
      }
    }
  }
}

extension String {
  /// Returns the result of parsing `self` as a `DebugGrammar`, or throws if `self` can't be parsed.
  func asTestGrammar(
    recognizing startSymbol: String, file: String = #filePath, line: Int = #line
  ) throws -> DebugGrammar {
    try DebugGrammar(recognizing: startSymbol, per: self, file: file, line: line)
  }
}
