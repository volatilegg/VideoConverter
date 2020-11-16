import XCTest
@testable import VideoConverter

final class VideoConverterTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(VideoConverter().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
