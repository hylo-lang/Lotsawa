extension Collection {
  /// Returns the element at `i`, or `nil` iff `i == endIndex`
  func at(_ i: Index) -> Element? {
    i == endIndex ? nil : self[i]
  }
}

extension Collection where Element: Equatable {
  /// Returns a lazy view of `self` omitting elements that compare equal to their right-hand
  /// neighbor.
  func droppingAdjacentDuplicates() -> some Collection<Element>
  {
    indices.lazy.filter { i in
      index(after: i) == endIndex || self[i] != self[index(after: i)]
    }.map { i in self[i] }
  }
}

extension BidirectionalCollection {
  /// Returns a lazy view of `self` omitting elements that are equivalent to their left-hand
  /// neighbor per the equivalence relation `equivalence`.
  func keepingFirstOfAdjacentDuplicates(equivalence: @escaping (Element, Element)->Bool)
    -> some BidirectionalCollection<Element>
  {
    indices.lazy.filter { i in
      i == startIndex || !equivalence(self[index(before: i)], self[i])
    }.map { i in self[i] }
  }
}

extension BidirectionalCollection where Element: Equatable {
  /// Returns a lazy view of `self` omitting elements that compare equal to their right-hand
  /// neighbor.
  func droppingAdjacentDuplicates() -> some BidirectionalCollection<Element>
  {
    indices.lazy.filter { i in
      index(after: i) == endIndex || self[i] != self[index(after: i)]
    }.map { i in self[i] }
  }
}

extension Collection {
  /// Returns the index of the first element in the collection
  /// that matches the predicate.
  ///
  /// The collection must already be partitioned according to the
  /// predicate, as if `self.partition(by: predicate)` had already
  /// been called.
  ///
  /// - Efficiency: At most log(N) invocations of `predicate`, where
  ///   N is the length of `self`.  At most log(N) index offsetting
  ///   operations if `self` conforms to `RandomAccessCollection`;
  ///   at most N such operations otherwise.
  func partitionPoint(
    where predicate: (Element) throws -> Bool
  ) rethrows -> Index {
    var n = distance(from: startIndex, to: endIndex)
    var l = startIndex

    while n > 0 {
      let half = n / 2
      let mid = index(l, offsetBy: half)
      if try predicate(self[mid]) {
        n = half
      } else {
        l = index(after: mid)
        n -= half + 1
      }
    }
    return l
  }
}

extension BidirectionalCollection {
  /// Returns `self` sans any suffix elements satisfying `predicate`.
  public func dropLast(while predicate: (Element) throws -> Bool) rethrows -> Self.SubSequence {
    let head = try self.reversed().drop(while: predicate)
    return self[head.endIndex.base..<head.startIndex.base]
  }

  /// Returns the longest suffix of `self` s.t. all elements satisfy predicate
  public func suffix(while predicate: (Element) throws -> Bool) rethrows -> Self.SubSequence {
    return try self[dropLast(while: predicate).endIndex...]
  }
}

extension Collection where Element: Comparable {

  /// Returns `true` iff the elements are in ascending order.
  func isSorted() -> Bool {
    return zip(self, self.dropFirst()).allSatisfy { $0 < $1 }
  }

  /// Returns an array containing the elements of `self` and `other` in ascending order.
  ///
  /// The result is equivalent to that of `(Array(self) + other).sorted()`.
  ///
  /// - Complexity: O(count + other.count)
  ///
  /// - Precondition: `self.isSorted() && other.isSorted()`
  func merged<C: Collection>(with other: C) -> [Element]
    where C.Element == Element
  {
    var r: [Element] = []
    r.reserveCapacity(count + other.count)

    var c0 = self[...]
    var c1 = other[...]
    while !c0.isEmpty && !c1.isEmpty {
      r.append(c0.first! < c1.first! ? c0.popFirst()! : c1.popFirst()!)
    }
    r.append(contentsOf: c0)
    r.append(contentsOf: c1)
    return r
  }
}
