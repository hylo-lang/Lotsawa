extension Collection {
  /// Returns true iff `self` has exactly one element.
  var hasUniqueElement: Bool {
    var p = makeIterator()
    return p.next() != nil && p.next() == nil
  }

  /// Returns `true` iff exactly one element of `self` satisfies `condition`.
  ///
  /// - Complexity: O(`count`)
  func hasUniqueElement(where condition: (Element)->Bool) -> Bool {
    guard let j = firstIndex(where: condition)
    else { return false }
    return self[index(after: j)...].allSatisfy { p in !condition(p) }
  }
}

/// Indicator of whether all elements, just some elements, or no elements of a collection satisfy
/// some predicate.
///
/// - See also: `Collection.satisfaction`.
enum AllSomeNone { case all, some, none }

extension Collection {
  /// Returns an indication of whether all, some, or no elements satisfy `predicate`.
  ///
  /// - Complexity: O(`count`)
  func satisfaction(_ predicate: (Element)->Bool) -> AllSomeNone {
    guard let i = firstIndex(where: predicate) else { return .none }
    if i == startIndex && dropFirst().allSatisfy(predicate) { return .all }
    return .some
  }

  /// Returns the nth element of `self`.
  ///
  /// Works even if `Self.Index == Int` and `startIndex != 0`, so is useful for array slices.
  ///
  /// - Precondition: `count > n`
  func nth(_ n: Int) -> Element { dropFirst(n).first! }
}
