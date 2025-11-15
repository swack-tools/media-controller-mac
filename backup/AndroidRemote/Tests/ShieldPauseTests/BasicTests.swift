import XCTest

/// Basic tests to verify the test infrastructure is working
/// These tests don't depend on any project code
final class BasicTests: XCTestCase {

    func testExample() {
        // This is a basic example test to verify testing works
        XCTAssertEqual(2 + 2, 4, "Basic math should work")
    }

    func testStringOperations() {
        let str = "Hello, World!"
        XCTAssertTrue(str.contains("World"))
        XCTAssertEqual(str.count, 13)
    }

    func testArrayOperations() {
        let numbers = [1, 2, 3, 4, 5]
        XCTAssertEqual(numbers.count, 5)
        XCTAssertEqual(numbers.first, 1)
        XCTAssertEqual(numbers.last, 5)
    }

    func testDictionaryOperations() {
        var dict = ["key": "value"]
        dict["new"] = "data"
        XCTAssertEqual(dict.count, 2)
        XCTAssertEqual(dict["key"], "value")
    }

    func testBooleanLogic() {
        XCTAssertTrue(true)
        XCTAssertFalse(false)
        XCTAssertTrue(true && true)
        XCTAssertFalse(true && false)
        XCTAssertTrue(true || false)
    }

    func testAsyncOperation() async throws {
        // Test async/await support
        let result = await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                continuation.resume(returning: 42)
            }
        }
        XCTAssertEqual(result, 42)
    }

    func testPerformance() {
        measure {
            // Test performance measurement
            _ = (0..<1000).map { $0 * 2 }
        }
    }

    func testThrowingFunction() {
        enum TestError: Error {
            case test
        }

        func throwingFunc() throws -> Int {
            throw TestError.test
        }

        XCTAssertThrowsError(try throwingFunc()) { error in
            XCTAssertTrue(error is TestError)
        }
    }
}
