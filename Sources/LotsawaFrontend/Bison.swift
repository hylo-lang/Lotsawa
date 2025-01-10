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
      // print("### line: \(rest.prefix(80))")
      rest = rest.droppingHorizontalWhitespace(followedBy: t)
      // print("### after seeking \(t): \(rest.prefix(80))")
      if t.isEmpty || rest.startIndex != lineStart.startIndex {
        // print("### FOUND")
        return self[..<lineStart.startIndex]
      }
      rest = rest.drop(while: { !$0.isNewline }).dropFirst()
      // print("### after dropping remainder of line: \(rest.prefix(80))")
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

    func drop1() { input = input.dropFirst() }
    func drop2() { input = input.dropFirst(2) }

    func dropExpected<S: StringProtocol>(_ s: S) throws {
      if input.popInitial(s) == nil {
        throw BisonSyntaxParseError(at: input[..<input.startIndex], "Expected \(s) not found")
      }
    }

    func popLines<S: StringProtocol>(between open: S, and close: S) throws -> Substring {
      try dropWhitespace(throughEOL: true)
      input = input.droppingHorizontalWhitespace()
      try dropExpected(open)
      input = input.droppingHorizontalWhitespace()
      input = input.dropFirst()
      let r = input.untilLineStartingWithToken(close)
      // print("### between: \(r.prefix(80))...\(r.suffix(80))")
      input = input[r.endIndex...].droppingHorizontalWhitespace()
      // print("### after: \(input.prefix(80))")
      try dropExpected(close)
      try dropWhitespace()
      return r
    }

    func dropWhitespace(throughEOL: Bool = false) throws {
      while !input.isEmpty {
        let first2 = input.prefix(2)
        if first2 == "//" {
          drop2()
          while !(input.first?.isNewline ?? false) { drop1() }
          drop1()
          if throughEOL { return }
        }
        else if first2 == "/*" {
          drop2()
          while !input.isEmpty && input.prefix(2) != "*/" {
            if throughEOL && !input.first!.isWhitespace { input = input.suffix(0) }
            drop1()
          }
          if input.isEmpty { throw BisonSyntaxParseError(at: first2, "Closing */ not found") }
          drop2()
        }
        else if input.first!.isWhitespace {
          if throughEOL && input.first!.isNewline { drop1(); break }
          drop1()
        }
        else { break }
      }
    }

    // print("### drop: \(input.prefix(80))")
    try dropWhitespace()
    // print("### after initial whitespace: \(input.prefix(80))")
    self.prologue = try popLines(between: "%{", and: "%}")
    // print("### after prologue: \(input.prefix(80))")
    let declarations = input.untilLineStartingWithToken("%%")
    // read declarations instead of this
    _ = declarations
    input = input[declarations.endIndex...]
    // print("### after declarations: \(input.prefix(80))")
    let rules = try popLines(between: "%%", and: "%%")
    // read rules instead of this
    _ = rules
    // print("### after rules: \(input.prefix(80))")
    self.epilogue = input
    lotsawaGrammar = .init(recognizing: Symbol(id: 0))
  }

}
