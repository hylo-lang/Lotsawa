/// A Recognizer wrapper engineered for convenient testing
public struct DebugRecognizer: CustomStringConvertible {
  /// The underlying recognizer type.
  public typealias Base = Recognizer<Symbol.ID>

  /// The underlying recognizer.
  public var base: Base

  /// The language being recognized.
  public let language: DebugGrammar

  /// A map from position in `language` to corresponding position in the raw grammar from which it
  /// was derived.
  public let rawPosition: DiscreteMap<DefaultGrammar.Position, DefaultGrammar.Position>

  /// Creates an instance that recognizes `language`.
  public init(_ language: DebugGrammar) {
    self.language = language
    let p = PreprocessedGrammar(language.raw)
    base = Recognizer(p)
    rawPosition = p.rawPosition
  }

  /// Recognize the given input string, treating each Character as a separate token, and return
  /// `nil`, or if recognition fails, return the suffix of input that starts *after* the character
  /// on which recognition failed.
  public mutating func recognize(_ input: String) -> Substring? {
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

  /// All the partial and full recognitions generated by this recognizer.
  public var chart: DebugChart {
    return DebugChart(base: base.chart, language: language, rawPosition: rawPosition)
  }

  public var description: String {
    chart.description
  }

  public mutating func initialize() {
    base.initialize()
  }

}
