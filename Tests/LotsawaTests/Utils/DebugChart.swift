@testable import Lotsawa

/// A Chart wrapper engineered for convenient testing and diagnostics
struct DebugChart {
  /// The underlying chart.
  var base: Chart

  /// The language recognized.
  let language: DebugGrammar

  /// A mapping from positions in `language` to those in the raw grammar from which it was derived.
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
