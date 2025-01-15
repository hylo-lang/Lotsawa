/// A mapping from keys `K` to arrays of values `[V]`, where by default every
/// key maps to the empty array.
struct
  MultiMap<K: Hashable, V> {
  /// The type used as underlying storage.
  typealias Storage = Dictionary<K, [V]>

  /// Creates an instance whose keys are the set of results of applying the given closure to each
  /// element of `s`, and whose values for a given key are the arrays of `s` elements for which
  /// `KeyForValue` returned that key.
  init<S: Sequence>(
    grouping s: S,
    by keyForValue: (S.Element) throws -> K
  ) rethrows where V == S.Element {
    storage = try Storage.init(grouping: s, by: keyForValue)
  }

  /// Creates an instance mapping every key to an empty array.
  init() {}

  /// Creates an instance using the given underlying `storage`.
  init(storage: Storage) {
    self.storage = storage
  }

  /// Accesses the array of values associated with k.
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

  /// Removes all values associated with key `k`.
  mutating func removeKey(_ k: K) { storage[k] = nil }

  /// Removes and returns all values associated with key `k`.
  mutating func removeValues(forKey k: K) -> [V] { storage.removeValue(forKey: k) ?? [] }

  private(set) var storage: Storage = [:]
}
