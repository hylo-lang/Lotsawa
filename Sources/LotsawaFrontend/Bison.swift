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

  func untilLineStartingWithToken<S: StringProtocol>(_ t: S) -> Self.SubSequence {
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

  @discardableResult
  mutating func popInitial<S: StringProtocol>(_ s: S) -> Self? {
    let r = self.droppingInitial(s)
    if !s.isEmpty && r.startIndex == self.startIndex { return nil }
    defer { self = r }
    return self[..<r.startIndex]
  }

  @discardableResult
  mutating func popHorizontalWhitespace() -> Self? {
    let next = self.droppingHorizontalWhitespace()
    if next.startIndex == self.startIndex { return nil }
    let r = self[..<next.startIndex]
    self = next
    return r
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

    func syntaxError(at position: Substring? = nil, _ message: String) throws -> Never {
       throw BisonSyntaxParseError(at: position ?? input[..<input.startIndex], message)
    }

    @discardableResult
    func popExpected<S: StringProtocol>(_ s: S) throws -> Substring {
      if let r = input.popInitial(s) { return r }
      try syntaxError("Expected \(s) not found")
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

    @discardableResult
    func popIdentifier() -> Substring? {
      let id = input.prefix(while: { $0 == "_" || $0.isLetter || $0.isNumber })
      if !id.isEmpty && (id.first == "_" || id.first!.isLetter) {
        input = input[id.endIndex...]
        return id
      }
      return nil
    }

    @discardableResult
    func popNonwhitespace() -> Substring? {
      let start = input
      while let c = input.first, !c.isWhitespace { pop1() }
      return start.startIndex == input.startIndex ? nil : start[..<input.startIndex]
    }

    @discardableResult
    func popExpectedIdentifier() throws -> Substring {
      if let id = popIdentifier() { return id }
      try syntaxError("identifier expected")
    }

    @discardableResult
    func popCharConstant() -> Substring? {
      let start = input
      if input.first != "'" { return nil }
      pop1()
      if input.first == "\\" { pop2() }
      while !input.isEmpty && input.first != "'" { pop1() }
      if input.isEmpty { input = start; return nil }
      pop1()
      return start[..<input.startIndex]
    }

    @discardableResult
    func popStringConstant() -> Substring? {
      let start = input
      if input.first != "\"" { return nil }
      pop1()
      while !input.isEmpty && input.first != "\"" {
        if input.first == "\\" { pop1() }
        pop1()
      }
      if input.isEmpty { input = start; return nil }
      pop1()
      return start[..<input.startIndex]
    }

    @discardableResult
    func popBalancedBraces() throws -> Substring? {
      let saved = input
      try popSpaceAndComments()
      var nesting = 0
      if !input.starts(with: "{") { return nil }
      pop1()
      try popSpaceAndComments()
      nesting = 1
      while !input.isEmpty && nesting != 0 {
        switch input.first {
        case "{":
          nesting += 1
          pop1()
        case "}":
          nesting -= 1
          pop1()
        case "'":
          if popCharConstant() == nil {
            try syntaxError("unterminated char constant")
          }
        case "\"":
          if popStringConstant() == nil {
            try syntaxError("unterminated string constant")
          }
        default:
          if try popSpaceAndComments().isEmpty { pop1() }
        }
      }
      return saved[..<input.startIndex]
    }

    @discardableResult
    func popExpectedBalancedBraces() throws -> Substring {
      if let b = try popBalancedBraces() { return b }
      try syntaxError("expected balanced braces")
    }

    @discardableResult
    func popExpectedOptionalIdentifierAndThenBalancedBraces() throws -> (identifier: Substring?, body: Substring)
    {
      try popSpaceAndComments()
      let id = popIdentifier()
      let b = try popExpectedBalancedBraces()
      return (id, b)
    }

    @discardableResult
    func popLine() -> Substring? {
      let start = input
      while let c = input.popFirst(), !c.isNewline {}
      if input.startIndex == start.startIndex { return nil }
      return start[..<input.startIndex]
    }

    @discardableResult
    func popExpectedStringConstant() throws -> Substring {
      try popSpaceAndComments()
      let saved = input
      if popStringConstant() == nil {
        try syntaxError("expected string constant")
      }
      return saved[..<input.startIndex]
    }

    func readDeclaration() throws -> Bool {
      try popSpaceAndComments()
      if input.isEmpty { return false }
      if input.starts(with: "%%") { return false }
      try popExpected("%")
      let key = try popExpectedIdentifier()
      switch key {
      case "union":
        try popExpectedOptionalIdentifierAndThenBalancedBraces()
      case "token":
        input.popHorizontalWhitespace()
        if let id = popIdentifier() {
          _ = id
          popLine()
        }
        else {
          let x = input.untilLineStartingWithToken("%")
          input = input[x.endIndex...]
        }
      case "right", "left", "nonassoc", "precedence":
        try popSpaceAndComments()
        popLine()
      case "type", "nterm":
        try popSpaceAndComments()
        popLine()
      case "start":
        try popSpaceAndComments()
        popLine()
      case "expect", "expect-rr":
        try popSpaceAndComments()
        popLine()
      case "code":
        try popExpectedOptionalIdentifierAndThenBalancedBraces()
      case "debug": break
      case "define":
        try popSpaceAndComments()
        guard let variable = popNonwhitespace() else { try syntaxError("expected variable name") }
        _ = variable
        try popSpaceAndComments()
        let body = try popBalancedBraces()
        if body == nil {
          let stringValue = popStringConstant()
          if stringValue == nil { popLine() }
        }
      case "defines", "header":
        try popSpaceAndComments()
        popLine()
        break
      case "destructor":
        try popSpaceAndComments()
        try popExpectedBalancedBraces()
        popLine()
      case "file-prefix":
        try popExpectedStringConstant()
      case "language":
        try popExpectedStringConstant()
      case "locations": popLine()
      case "name-prefix":
        try popExpectedStringConstant()
      case "no-lines": popLine()
      case "output":
        try popExpectedStringConstant()
      case "pure-parser": popLine()
      case "require":
        try popExpectedStringConstant()
      case "skeleton":
        try popExpectedStringConstant()
      case "token-table": popLine()
      case "verbose": popLine()
      case "yacc": popLine()
      default: try syntaxError(at: key, "unknown directive")
      }
      return true
    }

    try popSpaceAndComments()
    self.prologue = try popExpectedLines(between: "%{", and: "%}")

    while try readDeclaration() {}

    let rules = try popExpectedLines(between: "%%", and: "%%")
    // read rules instead of this
    _ = rules
    self.epilogue = input
    lotsawaGrammar = .init(recognizing: Symbol(id: 0))
  }

}

/*
       case "code": break
      case "debug": break
      case "define": break
      case "defines": break
      case "destructor": break
      case "empty": break
      case "expect": break
      case "expect-rr": break
      case "file-prefix": break
      case "glr-parser": break
      case "header": break
      case "initial-action": break
      case "language": break
      case "left": break
      case "lex-param": break
      case "locations": break
      case "name-prefix": break
      case "no-lines": break
      case "nonassoc": break
      case "nterm": break
      case "output": break
      case "param": break
      case "parse-param": break
      case "precedence": break
      case "printer": break
      case "pure-parser": break
      case "require": break
      case "right": break
      case "skeleton": break
      case "start": break
      case "token": break
      case "token-table": break
      case "type": break
      case "union": break
      case "verbose": break
      case "yacc": break

 */
