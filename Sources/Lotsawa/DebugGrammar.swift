/// A `DefaultGrammar` wrapper engineered for convenient testing.
///
/// `DebugGrammar` can be constructed from a BNF string and it has a human-readable string
/// representation.
public struct DebugGrammar {
  /// The underlying raw grammar.
  public var raw = DefaultGrammar()

  /// A mapping from raw grammar symbol to its name in the parsed source.
  public var symbolName: [Int: String] = [:]

  /// A mapping from symbol name in the parsed source to raw grammar symbol.
  public var symbols: [String: Symbol] = [:]



  /// Creates an instance.
  public init(recognizing startSymbol: Symbol) {
    raw.startSymbol = startSymbol
  }

  /// Creates an instance by parsing `bnf`, or throws an error if `bnf` can't be parsed.
  public init() {
    raw.startSymbol = Symbol(id: 0)
  }

  public mutating func nameSymbol(_ s: Symbol, _ name: String) {
    if symbols[name] == nil {
      symbols[name] = s
      symbolName[Int(s.id)] = name
    }
  }


  /// Translates t into a raw grammar symbol, memoizing name/symbol relationships.
  public mutating func demandSymbol<S: StringProtocol>(_ t: S) -> Symbol {
    let name = String(t)
    if let r = symbols[name] { return r }
    let s = Symbol(id: .init(symbolName.count))
    nameSymbol(s, name)
    return s
  }

}

extension DebugGrammar: CustomStringConvertible {
  /// Returns the human-readable name for `s`.
  public func text(_ s: Symbol) -> String { symbolName[Int(s.id)] ?? "<UNNAMED>" }

  /// Returns a human-readable representation of `r`.
  public func text(_ r: DefaultGrammar.Rule) -> String {
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
  public func text(_ s: Set<Symbol>) -> Set<String> { Set(s.lazy.map(text)) }

  /// Returns a human-readable representation of `self`.
  public var description: String {
    raw.rules.lazy.map { r in text(r) }.joined(separator: "\n")
  }
}
