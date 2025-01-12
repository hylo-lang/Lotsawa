import Lotsawa
import CitronLexerModule

/// "//" followed by any number of non-newlines (See
/// https://unicode-org.github.io/icu/userguide/strings/regexp.html#regular-expression-metacharacters
/// and https://www.unicode.org/reports/tr44/#BC_Values_Table).
let comment = #"(?://\P{Bidi_Class=B}*)"#

/// A lexical analyzer for the grammar we use to describe other grammars for testing.
var testGrammarScanner : Scanner<DebugGrammarParser.CitronTokenCode> {
  return .init(
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
    ])
}

extension DebugGrammar.AST {

  /// A nonterminal symbol.
  struct Token: Hashable, CustomStringConvertible {
    /// The ordinal ID.
    typealias ID = DebugGrammarParser.CitronTokenCode

    /// Creates an instance with ID `id` covering `content` at the
    /// given `position`.
    init(_ id: ID, _ content: Substring, at position: SourceRegion) {
      self.id = id
      self.text = content
      self.position = Incidental(position)
    }

    /// The ordinal ID.
    let id: ID

    /// The content covered.
    let text: Substring

    /// Where `text` appears in the input text.
    let position: Incidental<SourceRegion>

    var description: String {
      "Token(.\(id), \(String(reflecting: text)), at: \(position.value))"
    }
  }
}
