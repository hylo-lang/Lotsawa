/// Storage for incremental recognition results and the core representation of a parse forest.
public struct Chart: Hashable
{
  /// Storage for all chart entries
  public typealias Entries = Array<Entry>

  /// Identifier of an entry in the chart.
  typealias Position = Entries.Index

  /// Storage for all DerivationGroups, grouped by Earleme and sorted within each Earleme.
  internal private(set) var entries: [Entry] = []

  /// The position in `chart` where each Earley/derivation set begins, plus a sentinel for the end
  /// of the last complete set.
  private var setStart: [Position] = [0]
}

public typealias SourcePosition = UInt32
public typealias DotPosition = UInt16

extension Chart {
  /// Clear `entries` and `setStart` without deallocating their storage.
  mutating func removeAll() {
    entries.removeAll(keepingCapacity: true)
    setStart.removeAll(keepingCapacity: true)
    setStart.append(0)
  }
}

extension Chart {
  public typealias EarleySet = Array<Entry>.SubSequence

  /// The item set under construction.
  var currentEarleySet: EarleySet {
    entries[setStart.last!...]
  }

  /// The index of the Earley set currently being worked on.
  var currentEarleme: SourcePosition {
    SourcePosition(setStart.count - 1)
  }

  /// The set of partial parses ending at earleme `i`.
  public func earleySet(_ i: SourcePosition) -> EarleySet {
    entries[setStart[Int(i)]..<setStart[Int(i) + 1]]
  }

  public func earleme(ofEntryIndex j: Entries.Index) -> SourcePosition {
    SourcePosition(setStart.partitionPoint { start in start > j } - 1)
  }
}

extension Chart {
  /// An Earley or Leo item.
  struct Item: Comparable, Hashable {
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
    init(memoizingItemIndex m: Entries.Index, transitionSymbol: Symbol) {
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
    var memoizedPenultIndex: Entries.Index? {
      return isLeo ? Entries.Index(storage.originLow_dotPosition) : nil
    }

    /// Returns `self` with the dot advanced over one symbol.
    ///
    /// - Precondition: `self` is an incomplete Earley item,
    func advanced<S>(in g: Grammar<S>) -> Item {
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
    func mainstem<S>(in g: Grammar<S>) -> Item {
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

    /// If `self` is a Leo item, returns the Earley item it memoizes, assuming `g` is the grammar
    /// being parsed; returns `nil` otherwise.
    func leoMemo<S>(in g: Grammar<S>) -> Item? {
      if isEarley { return nil }
      var r = self
      r.symbolID = Symbol.ID(g.ruleStore[Int(dotPosition)])
      r.isEarley = true
      assert(r.isCompletion)
      return r
    }
  }

  /// A Leo or Earley item bundled with a single mainstem cause.
  public struct Entry: Comparable, Hashable {
    var item: Item

    /// The chart position where derivations of this entry's mainstem start, if any.
    var mainstemIndex: Entries.Index? {
      get { mainstemIndexStorage == ~0 ? nil : .init(mainstemIndexStorage) }
      set { mainstemIndexStorage = newValue == nil ? ~0 : .init(newValue!) }
    }

    /// Creates an instance with the given properties
    ///
    /// - Precondition: `0 <= mainstemIndex && mainstemIndex <= UInt.max`
    init(item: Item, mainstemIndex: Entries.Index?) {
      self.item = item
      self.mainstemIndexStorage = 0 // About to be overridden
      self.mainstemIndex = mainstemIndex
    }

    /// Storage for the chart position where derivations of this entry's mainstem start.
    var mainstemIndexStorage: UInt32

    /// Returns `true` iff `lhs` should precede `rhs` in a derivation set.
    public static func < (lhs: Self, rhs: Self) -> Bool {
      (lhs.item.key, lhs.mainstemIndexStorage) < (rhs.item.key, rhs.mainstemIndexStorage)
    }
  }

  private func isItemIndexStart(_ i: Entries.Index) -> Bool {
    let s = earleySet(earleme(ofEntryIndex: i))
    return i == s.startIndex || s[s.index(before: i)].item != s[i].item
  }

  /// Inserts `e` into the current Earley set, returning `true` iff `e.item` was not already present.
  @discardableResult
  mutating func insert(_ e: Entry) -> Bool {
    assert(e.mainstemIndex == nil || isItemIndexStart(e.mainstemIndex!))
    let i = currentEarleySet.partitionPoint { y in y >= e }
    let next = entries.at(i)
    if next == e { return false }
    entries.insert(e, at: i)
    return next?.item != e.item && currentEarleySet[..<i].last?.item != e.item
  }

  /// Returns the entries in Earley set `i` whose use is triggered by the recognition of `s`.
  func transitionEntries(on s: Symbol, inEarleySet i: UInt32) -> Entries.SubSequence
  {
    let ithSet = i == currentEarleme ? currentEarleySet : earleySet(i)
    let k = Item.transitionKey(s)

    let j = ithSet.partitionPoint { d in d.item.transitionKey >= k }
    let items = ithSet[j...]
    return items.prefix(while: { x in x.item.symbolID == s.id })
  }

  /// Returns the items in Earley set `i` whose use is triggered by the recognition of `s`.
  func transitionItems(on s: Symbol, inEarleySet i: UInt32) -> some BidirectionalCollection<Item>
  {
    transitionEntries(on: s, inEarleySet: i).lazy.map(\.item).droppingAdjacentDuplicates()
  }

  /// Returns the entries that complete a recognition of `lhs` covering `extent`.
  ///
  /// - Complexity: O(N) where N is the length of the result.
  func completions(of lhs: Symbol, over extent: Range<SourcePosition>) -> Entries.SubSequence
  {
    let ithSet = earleySet(extent.upperBound)
    let k = Item.completionKey(lhs, origin: extent.lowerBound)

    let j = ithSet.partitionPoint { d in d.item.key >= k }
    let r0 = ithSet[j...]
    let r = r0.prefix(while: { x in x.item.lhs == lhs && x.item.origin == extent.lowerBound })
    return r
  }

  /// Given an item `x`, found in earley set `i`, returns the chart positions of its mainstem items.
  func mainstemIndices(of x: Item, inEarleySet i: UInt32)
    -> some BidirectionalCollection<Entries.Index>
  {
    let ithSet = earleySet(i)
    let j = ithSet.partitionPoint { d in d.item >= x }
    return ithSet[j...].lazy.prefix(while: { y in y.item == x }).map(\.mainstemIndex!)
  }

  /// Returns the item *m* at `x`'s mainstemIndex if *m* is an Earley item, or *m*'s
  /// memoized Earley item index otherwise.
  ///
  /// - Complexity: O(N) where N is the length of the result.
  func earleyMainstem(of x: Entry) -> Entries.SubSequence
  {
    guard let m = x.mainstemIndex else { return entries[entries.endIndex...] }
    let head = entries[m].item
    let start = head.memoizedPenultIndex ?? m
    let tail = earleySet(earleme(ofEntryIndex: start))[start...].dropFirst()
    return entries[start..<tail.prefix { $0.item == head }.endIndex]
  }

  /// Completes the current earleme and moves on to the next one, returning `true` unless no
  /// progress was made in the current earleme.
  mutating func finishEarleme() -> Bool {
    setStart.append(entries.count)
    return setStart.last != setStart.dropLast().last
  }
}

extension Chart {
  /// Injects a Leo item memoizing `x` with transition symbol `t` before entries[i].item, returning
  /// true if it was not already present.
  mutating func insertLeo(_ leo: Entry, at i: Int) -> Bool {
    assert(leo.item.isLeo)
    if entries[i].item == leo.item {
      // FIXME: can we prove we never arrive here?  Should be possible.
      assert(
        entries[i].mainstemIndex == leo.mainstemIndex,
        "Leo item \(leo.item)"
          + " multiple mainstems \(leo.mainstemIndex!), \(entries[i].mainstemIndex!))")
      return false
    }
    entries.insert(leo, at: i)
    return true
  }
}

protocol DebuggableProductType: CustomReflectable, CustomStringConvertible {
  associatedtype ReflectedChildren: Collection
    where ReflectedChildren.Element == (key: String, value: Any)
  var reflectedChildren: ReflectedChildren { get }
}

private protocol OptionalProtocol {
  var valueString: String { get }
}

extension Optional: OptionalProtocol {
  var valueString: String {
    self == nil ? "nil" : "\(self!)"
  }
}

func valueString<T>(_ x: T) -> String {
  (x as? any OptionalProtocol)?.valueString ?? "\(x)"
}

extension DebuggableProductType {
  public var customMirror: Mirror {
    .init(self, children: reflectedChildren.lazy.map {(label: $0.key, value: $0.value)})
  }

  public var description: String {
    "{"
      + String(reflectedChildren.map { "\($0.key): \(valueString($0.value))" }
                 .joined(separator: ", "))
      + "}"
  }
}

extension Chart.Item: DebuggableProductType {
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

extension Chart: CustomStringConvertible {
  public var description: String {
    var r = "[\n"
    var s = setStart[...]
    for i in entries.indices {
      if i == s.first {
        r += "// \(s.startIndex)\n"
        _ = s.popFirst()
      }
      r += "\(i): \(entries[i])\n"
    }
    r += "\n]"
    return r
  }
}

extension Chart.Entry: DebuggableProductType {
  var reflectedChildren: [(key: String, value: Any)] {
    item.reflectedChildren + [("mainstemIndex", mainstemIndex as Any)]
  }
}
