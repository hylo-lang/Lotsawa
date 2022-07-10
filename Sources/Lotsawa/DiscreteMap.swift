/// A mapping from `Key`s to `Value`s, where a key `k` not explicitly specified is mapped to the
/// value associated of the next lower key plus the distance from that key to `k`.
struct DiscreteMap<Key: Strideable, Value: Strideable>
  where Key.Stride: SignedInteger, Value.Stride: SignedInteger
{
  var points: [(key: Key, value: Value)] = []

  /// Returns the value for key `k`.
  ///
  /// - Precondition: a mapping has been appended with key < `k`.
  subscript(k: Key) -> Value {
    let i = points.partitionPoint { e in e.key > k }
    return offsetValue(from: points.prefix(i).last!, for: k)
  }

  /// Maps `k` to `v`, and  `k` + *n* to `v` + *n* for 0 ≤ *n*.
  ///
  /// - Precondition: `k` exceeds any key from a previously appended mapping; the distance between
  ///   successive keys is representable as `Value.Stride`.
  mutating func appendMapping(from k: Key, to v: Value) {
    if !points.isEmpty {
      precondition(k > points.last.unsafelyUnwrapped.key)
      if offsetValue(from: points.last.unsafelyUnwrapped, for: k) == v { return }
    }
    points.append((key: k, value: v))
  }

  /// Returns the mapping for `k`, where `base.key` + *n* is mapped to `base.value` + *n* for 0 ≤
  /// *n*.
  ///
  /// - Precondition: the distance between successive keys is representable as `Value.Stride`.
  private func offsetValue(from base: (key: Key, value: Value), for k: Key) -> Value {
    base.value.advanced(by: Value.Stride(base.key.distance(to: k)))
  }
}
