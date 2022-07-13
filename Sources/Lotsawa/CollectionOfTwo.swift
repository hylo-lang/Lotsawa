/*
struct CollectionOfTwo<T>: RandomAccessCollection {
  var storage: (T, T)
  init(_ storage: (T, T)) { self.storage = storage }
}

extension CollectionOfTwo {
  init(_ a: T, _ b: T) { self = .init((a, b)) }

  typealias Index = Int

  var count: Int { 2 }
  var startIndex: Int { 0 }
  var endIndex: Int { 2 }
  subscript()
}
*/
