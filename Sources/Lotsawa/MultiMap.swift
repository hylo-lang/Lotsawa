/// A mapping from keys `K` to arrays of values `[V]`, where by default every
/// key maps to the empty array.
struct MultiMap<K: Hashable, V> {
  typealias Storage = Dictionary<K, [V]>

  subscript(k: K) -> [V] {
    set { storage[k] = newValue }
    _modify { yield &storage[k, default: []] }
    _read { yield storage[k, default: []] }
  }

  /// The keys in this MultiMap.
  ///
  /// - Note: the order of these keys is incidental.
  var keys: Storage.Keys {
    get { storage.keys }
  }

  /// The sets of values in this MultiMap.
  ///
  /// - Note: the order of these sets is incidental.
  var values: Storage.Values {
    get { storage.values }
  }

  mutating func removeKey(_ k: K) { storage[k] = nil }
  mutating func removeValues(forKey k: K) -> [V] { storage.removeValue(forKey: k) ?? [] }

  private(set) var storage: Storage = [:]
}
