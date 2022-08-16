private typealias Word = UInt
/*
/// Returns the offset at which the `i`th bit can be found in an array of
/// `Word`s.
private func wordOffset(ofBit i: Int) -> Int {
  precondition(i >= 0)
  return i / Word.bitWidth
}

/// Returns a mask that isolates the `i`th bit within its `Word` in an array of
/// `Word`s.
private func wordMask(ofBit i: Int) -> Word {
  precondition(i >= 0)
  return (1 as Word) << (i % Word.bitWidth)
}
*/

struct Bits<Base: Sequence>: Sequence
  where Base.Element: FixedWidthInteger
{
  public var base: Base
  typealias Element = Bool

  func makeIterator() -> Iterator { Iterator(base: base.makeIterator()) }

  struct Iterator: IteratorProtocol {
    typealias Element = Bool

    var base: Base.Iterator
    var buffer: Base.Element.Magnitude = 0

    mutating func next() -> Bool? {
      let r = buffer & 0x1 != 0
      buffer >>= 1
      if buffer != 0 { return r }
      guard let b = base.next() else { return nil }
      let r1 = b & 0x1 != 0
      buffer = Base.Element.Magnitude(truncatingIfNeeded: b)
      buffer >>= 1
      buffer |= 1 << (Base.Element.bitWidth - 1)
      return r1
    }
  }
}

extension Bits: Equatable where Base: Equatable {}
extension Bits: Hashable where Base: Hashable {}

extension Bits: RandomAccessCollection, BidirectionalCollection, Collection
  where Base: RandomAccessCollection
{
  typealias Index = Int
  var startIndex: Index { return 0 }
  var endIndex: Index { return base.count * Base.Element.bitWidth }

  /// Returns the offset at which the `i`th bit can be found in Base.
  func baseOffset(ofBit i: Int) -> Int {
    precondition(i >= 0)
    return i / Base.Element.bitWidth
  }

  /// Returns a mask that isolates the `i`th bit within its element in Base.
  func baseMask(ofBit i: Int) -> Base.Element {
    precondition(i >= 0)
    return (1 as Base.Element) &<< i
  }


  fileprivate func baseIndex(_ i: Index) -> Base.Index {
    base.index(base.startIndex, offsetBy: baseOffset(ofBit: i))
  }

  subscript(i: Index) -> Bool {
    base[baseIndex(i)] & ((1 as Base.Element) << (i % Base.Element.bitWidth)) != 0
  }
}

extension Bits: MutableCollection
  where Base: RandomAccessCollection & MutableCollection
{
  subscript(i: Int) -> Bool {
    get {
      base[baseIndex(i)] & baseMask(ofBit: i) != 0
    }
    set {
      if newValue {
        base[baseIndex(i)] |= baseMask(ofBit: i)
      }
      else {
        base[baseIndex(i)] &= ~baseMask(ofBit: i)
      }
    }
  }
}

struct BitSet: SetAlgebra, Hashable {
  typealias Element = Int
  typealias ArrayLiteralElement = Int

  /// Creates an empty set.
  init() {
    storage = []
  }

  /// Creates an empty set with storage preallocated to accomodate elements in
  /// `0...maxElementEstimate`
  init(elementMax maxElementEstimate: Int) {
    storage = []
    if maxElementEstimate > 0 {
      storage.reserveCapacity(storageCapacity(maxElement: maxElementEstimate))
    }
  }

  /// The number of storage words required to accomodate elements in `0...maxElement`.
  private func storageCapacity(maxElement: Int) -> Int {
    (maxElement + Word.bitWidth) / Word.bitWidth
  }

  /// Creates an instance using `storage` as its underlying storage.
  private init(storage: [Word]) {
    self.storage = storage
    trim()
  }

  /// Returns `true` if `n` is a element of `self`.
  func contains<N: BinaryInteger>(_ n: N) -> Bool {
    n >= 0 && n < bits.count && bits[Int(n)]
  }

  /// Returns the set of elements in either `self` or `other` (or both).
  func union(_ other: Self) -> Self {
    if self.isSuperset(of: other) { return self }
    if self.isSubset(of: other) { return other }

    return storage.withUnsafeBufferPointer{ b0 in
      other.storage.withUnsafeBufferPointer { b1 in
        Self(
          storage: (0..<max(b0.count, b1.count)).map { i in
            i < b0.count ? i < b1.count ? b0[i] | b1[i] : b0[i] : b1[i]
          })
      }
    }
  }

  /// Inserts the elements of `other` that are not already in `self`.
  mutating func formUnion(_ other: Self) {
    if self.isSuperset(of: other) { return }
    self.storage.reserveCapacity(other.storage.count)
    let overlap = min(storage.count, other.storage.count)
    other.storage.withUnsafeBufferPointer { b1 in
      storage.withUnsafeMutableBufferPointer{ b0 in
        for i in 0..<overlap {
          b0[i] |= b1[i]
        }
      }
      self.storage.append(contentsOf: b1.dropFirst(overlap))
    }
  }

  mutating func formUnionReportingChange(_ other: Self) -> Bool {
    if self.isSuperset(of: other) { return false }
    self.storage.reserveCapacity(other.storage.count)
    let overlap = min(storage.count, other.storage.count)
    other.storage.withUnsafeBufferPointer { b1 in
      storage.withUnsafeMutableBufferPointer{ b0 in
        for i in 0..<overlap {
          b0[i] |= b1[i]
        }
      }
      self.storage.append(contentsOf: b1.dropFirst(overlap))
    }
    return true
  }


  /// Returns the set of elements of `self` that are also in `other`.
  func intersection(_ other: Self) -> Self {
    if self.isSuperset(of: other) { return other }
    if self.isSubset(of: other) { return self }
    return storage.withUnsafeBufferPointer{ b0 in
      other.storage.withUnsafeBufferPointer { b1 in
        let newContents = (0..<min(b0.count, b1.count))
          .lazy.map { i in b0[i] & b1[i] }
          .dropLast { w in w == 0 }
        return Self(storage: Array(newContents))
      }
    }
  }

  /// Removes any elements of `self` that are not in `other`.
  mutating func formIntersection(_ other: Self) {
    if self.isSubset(of: other) { return }
    var newCount: Int = min(storage.count, other.storage.count)
    storage.withUnsafeMutableBufferPointer{ b0 in
      other.storage.withUnsafeBufferPointer { b1 in
        for i in 0..<newCount {
          b0[i] &= b1[i]
        }
        newCount = b0[..<newCount].dropLast { w in w == 0 }.count
      }
    }
    storage.removeSubrange(newCount...)
  }

  /// Returns the set of elements that are in `self` or `other`, but not both.
  func symmetricDifference(_ other: Self) -> Self {
    storage.withUnsafeBufferPointer{ b0 in
      other.storage.withUnsafeBufferPointer { b1 in
        let indices = 0..<max(b0.count, b1.count)
        let newContents = indices.lazy.map { i in
          i < b0.count ? i < b1.count ? b0[i] ^ b1[i] : b0[i] : b1[i]
        }
        return Self(storage: Array(newContents.dropLast { w in w == 0 }))
      }
    }
  }

  /// Replaces `self` with `self.symmetricDifference(other)`.
  mutating func formSymmetricDifference(_ other: Self) {
    self.storage.reserveCapacity(other.storage.count)
    let overlap = min(storage.count, other.storage.count)
    other.storage.withUnsafeBufferPointer { b1 in
      storage.withUnsafeMutableBufferPointer{ b0 in
        for i in 0..<overlap {
          b0[i] ^= b1[i]
        }
      }
      if b1.count > storage.count {
        storage.append(contentsOf: b1.dropFirst(overlap))
      }
      else if b1.count == storage.count { trim() }
    }
  }

  /// Inserts newElement if it was not already present, returing `true` and `newElement` if so, and
  /// returning `false` and `newElement` otherwise.
  @discardableResult
  mutating func insert<I: BinaryInteger>(_ newElement: I) -> (inserted: Bool, memberAfterInsert: I)
  {
    precondition(newElement >= 0, "BitSet can't store negative value \(newElement)")
    if newElement < bits.count {
      let r = (bits[Int(newElement)], newElement)
      bits[Int(newElement)] = true
      return r
    }
    let newCapacity = storageCapacity(maxElement: Int(newElement))
    storage.amortizedLinearReserveCapacity(newCapacity)
    storage.append(contentsOf: repeatElement(0, count: max(0, newCapacity - storage.count - 1)))
    storage.append(bits.baseMask(ofBit: Int(newElement)))
    return (true, newElement)
  }

  /// Removes `element` if it is a element of `self`, returning `element` if so, and `nil`
  /// otherwise.
  @discardableResult
  mutating func remove<I: BinaryInteger>(_ element: I) -> I?
  {
    if element < 0 || element >= bits.count || !bits[Int(element)] { return nil }
    bits[Int(element)] = false
    if bits.baseOffset(ofBit: Int(element)) + 1 == storage.count { trim() }
    return element
  }

  /// Inserts `newElement` if it was not already present, returing `nil` if so, and `newElement`
  /// otherwise.
  @discardableResult
  mutating func update<I: BinaryInteger>(with newElement: I) -> I? {
    self.insert(newElement).inserted ? newElement : nil
  }

  /// Returns `true` iff every element of `self` is in `other`.
  func isSubset(of other: Self) -> Bool {
    if storage.count > other.storage.count { return false }
    return storage.withUnsafeBufferPointer { b0 in
      other.storage.withUnsafeBufferPointer { b1 in
        zip(b0, b1).allSatisfy { x0, x1 in x0 & x1 == x0 }
      }
    }
  }

  /// Returns `true` iff no element of `self` is in `other`.
  func isDisjoint(with other: Self) -> Bool {
    storage.withUnsafeBufferPointer { b0 in
      other.storage.withUnsafeBufferPointer { b1 in
        zip(b0, b1).allSatisfy { x0, x1 in x0 & x1 == 0 }
      }
    }
  }

  /// Returns the elements of `self` that are not in `other`.
  public func subtracting(_ other: Self) -> Self {
    storage.withUnsafeBufferPointer{ b0 in
      other.storage.withUnsafeBufferPointer { b1 in
        let newContents =  b0.indices.lazy.map { i in i < b1.count ? b0[i] & ~b1[i] : b0[i] }
        return Self(storage: Array(newContents.dropLast { w in w == 0 }))
      }
    }
  }

  /// Removes the elements of `other` from `self`
  mutating func subtract(_ other: Self) {
    storage.withUnsafeMutableBufferPointer{ b0 in
      other.storage.withUnsafeBufferPointer { b1 in
        for i in 0..<min(b0.count, b1.count) {
          b0[i] &= ~b1[i]
        }
      }
    }
    if storage.count == other.storage.count { trim() }
  }

  /// True iff `self` has no elements.
  var isEmpty: Bool { storage.isEmpty }

  /// Returns the number of elements.
  func count() -> Int {
    storage.lazy.map(\.nonzeroBitCount).reduce(0, +)
  }

  /// A projection of the bits of `self` as a collection of `Bool`.
  private var bits: Bits<[Word]> {
    get { Bits(base: storage) }
    set { storage = newValue.base }
    _modify {
      var tmp: Bits<[Word]> = Bits(base: [])
      swap(&tmp.base, &storage)
      defer { swap(&tmp.base, &storage) }
      yield &tmp
    }
  }

  /// Removes any stored zeros at the end.
  private mutating func trim() {
    let nonZeroEnd = storage.withUnsafeBufferPointer { b in
      b.dropLast { w in w == 0 }.endIndex
    }
    storage.removeSubrange(nonZeroEnd...)
  }

  /// Storage for (at least) one `Bool` per element of `self`, packed into words.
  private var storage: [Word]
}
