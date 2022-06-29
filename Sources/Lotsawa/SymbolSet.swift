struct SymbolSet<ID: BinaryInteger>: SetAlgebra, Hashable, Equatable {
  typealias Element = Symbol<ID>
  typealias ArrayLiteralElement = Symbol<ID>

  /// Creates an empty set.
  init() { elementIDs = BitSet() }

  /// Creates the set of symbols whose IDs are in `elementIDs`.
  init(elementIDs: BitSet) { self.elementIDs = elementIDs }

  /// Creates an empty set with storage preallocated to accomodate elements with IDs in
  /// `0...maxElementIDEstimate`
  init(elementIDMax maxElementIDEstimate: Int) {
    elementIDs = BitSet(elementMax: maxElementIDEstimate)
  }

  /// Returns `true` if `x` is a element of `self`.
  func contains(_ x: Element) -> Bool {
    elementIDs.contains(x.id)
  }

  /// Returns the set of elements in either `self` or `other` (or both).
  func union(_ other: Self) -> Self {
    Self(elementIDs: elementIDs.union(other.elementIDs))
  }

  /// Inserts the elements of `other` that are not already in `self`.
  mutating func formUnion(_ other: Self) {
    elementIDs.formUnion(other.elementIDs)
  }

  /// Returns the set of elements of `self` that are also in `other`.
  func intersection(_ other: Self) -> Self {
    Self(elementIDs: elementIDs.intersection(other.elementIDs))
  }

  /// Removes any elements of `self` that are not in `other`.
  mutating func formIntersection(_ other: Self) {
    elementIDs.formIntersection(other.elementIDs)
  }

  /// Returns the set of elements that are in `self` or `other`, but not both.
  func symmetricDifference(_ other: Self) -> Self {
    Self(elementIDs: elementIDs.symmetricDifference(other.elementIDs))
  }

  /// Replaces `self` with `self.symmetricDifference(other)`.
  mutating func formSymmetricDifference(_ other: Self) {
    elementIDs.formSymmetricDifference(other.elementIDs)
  }

  /// Inserts newElement if it was not already present, returing `true` and `newElement` if so, and
  /// returning `false` and `newElement` otherwise.
  @discardableResult
  mutating func insert(_ newElement: __owned Element) -> (inserted: Bool, memberAfterInsert: Element)
  {
    (elementIDs.insert(newElement.id).0, newElement)
  }

  /// Removes `element` if it is a element of `self`, returning `element` if so, and `nil`
  /// otherwise.
  @discardableResult
  mutating func remove(_ element: Element) -> Element?
  {
    elementIDs.remove(element.id).map { _ in element }
  }

  /// Inserts `newElement` if it was not already present, returing `nil` if so, and `newElement`
  /// otherwise.
  @discardableResult
  mutating func update(with newElement: Element) -> Element? {
    elementIDs.update(with: newElement.id).map { _ in newElement }
  }

  /// Returns `true` iff every element of `self` is in `other`.
  func isSubset(of other: Self) -> Bool {
    elementIDs.isSubset(of: other.elementIDs)
  }

  /// Returns `true` iff no element of `self` is in `other`.
  func isDisjoint(with other: Self) -> Bool {
    elementIDs.isDisjoint(with: other.elementIDs)
  }

  /// Returns the elements of `self` that are not in `other`.
  public func subtracting(_ other: Self) -> Self {
    Self(elementIDs: elementIDs.subtracting(other.elementIDs))
  }

  /// Removes the elements of `other` from `self`
  mutating func subtract(_ other: Self) {
    elementIDs.subtract(other.elementIDs)
  }

  /// True iff `self` has no elements.
  var isEmpty: Bool { elementIDs.isEmpty }

  /// The IDs the elements of `self`.
  private var elementIDs: BitSet
}
