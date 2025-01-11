import Lotsawa

private struct CType<T> {
  static func new(_ value: T) -> UnsafeMutableRawPointer {
    let x = UnsafeMutablePointer<T>.allocate(capacity: 1)
    x.initialize(to: value)
    return UnsafeMutableRawPointer(x)
  }

  static func destroy(_ p: UnsafeMutableRawPointer) {
    let x = p.assumingMemoryBound(to: T.self)
    x.deinitialize(count: 1)
    x.deallocate()
  }
}

private typealias RawSymbol = Int16
private typealias G = Grammar<RawSymbol>

@_cdecl("lotsawa_grammar_new")
func lotsawa_grammar_new(recognizing s: Int32) -> UnsafeMutableRawPointer {
  CType<G>.new(.init(recognizing: Symbol(id: .init(s))))
}

@_cdecl("lotsawa_grammar_destroy")
func lotsawa_grammar_destroy(_ g: UnsafeMutableRawPointer)  {
  CType<G>.destroy(g)
}

typealias R = LotsawaRule
