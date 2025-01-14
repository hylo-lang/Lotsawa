/// A Chart wrapper engineered for convenient testing and diagnostics
public struct DebugChart {
  /// The underlying chart.
  public var base: Chart

  /// The language recognized.
  public let language: DebugGrammar

  /// A mapping from positions in `language` to those in the raw grammar from which it was derived.
  public let rawPosition: DiscreteMap<DefaultGrammar.Position, DefaultGrammar.Position>
}

extension DebugChart: CustomStringConvertible {

  public var description: String {
    var result = ""
    // print("base.currentEarleme =", base.currentEarleme)
    for earleme in (0 ... base.currentEarleme) {
      // print("earleme =", earleme)

      result.append("---------- \(earleme) ----------\n")

      var remainingDerivations = earleme == base.currentEarleme
        ? base.currentEarleySet : base.earleySet(earleme)

      while let head = remainingDerivations.first {
        let itemDerivations = remainingDerivations.prefix { x in x.item == head.item }
        result += "\(itemDerivations.startIndex): "
        // print("###", itemDerivations.startIndex)
        if !head.isLeo {
          // print("non-leo")
          result.append("<\(head.origin)> ")
        }
        if head.mainstemIndex != nil {
          // print("has mainstem")
          result.append(
            "{\(itemDerivations.map { String($0.mainstemIndex!) }.joined(separator: ", "))} ")
        }

        if head.isLeo {
          // print("leo description")
          result += "L(\(head.memoizedPenultIndex ?? -999)) •\(head.transitionSymbol ?? Symbol(id: -999))"
        }
        else  {
          // print("dotted text")
          result += language.dottedText(rawPosition[head.dotPosition])
        }
        result += "\n"
        remainingDerivations.removeFirst(itemDerivations.count)
      }
    }
    return result
  }

}
