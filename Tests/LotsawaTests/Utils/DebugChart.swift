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

      var remainingDerivations = earleme == base.currentEarleme
        ? base.currentEarleySet : base.earleySet(earleme)

      while let head = remainingDerivations.first {
        let itemDerivations = remainingDerivations.prefix { x in x.item == head.item }
        result += "\(itemDerivations.startIndex): "
        if !head.isLeo {
          result.append("<\(head.origin)> ")
        }
        if head.mainstemIndex != nil {
          result.append(
            "{\(itemDerivations.map { String($0.mainstemIndex!) }.joined(separator: ", "))} ")
        }

        if head.isLeo {
          result += "L(\(head.memoizedPenultIndex!)) •\(head.transitionSymbol!)"
        }
        else  {
          result += language.dottedText(head.dotPosition)
        }
        result += "\n"
        remainingDerivations.removeFirst(itemDerivations.count)
      }
    }
    return result
  }
}
