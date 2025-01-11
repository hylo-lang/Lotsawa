import Lotsawa

typealias RawSymbol = Int16
typealias G = Grammar<RawSymbol>

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
  typealias Wrapped = G

  var opaque: OpaquePointer? {
    get { value_ }
    _modify { yield &value_ }
  }
}

@_cdecl("lotsawa_grammar_new")
func lotsawa_grammar_new(recognizing s: Int32) -> LotsawaGrammar {
  LotsawaGrammar.create(.init(recognizing: Symbol(id: .init(s))))
}

@_cdecl("lotsawa_grammar_destroy")
func lotsawa_grammar_destroy(_ g: LotsawaGrammar)  {
  g.destroy()
}

typealias R = LotsawaRule
