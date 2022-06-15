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
