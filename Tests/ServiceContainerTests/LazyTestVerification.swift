import XCTest

// Test to verify Swift's static lazy behavior
class ExpensiveObject {
    static var initCount = 0

    init() {
        ExpensiveObject.initCount += 1
        print("ExpensiveObject initialized! Count: \(ExpensiveObject.initCount)")
    }
}

struct TestKey {
    static var value = ExpensiveObject()
}

class LazyVerificationTests: XCTestCase {
    func testStaticIsLazy() {
        // Reset counter
        ExpensiveObject.initCount = 0

        // At this point, TestKey is defined but value should NOT be created yet
        XCTAssertEqual(ExpensiveObject.initCount, 0, "Static should not initialize until accessed")

        // Now access it
        _ = TestKey.value
        XCTAssertEqual(ExpensiveObject.initCount, 1, "Static should initialize on first access")

        // Access again
        _ = TestKey.value
        XCTAssertEqual(ExpensiveObject.initCount, 1, "Static should not initialize again")
    }
}