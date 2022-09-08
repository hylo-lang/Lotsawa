@testable import Lotsawa
import XCTest

class BitsTests : XCTestCase {

  func testOneByte() {
    let oneByte = Bits(base: [UInt8(0b101)]);
    XCTAssert(oneByte.elementsEqual([true, false, true, false, false, false, false, false]))
  }

  func testAlternatingBits() {
    // REVISIT(demarco) How can I produce a compile time error on non-64 bit platforms?
    let alternatingBitSequence = Bits(base: [0b0101010101010101010101010101010101010101010101010101010101010101,
                                             0b0101010101010101010101010101010101010101010101010101010101010101])
    var flag = true
    for bit in alternatingBitSequence {
      XCTAssert(bit == flag)
      flag = !flag
    }
  }

  /// Ensures `drop` works as expected, dropping bits and not underlying integers.
  func testDrop() {
    let oneByte = Bits(base: [0b10]);
    let dropped = oneByte.dropFirst()
    XCTAssert(dropped.first == true);
  }
}

class BitSetTests : XCTestCase {}
