import XCTest
@testable import RSCore

final class RSCoreTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(RSCore().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
