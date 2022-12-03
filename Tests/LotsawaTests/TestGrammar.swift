import Lotsawa

/// A `DefaultGrammar` wrapper engineered for convenient testing.
///
/// `TestGrammar` can be constructed from a BNF string and it has a human-readable string
/// representation.
struct TestGrammar {
  /// Representation produced by Citron parser from the string.
  enum AST {
    typealias RuleList = [Rule]
    typealias Rule = (lhs: Token, alternatives: [RHS])
    typealias RHS = [Token]
  }

  /// The underlying raw grammar.
  var raw = DefaultGrammar(recognizing: Symbol(0))

  /// A mapping from raw grammar symbol to its name in the parsed source.
  var symbolName: [String]

  /// A mapping from symbol name in the parsed source to raw grammar symbol.
  var symbols: [String: Symbol] = [:]
}

extension TestGrammar {
  /// Creates an instance by parsing `bnf`, or throws an error if `bnf` can't be parsed.
  init(
    recognizing startSymbol: String, per bnf: String,
    file: String = #filePath, line: Int = #line
  ) throws {
    symbols[startSymbol] = Symbol(0)
    symbolName = [startSymbol]
    let tokens = testGrammarScanner.tokens(
      in: bnf, fromFile: file, unrecognizedToken: .ILLEGAL_CHARACTER)
    let parser = TestGrammarParser()
    for (id, text, position) in tokens {
      try parser.consume(token: AST.Token(id, text, at: position), code: id)
    }
    let rules: AST.RuleList = try parser.endParsing()

    /// Translates t into a raw grammar symbol, memoizing name/symbol relationships.
    func demandSymbol(_ t: AST.Token) -> Symbol {
      let name = String(t.text)
      if let r = symbols[name] { return r }
      let s = Symbol(symbolName.count)
      symbols[name] = s
      symbolName.append(name)
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
  /// Returns the result of parsing `self` as a `TestGrammar`, or throws if `self` can't be parsed.
  func asTestGrammar(
    recognizing startSymbol: String, file: String = #filePath, line: Int = #line
  ) throws -> TestGrammar {
    try TestGrammar(recognizing: startSymbol, per: self, file: file, line: line)
  }
}

extension TestGrammar: CustomStringConvertible {
  /// Returns the human-readable name for `s`.
  func text(_ s: Symbol) -> String { symbolName[Int(s.id)] }

  /// Returns a human-readable representation of `r`.
  func text(_ r: DefaultGrammar.Rule) -> String {
    text(r.lhs) + " ::= " + r.rhs.lazy.map { s in text(s) }.joined(separator: " ")
  }

  /// Returns a human-readable representation of `p` as a dotted rule.
  func dottedText(_ p: DefaultGrammar.Position) -> String {
    let r0 = raw.rule(containing: p)
    let r = raw.storedRule(r0)

    let rhsText = r.rhs.lazy.map { s in text(s) }
    let predotRHSCount = Int(p) - r.rhs.startIndex
    return text(r.lhs) + " ::= " + rhsText.prefix(predotRHSCount).joined(separator: " ") + "•"
    + rhsText.dropFirst(predotRHSCount).joined(separator: " ")
  }

  /// Returns a human-readable representation of `dotInGrammar` as the position of the dot in a
  /// dotted rule, with `predotPositions` enumerated at the position before the dot.
  func derivationText<PredotPositions: Collection<SourcePosition>>(
    origin: SourcePosition,
    dotInGrammar: DefaultGrammar.Position,
    dotInSource: SourcePosition?,
    predotPositions: PredotPositions
  ) -> String {
    let r0 = raw.rule(containing: dotInGrammar)
    let r = raw.storedRule(r0)

    let rhsText = r.rhs.lazy.map { s in text(s) }
    let predotRHSCount = Int(dotInGrammar) - r.rhs.startIndex
    return "[\(origin) \(text(r.lhs))"
      + (dotInSource == nil || Int(dotInGrammar) != r.rhs.endIndex
           ? "\(dotInSource == nil ? "]" : "")\t::= " : " \(dotInSource!)]\t::= ")
      + "[\(origin)\(predotRHSCount == 0 ? "" : " ")"
      + rhsText.prefix(max(predotRHSCount - 1, 0)).joined(separator: " ")
      + (
        predotRHSCount < 2 || predotPositions.isEmpty ? " "
          : " {\(predotPositions.lazy.map(String.init).joined(separator: " "))} ")
      + rhsText.prefix(predotRHSCount).suffix(1).joined() // predot symbol
      + (predotRHSCount == 0 || dotInSource == nil ? "•" : " \(dotInSource!)]\t•")
      + rhsText.dropFirst(predotRHSCount).joined(separator: " ")
  }

  /// Returns the set of names of `s`'s elements.
  func text(_ s: Set<Symbol>) -> Set<String> { Set(s.lazy.map(text)) }

  /// Returns a human-readable representation of `self`.
  var description: String {
    raw.rules.lazy.map { r in text(r) }.joined(separator: "\n")
  }
}
