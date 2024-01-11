import Lotsawa

/// A `DefaultGrammar` wrapper engineered for convenient testing.
///
/// `DebugGrammar` can be constructed from a BNF string and it has a human-readable string
/// representation.
struct DebugGrammar {
  /// Representation produced by Citron parser from the string.
  enum AST {
    /// The rules extracted from BNF.
    typealias RuleList = [Rule]

    /// A parse rule.
    typealias Rule = (lhs: Token, alternatives: [RHS])

    /// The RHS of a rule.
    typealias RHS = [Token]
  }

  /// The underlying raw grammar.
  var raw = DefaultGrammar(recognizing: Symbol(0))

  /// A mapping from raw grammar symbol to its name in the parsed source.
  var symbolName: [String]

  /// A mapping from symbol name in the parsed source to raw grammar symbol.
  var symbols: [String: Symbol] = [:]
}

extension DebugGrammar {
  /// Creates an instance by parsing `bnf`, or throws an error if `bnf` can't be parsed.
  init(
    recognizing startSymbol: String, per bnf: String,
    file: String = #filePath, line: Int = #line
  ) throws {
    symbols[startSymbol] = Symbol(0)
    symbolName = [startSymbol]
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
  /// Returns the result of parsing `self` as a `DebugGrammar`, or throws if `self` can't be parsed.
  func asTestGrammar(
    recognizing startSymbol: String, file: String = #filePath, line: Int = #line
  ) throws -> DebugGrammar {
    try DebugGrammar(recognizing: startSymbol, per: self, file: file, line: line)
  }
}

extension DebugGrammar: CustomStringConvertible {
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

  /// Returns the set of names of `s`'s elements.
  func text(_ s: Set<Symbol>) -> Set<String> { Set(s.lazy.map(text)) }

  /// Returns a human-readable representation of `self`.
  var description: String {
    raw.rules.lazy.map { r in text(r) }.joined(separator: "\n")
  }
}
