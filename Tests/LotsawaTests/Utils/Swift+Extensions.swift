import XCTest

extension Collection {
  func checkedOnlyElement(
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath, line: UInt = #line) throws -> Element
  {
    XCTAssert(
      !self.isEmpty, message() + " Expected exactly one element in \(Array(self))",
      file: file, line: line)

    if self.isEmpty { throw UnexpectedlyEmpty() }
    XCTAssert(self.dropFirst().isEmpty, message(), file: file, line: line)
    return self.first!
  }
}

extension BinaryInteger {
  /// Returns a string representation where all digits are subscript numerals
  func subscriptingDigits() -> String {
    return String(
      "\(self)".lazy.map { c in
        if c.unicodeScalars.count != 1 { return c }
        let u = c.unicodeScalars.first!
        if u < "0" || u > "9" { return c }
        return Character(
          Unicode.Scalar(
            u.value - ("0" as UnicodeScalar).value + ("₀" as UnicodeScalar).value)!)
      })
  }
}
