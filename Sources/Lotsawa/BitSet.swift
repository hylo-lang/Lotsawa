private typealias Word = UInt

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

/// An adapter that presents a base instance of `S` as a sequence of bits packed
/// into `Word`, where `true` and `false` in the base are represented as `1` and
/// `0` bits in an element of `self`, respectively.
private struct PackedIntoWords<S: Sequence>: Sequence where S.Element == Bool {
  /// The iteration state of a traversal of a `PackedIntoWords`.
  struct Iterator: IteratorProtocol {
    var base: S.Iterator

    mutating func next() -> Word? {
      guard let b = base.next() else { return nil }
      var r: Word = b ? 1 : 0
      for i in 1..<Word.bitWidth {
        guard let b = base.next() else { return r }
        if b { r |= wordMask(ofBit: i) }
      }
      return r
    }
  }
  /// Returns a new iterator over `self`.
  func makeIterator() -> Iterator { Iterator(base: base.makeIterator()) }

  /// Returns a number no greater than the number of elements in `self`.
  var underestimatedCount: Int {
    (base.underestimatedCount + Word.bitWidth - 1) / Word.bitWidth
  }

  /// The underlying sequence of `Bool`.
  let base: S

  init(_ base: S) { self.base = base }
}

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

  fileprivate func baseIndex(_ i: Index) -> Base.Index {
    base.index(base.startIndex, offsetBy: i / Base.Element.bitWidth)
  }

  subscript(i: Index) -> Bool {
    base[baseIndex(i)] & (1 << (i % Base.Element.bitWidth)) != 0
  }
}

extension Bits: MutableCollection
  where Base: RandomAccessCollection & MutableCollection
{
  subscript(i: Int) -> Bool {
    get {
      base[baseIndex(i)] & (1 << (i % Base.Element.bitWidth)) != 0
    }
    set {
      if newValue {
        base[baseIndex(i)] |= (1 << (i % Base.Element.bitWidth))
      }
      else {
        base[baseIndex(i)] &= ~(1 << (i % Base.Element.bitWidth))
      }
    }
  }
}


struct BitSet: SetAlgebra {
  typealias Element = Int
  typealias ArrayLiteralElement = Int

  init() {
    storage = []
  }

  init(elementMax maxElementEstimate: Int) {
    storage = []
    if maxElementEstimate > 0 {
      storage.reserveCapacity(storageCapacity(maxElement: maxElementEstimate))
    }
  }

  private func storageCapacity(maxElement: Int) -> Int {
    (maxElement + Word.bitWidth) / Word.bitWidth
  }

  private init(storage: [Word]) { self.storage = storage }

  func contains<N: BinaryInteger>(_ n: N) -> Bool {
    n >= 0 && n < bits.count && bits[Int(n)]
  }

  func union(_ other: Self) -> Self {
    storage.withUnsafeBufferPointer{ b0 in
      other.storage.withUnsafeBufferPointer { b1 in
        Self(
          storage: (0..<max(b0.count, b1.count)).map { i in
            i < b0.count ? i < b1.count ? b0[i] | b1[i] : b0[i] : b1[i]
          })
      }
    }
  }

  mutating func formUnion(_ other: Self) {
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

  func intersection(_ other: Self) -> Self {
    storage.withUnsafeBufferPointer{ b0 in
      other.storage.withUnsafeBufferPointer { b1 in
        Self(
          storage: (0..<min(b0.count, b1.count)).map { i in
            b0[i] & b1[i]
          })
      }
    }
  }

  mutating func formIntersection(_ other: Self) {
    let newCount = min(storage.count, other.storage.count)
    storage.removeLast(storage.count - newCount)
    storage.withUnsafeMutableBufferPointer{ b0 in
      other.storage.withUnsafeBufferPointer { b1 in
        for i in 0..<newCount {
          b0[i] &= b1[i]
        }
      }
    }
  }

  func symmetricDifference(_ other: Self) -> Self {
    storage.withUnsafeBufferPointer{ b0 in
      other.storage.withUnsafeBufferPointer { b1 in
        Self(
          storage: (0..<max(b0.count, b1.count)).map { i in
            i < b0.count ? i < b1.count ? b0[i] ^ b1[i] : b0[i] : b1[i]
          })
      }
    }
  }

  mutating func formSymmetricDifference(_ other: Self) {
    self.storage.reserveCapacity(other.storage.count)
    let overlap = min(storage.count, other.storage.count)
    other.storage.withUnsafeBufferPointer { b1 in
      storage.withUnsafeMutableBufferPointer{ b0 in
        for i in 0..<overlap {
          b0[i] ^= b1[i]
        }
      }
      self.storage.append(contentsOf: b1.dropFirst(overlap))
    }
  }

  mutating func insert<I: BinaryInteger>(_ newMember: I) -> (inserted: Bool, memberAfterInsert: I)
  {
    precondition(newMember >= 0, "BitSet can't store negative value \(newMember)")
    if newMember < bits.count {
      let r = (bits[Int(newMember)], newMember)
      bits[Int(newMember)] = true
      return r
    }
    let newCapacity = storageCapacity(maxElement: Int(newMember))
    storage.amortizedLinearReserveCapacity(newCapacity)
    storage.append(contentsOf: repeatElement(0, count: max(0, newCapacity - storage.count - 1)))
    storage.append(1 &<< (Int(newMember) % Word.bitWidth))
    return (true, newMember)
  }

  mutating func remove<I: BinaryInteger>(_ member: I) -> I?
  {
    if member < 0 || member >= bits.count || !bits[Int(member)] { return nil }
    bits[Int(member)] = false
    return member
  }

  mutating func update<I: BinaryInteger>(with newMember: I) -> I? {
    self.insert(newMember).inserted ? newMember : nil
  }

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

  private var storage: [Word]
}

// Array(Bits(base: [-128 as Int8]))
