extension Collection {
  var hasUniqueElement: Bool {
    var p = makeIterator()
    return p.next() != nil && p.next() == nil
  }

  func hasUniqueElement(where condition: (Element)->Bool) -> Bool {
    guard let j = firstIndex(where: condition)
    else { return false }
    return self[index(after: j)...].allSatisfy { p in !condition(p) }
  }
}

enum AllSomeNone { case all, some, none }

extension Collection {
  /// Returns an indication of whether all, some, or no elements satisfy `predicate`.
  func satisfaction(_ predicate: (Element)->Bool) -> AllSomeNone {
    guard let i = firstIndex(where: predicate) else { return .none }
    if i == startIndex && dropFirst().allSatisfy(predicate) { return .all }
    return .some
  }

  func nth(_ n: Int) -> Element { dropFirst(n).first! }
}
