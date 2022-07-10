@testable import Lotsawa

import XCTest

class DiscreteMapTests: XCTestCase {
  func test() {
    var x = DiscreteMap<Int8, UInt8>()
    x.appendMapping(from: -10, to: 1)
    XCTAssertEqual(x.points.count, 1)
    x.appendMapping(from: -9, to: 2)
    XCTAssertEqual(x.points.count, 1)
    x.appendMapping(from: 0, to: 3)
    XCTAssertEqual(x.points.count, 2)

    x.appendMapping(from: 1, to: 1)
    x.appendMapping(from: 100, to: 4)

    XCTAssertEqual(x[-10], 1)
    XCTAssertEqual(x[-9], 2)
    XCTAssertEqual(x[-8], 3)
    XCTAssertEqual(x[-7], 4)
    XCTAssertEqual(x[-6], 5)
    XCTAssertEqual(x[-5], 6)
    XCTAssertEqual(x[-4], 7)
    XCTAssertEqual(x[-3], 8)
    XCTAssertEqual(x[-2], 9)
    XCTAssertEqual(x[-1], 10)
    XCTAssertEqual(x[0], 3)
    XCTAssert((1..<100).allSatisfy { i in x[i] == i })
    XCTAssertEqual(x[100], 4)
    XCTAssertEqual(x[101], 5)
  }
}
