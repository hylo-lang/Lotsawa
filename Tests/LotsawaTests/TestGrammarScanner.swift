import CitronLexerModule

// One horizontal space character
let hspace_char = #"[\p{gc=Space_Separator} \N{CHARACTER TABULATION}]"#

/// "//" followed by any number of non-newlines (See
/// https://unicode-org.github.io/icu/userguide/strings/regexp.html#regular-expression-metacharacters
/// and https://www.unicode.org/reports/tr44/#BC_Values_Table).
let comment = #"(?://\P{Bidi_Class=B}*)"#

let line_break_prefix = "\(hspace_char)*\(comment)?\p{Bidi_Class=B}"

let testGrammarScanner = Scanner<TestGrammarParser.CitronTokenCode>(
  literalStrings: [
    "::=": .IS_DEFINED_AS,
    "_": .UNDERSCORE,
  ],
  patterns: [
    /// A mapping from regular expression pattern to either a coresponding token ID,
    /// or `nil` if the pattern is to be discarded (e.g. for whitespace).
    #"[A-Za-z][-_A-Za-z0-9]*"#: .SYMBOL,
    #"'([^\\']|\\.)*'"#: .LITERAL,
    "\(hspace_char)*\(comment)|\(hspace_char)+": .HORIZONTAL_SPACE, // 1-line comment
    "\(line_break_prefix)\(hspace_char)*": .LINE_BREAK,
    "\(line_break_prefix)\(line_break_prefix)+\(hspace_char)*": .MULTIPLE_LINE_BREAKS
  ]
)

struct TestGrammarToken: Hashable {
  typealias ID = TestGrammarParser.CitronTokenCode

  init(_ id: ID, _ content: Substring, at position: SourceRegion) {
    self.id = id
    self.text = content
    self.position = position
  }

  let id: ID
  let text: Substring
  let position: SourceRegion

  var dump: String { String(text) }
}

extension TestGrammarToken: CustomStringConvertible {
  var description: String {
    "Token(.\(id), \(String(reflecting: text)), at: \(String(reflecting: position)))"
  }
}
