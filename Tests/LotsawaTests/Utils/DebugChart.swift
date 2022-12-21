@testable import Lotsawa

/// A Chart wrapper engineered for convenient testing and diagnostics
struct DebugChart {
  var base: Chart
  let language: DebugGrammar
  let rawPosition: DiscreteMap<DefaultGrammar.Position, DefaultGrammar.Position>
}

extension DebugChart: CustomStringConvertible {
  var description: String {
    var result = ""
    for earleme in (0 ... base.currentEarleme) {

      result.append("---------- \(earleme) ----------\n")

      var allDerivations = earleme == base.currentEarleme
        ? base.currentEarleySet : base.earleySet(earleme)

      while !allDerivations.isEmpty {
        let currentItem = allDerivations.first!.item
        let itemDerivations = allDerivations.prefix { x in x.item == currentItem }

        result.append("\(itemDerivations.startIndex): ")

        result.append(
          language.derivationText(
            origin: currentItem.origin,
            dotInGrammar: rawPosition[currentItem.dotPosition],
            dotInSource: currentItem.isLeo ? nil : earleme,
            predotPositions: itemDerivations.map { d in d.predotOrigin }))

        if currentItem.isLeo {
          result.append("\(language.text(currentItem.transitionSymbol!))* ")
        }
        result.append("\n")
        allDerivations = allDerivations[itemDerivations.endIndex...]
      }
    }
    return result
  }
}
