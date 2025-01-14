import TestResources
import Lotsawa

@main
struct ProfileMain {
  static func main() {
    print("starting")
    let g = TestResources.ansiCGrammar
    var r = Recognizer(PreprocessedGrammar(g.raw))
    precondition(r.finishEarleme(), "Couldn't finish initial earleme")

    for (i, c) in ansiCTokens.enumerated() {
      r.discover(c, startingAt: .init(i))
      precondition(r.finishEarleme(), "No progress in earleme \(i)")
    }

    precondition(r.hasCompleteParse())
    print("parsing complete")
    print("\(r.currentEarleme - 1) tokens processed.")
  }
}

