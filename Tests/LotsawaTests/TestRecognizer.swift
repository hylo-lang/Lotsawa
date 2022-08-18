@testable import Lotsawa

/// A Recognizer wrapper engineered for convenient testing
struct TestRecognizer: CustomStringConvertible {
  typealias Base = Recognizer<DefaultGrammarConfig>
  typealias Symbol = Base.Symbol

  var base: Base
  let language: TestGrammar
  let rawPosition: DiscreteMap<DefaultGrammar.Position, DefaultGrammar.Position>

  /// Creates an instance that recognizes `language`.
  init(_ language: TestGrammar) {
    self.language = language
    let p = PreprocessedGrammar(language.raw)
    base = Recognizer(p)
    rawPosition = p.rawPosition
  }

  /// Recognize the given input string and return `nil`, or if recognition fails, return the suffix
  /// of input that starts *after* the character on which recognition failed.
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

  var description: String {
    var result: [String] = []
    for earleme in (0 ... base.currentEarleme) {

      result.append("---------- \(earleme) ----------\n")

      var allDerivations = earleme < base.currentEarleme
        ? base.derivationSet(earleme) : base.currentDerivationSet

      while !allDerivations.isEmpty {
        let currentItem = allDerivations.first!.item
        let itemDerivations = allDerivations.prefix { x in x.item == currentItem }

        if currentItem.isLeo {
          result.append("Leo(\(language.text(currentItem.transitionSymbol!))) ")
        }
        result.append(language.dottedText(rawPosition[currentItem.dotPosition]))

        if itemDerivations.first!.predotOrigin != nil {
          result.append(" (\(currentItem.origin))")
          result.append(" \(itemDerivations.map { d in d.predotOrigin! })")
        }
        result.append("\n")
        allDerivations = allDerivations[itemDerivations.endIndex...]
      }
    }
    return result.joined()
  }
}
