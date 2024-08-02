import HyloEBNF

extension Equatable {

  func equals(_ rhs: any Equatable) -> Bool {
    type(of: self) == type(of: rhs) && (self == (rhs as! Self))
  }

}

struct GrammarBuilder<StoredSymbol: SignedInteger & FixedWidthInteger>: BNFBuilder {

  var symbols: [any EBNFNode] = []
  var rules: [RuleID: any EBNFNode] = [:]
  var result = Grammar<StoredSymbol>(recognizing: Symbol(id: 0))

  init(startSymbol: any EBNFNode) {
    let start = makeSymbol(startSymbol)
    assert(start.id == 0)
  }

  /// Returns a new BNF terminal symbol corresponding to `n`.
  ///
  /// It would typically be a mistake to call this function twice for the same `n`.
  mutating func makeTerminal<N: EBNFNode>(_ n: N) -> Symbol {
    assert(n.equals(symbols[0]), "The start symbol is a terminal?")
    return makeSymbol(n)
  }

  /// Returns a new BNF nonterminal symbol corresponding to `n`.
  mutating func makeNonterminal<N: EBNFNode>(_ n: N) -> Symbol {
    if n.equals(symbols[0]) { return Symbol(id: 0) }
    return makeSymbol(n)
  }

  /// Returns a new BNF nonterminal symbol corresponding to `n`.
  private mutating func makeSymbol<N: EBNFNode>(_ n: N) -> Symbol {
    let r = Symbol(id: Symbol.ID(symbols.count))
    symbols.append(n)
    return r
  }

  /// Sets the BNF grammar's start symbol.
  mutating func setStartSymbol(_ s: Symbol) {
    assert(s.id == 0)
  }

  /// Adds a BNF rule corresponding to `source`, reducing the elements
  /// of `rhs` to the nonterminal symbol `lhs`.
  mutating func addRule<RHS: Collection, Source: EBNFNode>(
    reducing rhs: RHS, to lhs: Self.Symbol, source: Source) where RHS.Element == Self.Symbol {
    let r = result.addRule(lhs: lhs, rhs: rhs)
    rules[r] = source
  }

}
