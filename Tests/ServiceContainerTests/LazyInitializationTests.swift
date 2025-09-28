@testable import ServiceContainer
import XCTest

// MARK: - Test Helpers for Lazy Verification

class ExpensiveService {
    static var initializationCount = 0
    let id: String

    init() {
        ExpensiveService.initializationCount += 1
        self.id = UUID().uuidString
    }
}

private struct ExpensiveServiceKey: InjectionKey {
    static var defaultValue: ExpensiveService {
        ExpensiveService()
    }
}

extension InjectedValues {
    var expensiveService: ExpensiveService {
        get { Self[ExpensiveServiceKey.self] }
        set { Self[ExpensiveServiceKey.self] = newValue }
    }
}

// MARK: - Lazy Initialization Tests

final class LazyInitializationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset everything before each test
        InjectedValues.resetAll()
        ExpensiveService.initializationCount = 0
    }

    override func tearDown() {
        super.tearDown()
        InjectedValues.resetAll()
    }

    // MARK: - Basic Lazy Initialization

    func testLazyInitialization() {
        // Service should not be initialized yet
        XCTAssertEqual(ExpensiveService.initializationCount, 0, "Service should not initialize until accessed")

        // First access should trigger initialization
        let service1 = InjectedValues[\.expensiveService]
        XCTAssertEqual(ExpensiveService.initializationCount, 1, "Service should initialize on first access")

        // Second access should return the same instance
        let service2 = InjectedValues[\.expensiveService]
        XCTAssertEqual(ExpensiveService.initializationCount, 1, "Service should not reinitialize")
        XCTAssertEqual(service1.id, service2.id, "Should return the same instance")
    }

    // MARK: - Reset Functionality

    func testResetAndReinitialize() {
        // First initialization
        let service1 = InjectedValues[\.expensiveService]
        let id1 = service1.id
        XCTAssertEqual(ExpensiveService.initializationCount, 1)

        // Reset the specific service
        InjectedValues.reset(key: ExpensiveServiceKey.self)

        // Should create a new instance after reset
        let service2 = InjectedValues[\.expensiveService]
        let id2 = service2.id
        XCTAssertEqual(ExpensiveService.initializationCount, 2, "Service should reinitialize after reset")
        XCTAssertNotEqual(id1, id2, "Should be a different instance after reset")
    }

    func testResetAll() {
        // Access multiple services
        _ = InjectedValues[\.expensiveService]
        _ = InjectedValues[\.networkProvider]
        XCTAssertEqual(ExpensiveService.initializationCount, 1)

        // Reset all
        InjectedValues.resetAll()

        // Should recreate when accessed again
        _ = InjectedValues[\.expensiveService]
        XCTAssertEqual(ExpensiveService.initializationCount, 2, "Service should reinitialize after resetAll")
    }

    // MARK: - Manual Override

    func testManualOverride() {
        // Service not initialized yet
        XCTAssertEqual(ExpensiveService.initializationCount, 0)

        // Manually set a value directly via the key
        let customService = ExpensiveService()
        XCTAssertEqual(ExpensiveService.initializationCount, 1, "Only the manual instance should be created")

        InjectedValues[ExpensiveServiceKey.self] = customService

        // The manually set instance should be used
        let retrieved = InjectedValues[\.expensiveService]
        XCTAssertEqual(retrieved.id, customService.id, "Should use manually set instance")

        // No additional instances should be created
        XCTAssertEqual(ExpensiveService.initializationCount, 1, "No additional instances should be created")
    }

    // MARK: - Property Wrapper Integration

    func testPropertyWrapperLazyAccess() {
        class TestClass {
            @Injected(\.expensiveService) var service: ExpensiveService
        }

        // Creating the class should not initialize the service
        XCTAssertEqual(ExpensiveService.initializationCount, 0)

        let testObject = TestClass()
        XCTAssertEqual(ExpensiveService.initializationCount, 0, "Service should not initialize until property is accessed")

        // Accessing the property should trigger initialization
        _ = testObject.service
        XCTAssertEqual(ExpensiveService.initializationCount, 1, "Service should initialize on property access")
    }

    // MARK: - Thread Safety

    func testThreadSafety() {
        let expectation = self.expectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 10

        let queue = DispatchQueue(label: "test", attributes: .concurrent)

        // Reset counter
        ExpensiveService.initializationCount = 0

        // Try to access from multiple threads simultaneously
        for _ in 0..<10 {
            queue.async {
                _ = InjectedValues[\.expensiveService]
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 5) { error in
            XCTAssertNil(error)
            // Should only initialize once despite concurrent access
            XCTAssertEqual(ExpensiveService.initializationCount, 1, "Service should only initialize once despite concurrent access")
        }
    }
}