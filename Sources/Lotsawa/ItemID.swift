extension Chart {
  /// An Earley or Leo item.
  struct ItemID: Comparable, Hashable {
    /// The raw storage.
    ///
    /// It is arranged to avoid 64-bit alignment, since this will be combined into an `Entry`.
    /// You'd want to swap the elements for optimal performance on big-endian architectures.
    var storage: (
      /// The low 16 bits of the origin and a 16-bit dot position.
      ///
      ///     bit         | 31 ... 16 | 15  ...   0 |
      ///     meaning     | originLow | dotPosition |
      originLow_dotPosition: UInt32,

      /// 1 bit for `isCompletion`, 14 bit transition or LHS `symbol`,
      /// 1 bit for `isEarley`, and the high 16 bits of the origin.
      ///
      ///     bit     |      31      | 30...17 |    16    | 15 ... 0 |
      ///     meaning | isCompletion |  symbol | isEarley | originHi |
      isCompletion_symbol_isEarley_originHi: UInt32
    )
  }
}

extension Chart.ItemID {
  /// Creates an Earley item starting at `origin and predicting the rule identified by `r` in `g`.
  init<S>(predicting r: RuleID, in g: Grammar<S>, at origin: SourcePosition) {
    let ruleStart = g.rhsStart(r)
    let postdot = g.rhs(r).first!
    storage = (
      originLow_dotPosition:
        UInt32(UInt16(truncatingIfNeeded: origin)) << 16 | UInt32(ruleStart),
      isCompletion_symbol_isEarley_originHi: (origin >> 16 | (1 << 16) | UInt32(postdot.id) << 17))
    assert(isEarley)
    assert(self.origin == origin)
    assert(self.dotPosition == ruleStart)
    assert(self.transitionSymbol == postdot)
    assert(!isCompletion)
  }

  /// Creates a Leo item that memoizes `m`, which can be an Earley or a Leo item, to be used when
  /// `transitionSymbol` is recognized.
  init(memoizingItemIndex m: Chart.Position, transitionSymbol: Symbol) {
    storage = (
      originLow_dotPosition: .init(m),
      isCompletion_symbol_isEarley_originHi: UInt32(transitionSymbol.id) << 17
    )
    assert(isLeo)
    assert(self.memoizedPenultIndex == m)
    assert(self.transitionSymbol == transitionSymbol)
    assert(!isCompletion)
  }

  /// Lookup key.
  var key: UInt64 {
    UInt64(storage.isCompletion_symbol_isEarley_originHi) << 32
      | UInt64(storage.originLow_dotPosition)
  }

  func hash(into h: inout Hasher) { key.hash(into: &h) }

  /// Lookup key for the start of the Leo-Earley sequence expecting a given symbol.
  ///
  /// Any Leo item always precedes Earley derivations in this sequence.
  var transitionKey: UInt32 { storage.isCompletion_symbol_isEarley_originHi }

  /// Lookup key for the start of the Leo-Earley sequence expecting symbol `s`.
  static func transitionKey(_ s: Symbol) -> UInt32 {
    return UInt32(s.id) << 17
  }


  /// Lookup key for the start of the sequence of Earley completions of symbol `s` with the given
  /// `origin`.
  static func completionKey(_ s: Symbol, origin: UInt32) -> UInt64 {
    return UInt64(truncatingIfNeeded: ~s.id) << (17+32)
      | (1 as UInt64) << (16 + 32)
      | UInt64(origin) << 16
  }

  /// Returns `true` iff `lhs` should precede `rhs` in a Earley set.
  static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.key < rhs.key
  }

  /// Returns `true` iff `lhs` is equivalent to `rhs`.
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.key == rhs.key
  }

  /// True iff `self` represents a completion
  var isCompletion: Bool {
    get {
      Int32(bitPattern: storage.isCompletion_symbol_isEarley_originHi) < 0
    }
    set {
      if newValue != isCompletion {
        storage.isCompletion_symbol_isEarley_originHi ^= (1 << 31)
      }
    }
  }

  /// The transition symbol if `self` is not a completion; otherwise the bitwise inverse of the
  /// LHS symbol.
  fileprivate var symbolID: Symbol.ID {
    get {
      .init(
        truncatingIfNeeded: Int32(bitPattern: storage.isCompletion_symbol_isEarley_originHi) >> 17)
    }
    set {
      // Mask off the hi 15 bits
      storage.isCompletion_symbol_isEarley_originHi &= ~0 >> 15

      // Mix in the low 15 bits of newValue, which sets isCompletion if needed.
      storage.isCompletion_symbol_isEarley_originHi
        |= UInt32(truncatingIfNeeded: newValue) << (32 - 15)
    }
  }

  /// The symbol that triggers the use of `self`, or `nil` if no such symbol exists (i.e. self is
  /// a completion).
  var transitionSymbol: Symbol? {
    isCompletion ? nil : Symbol(id: symbolID)
  }

  /// The LHS symbol of `self`'s rule, or nil if `self` is not a completion.
  var lhs: Symbol? {
    isCompletion ? Symbol(id: ~symbolID) : nil
  }

  /// True iff `self` is a Leo transitional item.
  private(set) var isLeo: Bool {
    get { !isEarley }
    set { isEarley = !newValue }
  }

  /// True iff `self` is an Earley item.
  private(set) var isEarley: Bool {
    get {
      storage.isCompletion_symbol_isEarley_originHi >> 16 & 1 != 0
    }
    set {
      if newValue { storage.isCompletion_symbol_isEarley_originHi |= 1 << 16 }
      else { storage.isCompletion_symbol_isEarley_originHi &= ~(1 << 16) }
    }
  }

  /// The input position where this partial recognition started.
  ///
  /// - Precondition: !self.isLeo
  var origin: UInt32 {
    assert(!isLeo)
    return
      storage.isCompletion_symbol_isEarley_originHi << 16 | storage.originLow_dotPosition >> 16
  }

  /// The dot position representing this Earley Item's parse progress.
  ///
  /// - Precondition: !self.isLeo
  var dotPosition: UInt16 {
    assert(!isLeo)
    return UInt16(truncatingIfNeeded: storage.originLow_dotPosition)
  }

  /// The `mainstemIndex` for any Earley items generated by this Leo item, or `nil` if `self` is
  /// an Earley item.
  var memoizedPenultIndex: Chart.Position? {
    return isLeo ? .init(storage.originLow_dotPosition) : nil
  }

  /// Returns `self` with the dot advanced over one symbol.
  ///
  /// - Precondition: `self` is an incomplete Earley item,
  func advanced<S>(in g: Grammar<S>) -> Chart.ItemID {
    assert(isEarley)
    assert(!isCompletion)

    var r = self
    // Advance the dot
    r.storage.originLow_dotPosition += 1

    // Sign-extends small LHS symbol representations to 16 bits; leaves RHS symbol values alone.
    let s = Int16(g.ruleStore[Int(r.dotPosition)])
    r.symbolID = s

    assert(r.isEarley)
    assert(r.origin == self.origin)
    assert(r.dotPosition == self.dotPosition + 1)
    assert(r.symbolID == s)
    assert(r.isCompletion == (s < 0))
    return r
  }

  /// Returns `self` with the dot moved back over one symbol.
  ///
  /// - Precondition: `self` is a non-prediction Earley item.
  func mainstem<S>(in g: Grammar<S>) -> Chart.ItemID {
    assert(isEarley)

    var r = self

    r.storage.originLow_dotPosition -= 1
    r.symbolID = g.postdot(at: r.dotPosition)!.id
    r.isCompletion = false

    assert(r.isEarley)
    assert(r.origin == self.origin)
    assert(r.dotPosition == self.dotPosition - 1)
    assert(r.symbolID == g.predot(at: dotPosition)!.id)
    assert(r.isCompletion == false)
    return r
  }
}

extension Chart.ItemID: DebuggableProductType {
  enum Kind { case completion, mainstem, leo }
  var reflectedChildren: KeyValuePairs<String, Any> {
    [
      "type": (isCompletion ? .completion : isLeo ? .leo : .mainstem) as Kind,
      "symbolID": (transitionSymbol ?? lhs)!.id,
      "origin": origin,
      "dotPosition": dotPosition
    ]
  }
}
