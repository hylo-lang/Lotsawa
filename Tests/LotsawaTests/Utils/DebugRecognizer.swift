@testable import Lotsawa

/// A Recognizer wrapper engineered for convenient testing
struct DebugRecognizer: CustomStringConvertible {
  typealias Base = Recognizer<Symbol.ID>

  var base: Base
  let language: DebugGrammar
  let rawPosition: DiscreteMap<DefaultGrammar.Position, DefaultGrammar.Position>

  /// Creates an instance that recognizes `language`.
  init(_ language: DebugGrammar) {
    self.language = language
    let p = PreprocessedGrammar(language.raw)
    base = Recognizer(p)
    rawPosition = p.rawPosition
  }

  /// Recognize the given input string, treating each Character as a separate token, and return
  /// `nil`, or if recognition fails, return the suffix of input that starts *after* the character
  /// on which recognition failed.
  mutating func recognize(_ input: String) -> Substring? {
    base.initialize()
    if !base.finishEarleme() { return input[...] }

    for (i, c) in input.enumerated() {
      base.discover(language.symbols["'\(c)'"]!, startingAt: .init(i))
      if !base.finishEarleme() {
        return input.dropFirst(i + 1)
      }
    }

    return base.hasCompleteParse() ? nil : input.suffix(0)
  }

  var chart: DebugChart {
    return DebugChart(base: base.chart, language: language, rawPosition: rawPosition)
  }

  var description: String {
    chart.description
  }
}
