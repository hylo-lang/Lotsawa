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
  /// A Leo or Earley item bundled with a single mainstem cause.
  @dynamicMemberLookup
  public struct Entry: Comparable, Hashable {
    var item: ItemID

    /// The chart position where derivations of this entry's mainstem start, if any.
    var mainstemIndex: Entries.Index? {
      get { mainstemIndexStorage == ~0 ? nil : .init(mainstemIndexStorage) }
      set { mainstemIndexStorage = newValue == nil ? ~0 : .init(newValue!) }
    }

    /// Creates an instance with the given properties
    ///
    /// - Precondition: `0 <= mainstemIndex && mainstemIndex <= UInt.max`
    init(item: ItemID, mainstemIndex: Entries.Index?) {
      self.item = item
      self.mainstemIndexStorage = 0 // About to be overridden
      self.mainstemIndex = mainstemIndex
    }

    /// Storage for the chart position where derivations of this entry's mainstem start.
    var mainstemIndexStorage: UInt32

    /// Returns `true` iff `lhs` should precede `rhs` in a derivation set.
    public static func < (lhs: Self, rhs: Self) -> Bool {
      (lhs.key, lhs.mainstemIndexStorage) < (rhs.key, rhs.mainstemIndexStorage)
    }

    subscript<Target>(dynamicMember m: KeyPath<ItemID, Target>) -> Target {
      item[keyPath: m]
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
    let k = ItemID.transitionKey(s)

    let j = ithSet.partitionPoint { d in d.transitionKey >= k }
    let items = ithSet[j...]
    return items.prefix(while: { x in x.symbolID == s.id })
  }

  /// Returns the items in Earley set `i` whose use is triggered by the recognition of `s`.
  func transitionItems(on s: Symbol, inEarleySet i: UInt32) -> some BidirectionalCollection<ItemID>
  {
    transitionEntries(on: s, inEarleySet: i).lazy.map(\.item).droppingAdjacentDuplicates()
  }

  /// Returns the entries that complete a recognition of `lhs` covering `extent`.
  ///
  /// - Complexity: O(N) where N is the length of the result.
  func completions(of lhs: Symbol, over extent: Range<SourcePosition>) -> Entries.SubSequence
  {
    let ithSet = earleySet(extent.upperBound)
    let k = ItemID.completionKey(lhs, origin: extent.lowerBound)

    let j = ithSet.partitionPoint { d in d.key >= k }
    let r0 = ithSet[j...]
    let r = r0.prefix(while: { x in x.lhs == lhs && x.origin == extent.lowerBound })
    return r
  }

  /// Given an item `x`, found in earley set `i`, returns the chart positions of its mainstem items.
  func mainstemIndices(of x: ItemID, inEarleySet i: UInt32)
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
    assert(leo.isLeo)
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

extension Chart {
  /// Returns the sequence of entries awaiting advancement on symbol `s` if that sequence begins
  /// with a Leo item, and nil otherwise.
  func leoDerivations(awaiting s: Symbol, at i: SourcePosition)
    -> Optional<some BidirectionalCollection<Entry>>
  {

    let predecessors = transitionEntries(on: s, inEarleySet: i)
    return predecessors.first.map { $0.isLeo ? predecessors : nil } ?? nil
  }
}
