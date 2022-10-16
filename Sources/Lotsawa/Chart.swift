/// Storage for incremental recognition results and the core representation of a parse forest.
public struct Chart
{
  /// Storage for all DerivationGroups, grouped by Earleme and sorted within each Earleme.
  private var entries: [Entry] = []

  /// The position in `chart` where each Earley/derivation set begins, plus a sentinel for the end
  /// of the last complete set.
  private var setStart: [Array<Entry>.Index] = [0]
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
  typealias EarleySet = Array<Entry>.SubSequence

  /// The item set under construction.
  var currentEarleySet: EarleySet {
    entries[setStart.last!...]
  }

  /// The index of the Earley set currently being worked on.
  var currentEarleme: SourcePosition {
    SourcePosition(setStart.count - 1)
  }

  /// The set of partial parses ending at earleme `i`.
  func earleySet(_ i: UInt32) -> EarleySet {
    entries[setStart[Int(i)]..<setStart[Int(i) + 1]]
  }
}

extension Chart {
  /// An Earley or Leo item.
  struct Item: Comparable {
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

    init(predicting ruleStart: DotPosition, at origin: SourcePosition, postdot: Symbol) {
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

    init(memoizing e: Self, transitionSymbol: Symbol) {
      self = e
      self.isLeo = true
      self.symbolID = transitionSymbol.id
      assert(!isEarley)
      assert(self.origin == e.origin)
      assert(self.dotPosition == e.dotPosition)
      assert(self.transitionSymbol == transitionSymbol)
      assert(!isCompletion)
   }

    /// Lookup key.
    var key: UInt64 {
      UInt64(storage.isCompletion_symbol_isEarley_originHi) << 32
        | UInt64(storage.originLow_dotPosition)
    }

    /// Lookup key for the start of the Leo-Earley sequence expecting a given symbol.
    ///
    /// Any Leo item always precedes Earley derivations in this sequence.
    var transitionKey: UInt32 { storage.isCompletion_symbol_isEarley_originHi }

    /// Lookup key for the start of the Leo-Earley sequence expecting symbol `s`.
    static func transitionKey(_ s: Symbol) -> UInt32 {
      return UInt32(s.id) << 17
    }


    /// Lookup key for the start of the sequence of completions for a given symbol
    ///
    /// Any Leo item always precedes Earley derivations in this sequence.
    var completionKey: UInt32 { storage.isCompletion_symbol_isEarley_originHi }

    /// Lookup key for the start of the sequence of completions of symbol `s`.
    static func completionKey(_ s: Symbol) -> UInt32 {
      return UInt32(truncatingIfNeeded: ~s.id) << 17
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
      Int32(bitPattern: storage.isCompletion_symbol_isEarley_originHi) < 0
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

    var transitionSymbol: Symbol? {
      isCompletion ? nil : Symbol(id: symbolID)
    }

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
    var origin: UInt32 {
      storage.isCompletion_symbol_isEarley_originHi << 16 | storage.originLow_dotPosition >> 16
    }

    /// The dot position representing this Item's parse progress.
    var dotPosition: UInt16 {
      UInt16(truncatingIfNeeded: storage.originLow_dotPosition)
    }

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

    /// If `self` is a Leo item, returns the Earley item it memoizes, assuming `g` is the grammar
    /// being parsed.
    func leoMemo<S>(in g: Grammar<S>) -> Item? {
      if isEarley { return nil }
      // A possible optimization: store the postdot symbol in the predotOrigin field of Leo items.
      var r = self
      r.symbolID = Symbol.ID(truncatingIfNeeded: g.ruleStore[Int(dotPosition)])
      r.isEarley = true
      return r
    }
  }

  /// Either a Leo Item, or a partial Earley item representing derivations with a given predot
  /// origin.
  ///
  /// Because a set of predot symbol origins is sufficient to efficiently reconstruct all
  /// derivations of any Earley item, and the non-derivation information is small, and
  /// ambiguity in useful grammars is low, each such item is represented as one or more
  /// consecutively stored `Entry`s, each representing one predot symbol origin.
  struct Entry: Comparable {
    var item: Item
    /// The origin of the predot symbol for this entry, if any.
    var predotOrigin: UInt32

    /// Returns `true` iff `lhs` should precede `rhs` in a derivation set.
    static func < (lhs: Self, rhs: Self) -> Bool {
      (lhs.item.key, lhs.predotOrigin) < (rhs.item.key, rhs.predotOrigin)
    }
  }

  /// Inserts `e` into the current Earley set, returning `true` iff `e.item` was not already present.
  @discardableResult
  mutating func insert(_ e: Entry) -> Bool {
    let i = currentEarleySet.partitionPoint { y in y >= e }
    let next = entries.at(i)
    if next == e { return false }
    entries.insert(e, at: i)
    return next?.item != e.item && currentEarleySet[..<i].last?.item != e.item
  }

  func transitionItems(on s: Symbol, inEarleySet i: UInt32)
    -> LazyPrefixWhileSequence<
         LazyMapSequence<LazyFilterSequence<EarleySet.SubSequence.Indices>, Item>>
  {
    let ithSet = earleySet(i)
    let k = Item.transitionKey(s)

    let j = ithSet.partitionPoint { d in d.item.transitionKey >= k }
    let items = ithSet[j...].lazy.map(\.item).droppingAdjacentDuplicates()
    return items.prefix(while: { x in x.symbolID == s.id })
  }

  func completions(of s: Symbol, inEarleySet i: UInt32)
    -> LazyPrefixWhileSequence<EarleySet.SubSequence>
  {
    let ithSet = earleySet(i)
    let k = Item.completionKey(s)

    let j = ithSet.partitionPoint { d in d.item.completionKey >= k }
    let r0 = ithSet[j...]
    let r = r0.lazy.prefix(while: { x in x.item.lhs == s })
    return r
  }

  /// Completes the current earleme and moves on to the next one, returning `true` unless no
  /// progress was made in the current earleme.
  mutating func finishEarleme() -> Bool {
    setStart.append(entries.count)
    return setStart.last != setStart.dropLast().last
  }
}

// Lookups:
//
// * Leo item with a particular transition symbol (or the set of derivations awaiting that symbol),
//   meaning that derivations follow Leo items.
//
// * Completions of a particular LHS symbol with a particular origin
//
// * a particular element in the current derivation set
//
// Sort key must
// <---------------- 18 --------------------------------><--origin14->| <--origin18--><----dotPosition 14----> |
// <isCompletion 1><transition symbol or lhs 16><isEarley 1><origin 32> <dotPosition 16> <predotOrigin 32>
// +------------+------------+-------------+----------+----------+------------+
// |            |origin      |dotPosition  |transition|lhs       |predotOrigin|
// +------------+------------+-------------+----------+----------+------------+
// |Prediction  |            |             |          |   NO     |    NO      |
// +------------+------------+-------------+----------+----------+------------+
// |Intermediate|            |             |          |   NO     |            |
// +------------+------------+-------------+----------+----------+------------+
// |Completion  |            |             |    NO    |   YES    |            |
// +------------+------------+-------------+----------+----------+------------+
// |Leo         |            |             |          |   NO     |    NO      |
// +------------+------------+-------------+----------+----------+------------+
// |Bits        | 32         | 16          | 8        | 8        | 32         |
// +------------+------------+-------------+----------+----------+------------+
//

// Order non-completions by transition key. For Leo items that's transition symbol; otherwise it's
// postdot.
//
// Order leo items before incompletions having the same transition key.  We can steal the low bit of
// the transition key for this purpose, since symbols are  positive signed integers.
//
// Order completions last by using the high bit of the first key
//
// This leaves us with one transition key value that can be used later (vary the low bit on
// the transition key with the max symbol value).

// (transitionKey, item.isLeo ? 0 : 1, item.dotPosition, item.origin, predotOrigin ?? 0)
