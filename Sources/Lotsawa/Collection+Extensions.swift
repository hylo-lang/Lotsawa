extension Collection {
  /// Returns the element at `i`, or `nil` iff `i == endIndex`
  func at(_ i: Index) -> Element? {
    i == endIndex ? nil : self[i]
  }

  /// Returns a lazy view of `self` omitting elements which are equivalent to their right-hand neighbor.
  func droppingAdjacentDuplicates(equivalence: @escaping (Element, Element)->Bool)
    -> LazyMapSequence<LazyFilterSequence<Indices>, Element>
  {
    indices.lazy.filter { i in
      index(after: i) == endIndex || !equivalence(self[i], self[index(after: i)])
    }.map { i in self[i] }
  }
}

extension Collection where Element: Equatable {
  /// Returns a lazy view of `self` omitting elements which compare equal to their right-hand neighbor.
  func droppingAdjacentDuplicates()
    -> LazyMapSequence<LazyFilterSequence<Indices>, Element>
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
