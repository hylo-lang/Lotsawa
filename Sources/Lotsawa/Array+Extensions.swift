extension Array {
  /// Version of reserveCapacity that ensures repeated increasing requests have
  /// amortized complexity O(N), where N is the total capacity reserved.
  mutating func amortizedLinearReserveCapacity(_ minimumCapacity: Int) {
    let n = capacity > minimumCapacity ? capacity : Swift.max(2 * capacity, minimumCapacity)
    reserveCapacity(n) // Note: must reserve unconditionally to ensure uniqueness
  }
}
