import Lotsawa

public struct BisonSyntaxParseError: Error {
  var position: Substring
  var message: String
  init(at position: Substring, _ message: String) {
    self.position = position; self.message = message
  }
}

public struct BisonGrammar<StoredSymbol: SignedInteger & FixedWidthInteger> {
  public var lotsawaGrammar: Grammar<StoredSymbol>
  public var prologue: Substring
  public var epilogue: Substring
  public var symbol: [Substring: Symbol] = [:]
  public var action: [RuleID: Substring] = [:]
}

extension StringProtocol {

  mutating func untilLineStartingWithToken<S: StringProtocol>(_ t: S) -> Self.SubSequence {
    var rest = self[...]
    while !rest.isEmpty {
      let lineStart = rest
      rest = rest.droppingHorizontalWhitespace(followedBy: t)
      if t.isEmpty || rest.startIndex != lineStart.startIndex {
        return self[..<lineStart.startIndex]
      }
      rest = rest.drop(while: { !$0.isNewline }).dropFirst()
    }
    return self[...]
  }

  func droppingInitial<S: StringProtocol>(_ t: S) -> Self.SubSequence {
    var s1 = self[...]
    var t1 = t[...]
    while let c = t1.popFirst() {
      if let d = s1.popFirst(), c == d { continue }
      return self[...]
    }
    return s1
  }

  func droppingHorizontalWhitespace() -> Self.SubSequence {
    var r = self[...]
    while !r.isEmpty && r.first!.isWhitespace && !r.first!.isNewline {
      r = r.dropFirst()
    }
    return r
  }

  func droppingHorizontalWhitespace<S: StringProtocol>(followedBy t: S) -> Self.SubSequence {
    var r = self.droppingHorizontalWhitespace()
    if r.popInitial(t) == nil { return self[...] }
    return r
  }

}

extension StringProtocol where SubSequence == Self {

  mutating func popInitial<S: StringProtocol>(_ s: S) -> Self? {
    let r = self.droppingInitial(s)
    if !s.isEmpty && r.startIndex == self.startIndex { return nil }
    defer { self = r }
    return self[..<r.startIndex]
  }

}

extension BisonGrammar {

  public init(_ source: String) throws {
    var input = source[...]

    @discardableResult
    func pop1() -> Character? { input.popFirst() }

    @discardableResult
    func pop2() -> Substring? {
      defer {
        input = input.dropFirst(2)
      }
      return input.prefix(2)
    }

    @discardableResult
    func popExpected<S: StringProtocol>(_ s: S) throws -> Substring {
      if let r = input.popInitial(s) { return r }
      throw BisonSyntaxParseError(at: input[..<input.startIndex], "Expected \(s) not found")
    }

    func popExpectedLines<S: StringProtocol>(between open: S, and close: S) throws -> Substring {
      try popSpaceAndComments(throughEOL: true)
      input = input.droppingHorizontalWhitespace()
      try popExpected(open)
      input = input.droppingHorizontalWhitespace()
      input = input.dropFirst()
      let r = input.untilLineStartingWithToken(close)
      input = input[r.endIndex...].droppingHorizontalWhitespace()
      try popExpected(close)
      try popSpaceAndComments()
      return r
    }

    @discardableResult
    func popSpaceAndComments(throughEOL: Bool = false) throws -> Substring {
      let initial = input
      while !input.isEmpty {
        let first2 = input.prefix(2)
        if first2 == "//" {
          pop2()
          while !(input.first?.isNewline ?? false) { pop1() }
          pop1()
          if throughEOL { break }
        }
        else if first2 == "/*" {
          pop2()
          while !input.isEmpty && input.prefix(2) != "*/" {
            if throughEOL && !input.first!.isWhitespace { input = input.suffix(0) }
            pop1()
          }
          if input.isEmpty { throw BisonSyntaxParseError(at: first2, "Closing */ not found") }
          pop2()
        }
        else if input.first!.isWhitespace {
          if throughEOL && input.first!.isNewline { pop1(); break }
          pop1()
        }
        else { break }
      }
      return initial[..<input.startIndex]
    }

    try popSpaceAndComments()
    self.prologue = try popExpectedLines(between: "%{", and: "%}")
    let declarations = input.untilLineStartingWithToken("%%")
    // read declarations instead of this
    _ = declarations
    input = input[declarations.endIndex...]
    let rules = try popExpectedLines(between: "%%", and: "%%")
    // read rules instead of this
    _ = rules
    self.epilogue = input
    lotsawaGrammar = .init(recognizing: Symbol(id: 0))
  }

}
