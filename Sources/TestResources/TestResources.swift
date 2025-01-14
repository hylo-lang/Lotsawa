import Foundation
import Lotsawa

func textResource(_ name: String) -> String {
  try! String(contentsOf: Bundle.module.url(forResource: name, withExtension: "txt")!)
}

public var ansiCGrammar: DebugGrammar {
  let grammarText = textResource("AnsiCGrammar")
  let symbols = textResource("AnsiCSymbolIDs").split(separator: "\n").filter { !$0.isEmpty }
  precondition(symbols.count > 1) // make sure splitting worked.
  let symbolID: [Substring: Symbol]
    = Dictionary(uniqueKeysWithValues: symbols.enumerated().lazy.map { n, s in (s, Symbol(id: .init(n))) })
  var g = DebugGrammar(recognizing: symbolID["start"]!)
  for (name, s) in symbolID {  g.nameSymbol(s, String(name)) }
  for rule in grammarText.split(separator: "\n") {
    if rule.isEmpty { continue }
    let colon = rule.firstIndex(of: ":")!
    let lhs = rule[..<colon]
    let rhs = rule[rule.index(after: colon)...].split(separator: " ").filter { $0 != "" && $0 != "_" }
    g.raw.addRule(lhs: symbolID[lhs]!, rhs: rhs.map { symbolID[$0]! })
  }
  return g
}

public var ansiCTokens: some Collection<Symbol> {
  textResource("AnsiCTokens").utf8.lazy.filter { !Character(UnicodeScalar($0)).isWhitespace }.map { Symbol(id: Int16($0 - 33)) }
}
