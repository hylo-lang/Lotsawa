@testable import Lotsawa

extension Grammar: CustomStringConvertible {
  /// Returns the human-readable name for `s`.
  func text(_ s: Symbol) -> String { String(s.id) }

  /// Returns a human-readable representation of `r`.
  func rhsText(_ r: Rule) -> String {
    r.rhs.isEmpty ? "𝛆" : r.rhs.indices.lazy.map {
      i in text(r.rhs[i]) + i.subscriptingDigits()
    }.joined(separator: " ")
  }

  /// Returns a human-readable representation of `self`.
  public var description: String {
    let sortedRules = MultiMap(grouping: rules, by: \.lhs).storage
      .sorted(by: { a,b in a.key < b.key })

    return sortedRules.lazy.map { (lhs, alternatives) in
      "\(lhs) ::= " + alternatives.lazy.map(rhsText).joined(separator: " | ")
    }.joined(separator: "; ")
  }
}

extension Symbol {
  init<I: BinaryInteger>(_ id: I) { self = Symbol(id: ID(id)) }
}
