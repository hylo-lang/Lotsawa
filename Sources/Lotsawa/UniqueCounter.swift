struct UniqueCounter<T: Hashable> {
  private var scratch: Set<T> = []

  mutating func callAsFunction<S: Sequence>(_ toBeCounted: S) -> Int
    where S.Element == T
  {
    scratch.formUnion(toBeCounted)
    defer { scratch.removeAll(keepingCapacity: true) }
    return scratch.count
  }
}
