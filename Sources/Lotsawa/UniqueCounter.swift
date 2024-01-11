/// A function object; returns the number of unique `T`'s in a given Sequence.
///
/// Implemented as a function object to optimize repeated invocations by reusing a Set<T>.
struct UniqueCounter<T: Hashable> {
  private var scratch: Set<T> = []

  /// Returns the number of unique elements in `toBeCounted`.
  mutating func callAsFunction<S: Sequence>(_ toBeCounted: S) -> Int
    where S.Element == T
  {
    scratch.formUnion(toBeCounted)
    defer { scratch.removeAll(keepingCapacity: true) }
    return scratch.count
  }
}
