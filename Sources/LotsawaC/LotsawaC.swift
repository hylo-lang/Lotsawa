import Lotsawa

typealias RawSymbol = Int16

typealias CGrammar = Lotsawa.DebugGrammar
typealias CRecognizer = Lotsawa.DebugRecognizer
typealias CPreprocessedGrammar = Lotsawa.DebugGrammar

protocol ExposedViaOpaquePointer {
  associatedtype Wrapped
  var opaque: OpaquePointer? { get set }
  init()
}

extension ExposedViaOpaquePointer {

  var value: Wrapped {
    _read {
      yield pointer().pointee
    }
    _modify {
      yield &pointer().pointee
    }
  }

  func mutate<R>(_ mutation: (inout Wrapped)->R) -> R {
    mutation(&pointer().pointee)
  }

  func pointer() -> UnsafeMutablePointer<Wrapped> {
    UnsafeMutableRawPointer(opaque!).assumingMemoryBound(to: Wrapped.self)
  }

  static func create(_ value: Wrapped) -> Self {
    let x = UnsafeMutablePointer<Wrapped>.allocate(capacity: 1)
    x.initialize(to: value)
    var y = Self()
    y.opaque = OpaquePointer(x)
    return y
  }

  func destroy() {
    let p = UnsafeMutableRawPointer(opaque!)
    let x = p.assumingMemoryBound(to: Wrapped.self)
    x.deinitialize(count: 1)
    x.deallocate()
  }

  func copy() -> Self {
    Self.create(value)
  }

}

extension LotsawaGrammar: ExposedViaOpaquePointer {
  typealias Wrapped = CGrammar

  var opaque: OpaquePointer? {
    get { opaque_ }
    _modify { yield &opaque_ }
  }
}

@_cdecl("lotsawa_grammar_create")
func lotsawa_grammar_create() -> LotsawaGrammar {
  LotsawaGrammar.create(.init())
}

@_cdecl("lotsawa_grammar_set_start")
func lotsawa_grammar_set_start(g: LotsawaGrammar, start: LotsawaSymbol) {
  g.mutate { $0.raw.startSymbol = Symbol(id: start) }
}

@_cdecl("lotsawa_grammar_destroy")
func lotsawa_grammar_destroy(_ g: LotsawaGrammar)  {
  g.destroy()
}

@_cdecl("lotsawa_grammar_copy")
func lotsawa_grammar_copy(_ g: LotsawaGrammar) -> LotsawaGrammar {
  g.copy()
}

@_cdecl("lotsawa_grammar_add_rule")
func lotsawa_grammar_add_rule(
  g: LotsawaGrammar, lhs: LotsawaSymbol,
  rhsCount: CInt, rhsBase: UnsafePointer<LotsawaSymbol>
) -> LotsawaRule {
  let rhs = UnsafeBufferPointer(start: rhsBase, count: Int(rhsCount)).lazy.map(Symbol.init(id:))
  return g.mutate { $0.raw.addRule(lhs: Symbol(id: lhs), rhs: rhs).ordinal }
}

@_cdecl("lotsawa_grammar_name_symbol")
func lotsawa_grammar_name_symbol(g: LotsawaGrammar, _ s: LotsawaSymbol, _ name: UnsafePointer<CChar>) {
  g.mutate { $0.nameSymbol(Symbol(id: s), String(cString: name)) }
}

/*
extension LotsawaPreprocessedGrammar: ExposedViaOpaquePointer {
  typealias Wrapped = CPreprocessedGrammar

  var opaque: OpaquePointer? {
    get { opaque_ }
    _modify { yield &opaque_ }
  }
}

@_cdecl("lotsawa_preprocessed_grammar_create")
func lotsawa_preprocessed_grammar_create(g: LotsawaGrammar) -> LotsawaPreprocessedGrammar {
  print("grammar:\n", g.value)
  return LotsawaPreprocessedGrammar.create(g.value)
}

@_cdecl("lotsawa_preprocessed_grammar_destroy")
func lotsawa_preprocessed_grammar_destroy(_ g: LotsawaPreprocessedGrammar)  {
  g.destroy()
}

@_cdecl("lotsawa_preprocessed_grammar_copy")
func lotsawa_preprocessed_grammar_copy(_ g: LotsawaPreprocessedGrammar) -> LotsawaPreprocessedGrammar {
  g.copy()
}
 */

extension LotsawaRecognizer: ExposedViaOpaquePointer {
  typealias Wrapped = CRecognizer

  var opaque: OpaquePointer? {
    get { opaque_ }
    _modify { yield &opaque_ }
  }
}

@_cdecl("lotsawa_recognizer_create")
func lotsawa_recognizer_create(_ g: LotsawaGrammar) -> LotsawaRecognizer {
  // print("grammar:\n", g.value)
  let r = LotsawaRecognizer.create(CRecognizer(g.value))
  // print("------------------")
  // print("recognizer:")
  // print(r.value)
  return r
}

@_cdecl("lotsawa_recognizer_destroy")
func lotsawa_recognizer_destroy(_ r: LotsawaRecognizer)  {
  r.destroy()
}

@_cdecl("lotsawa_recognizer_copy")
func lotsawa_recognizer_copy(_ r: LotsawaRecognizer) -> LotsawaRecognizer {
  r.copy()
}

@_cdecl("lotsawa_recognizer_initialize")
func lotsawa_recognizer_initialize(_ r: LotsawaRecognizer) {
  r.mutate { $0.initialize() }
}

@_cdecl("lotsawa_recognizer_discover")
func lotsawa_recognizer_discover(_ r: LotsawaRecognizer, symbol: LotsawaSymbol, startingAt start: LotsawaSourcePosition) {
  r.mutate { $0.base.discover(Symbol(id: symbol), startingAt: start) }
}

@_cdecl("lotsawa_recognizer_finish_earleme")
func lotsawa_recognizer_finish_earleme(_ r: LotsawaRecognizer) -> CBool {
  let x = r.mutate { $0.base.finishEarleme() }
  if r.value.base.currentEarleme == 1000 {
    // print("------------------")
    // print(r.value)
  }
  return x
}

@_cdecl("lotsawa_recognizer_has_complete_parse")
func lotsawa_recognizer_has_complete_parse(_ r: LotsawaRecognizer) -> CBool {
  r.value.base.hasCompleteParse()
}
