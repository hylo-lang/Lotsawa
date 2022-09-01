import CitronLexerModule

/// "//" followed by any number of non-newlines (See
/// https://unicode-org.github.io/icu/userguide/strings/regexp.html#regular-expression-metacharacters
/// and https://www.unicode.org/reports/tr44/#BC_Values_Table).
let comment = #"(?://\P{Bidi_Class=B}*)"#

let testGrammarScanner = Scanner<TestGrammarParser.CitronTokenCode>(
  literalStrings: [
    "::=": .IS_DEFINED_AS,
    "_": .UNDERSCORE,
    "|": .ALTERNATION,
  ],
  patterns: [
    /// A mapping from regular expression pattern to either a coresponding token ID,
    /// or `nil` if the pattern is to be discarded (e.g. for whitespace).
    #"[A-Za-z][-_A-Za-z0-9]*(?=\s*::=)"#: .LHS,
    #"[A-Za-z][-_A-Za-z0-9]*(?!\s*::=)"#: .SYMBOL,
    #"'([^\\']|\\.)*'"#: .LITERAL,
    #"\s*"#: nil,
    comment: nil,
  ]
)

extension TestGrammar.AST {
  struct Token: Hashable, CustomStringConvertible {
    typealias ID = TestGrammarParser.CitronTokenCode

    init(_ id: ID, _ content: Substring, at position: SourceRegion) {
      self.id = id
      self.text = content
      self.position = Incidental(position)
    }

    let id: ID
    let text: Substring
    let position: Incidental<SourceRegion>

    var description: String {
      "Token(.\(id), \(String(reflecting: text)), at: \(position.value))"
    }
  }
}
