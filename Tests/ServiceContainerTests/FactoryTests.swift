@testable import ServiceContainer
import os.lock
import XCTest

// MARK: - Thread-Safe Counter Helper

private final class ThreadSafeCounter {
    private let lock = OSAllocatedUnfairLock(initialState: 0)

    func increment() {
        lock.withLock { $0 += 1 }
    }

    var value: Int {
        lock.withLock { $0 }
    }
}

// MARK: - Test Protocols and Implementations

/// Analytics protocol to test protocol-based factory injection
protocol AnalyticsProviding {
    func track(event: String)
    var trackingCalls: [String] { get }
}

/// Production implementation
class ProductionAnalytics: AnalyticsProviding {
    private(set) var trackingCalls: [String] = []

    func track(event: String) {
        trackingCalls.append(event)
        // In real app: send to analytics service
    }
}

/// Test/mock implementation
class MockAnalytics: AnalyticsProviding {
    private(set) var trackingCalls: [String] = []

    func track(event: String) {
        trackingCalls.append("MOCK: \(event)")
    }
}

/// Another protocol to test multiple protocol types
protocol DataProviding {
    func fetchData() -> String
}

class ProductionDataProvider: DataProviding {
    func fetchData() -> String {
        "Production Data"
    }
}

class MockDataProvider: DataProviding {
    func fetchData() -> String {
        "Mock Data"
    }
}

// MARK: - InjectionKey Implementations

private struct AnalyticsKey: InjectionKey {
    static var defaultValue: AnalyticsProviding {
        // Default implementation that should be replaced by factory
        MockAnalytics()
    }
}

private struct DataProviderKey: InjectionKey {
    static var defaultValue: DataProviding {
        MockDataProvider()
    }
}

private struct CounterKey: InjectionKey {
    static var defaultValue: Int { 0 }
}

private struct OptionalAnalyticsKey: InjectionKey {
    static var defaultValue: AnalyticsProviding? { nil }
}

// MARK: - Extend InjectedValues

extension InjectedValues {
    var analytics: AnalyticsProviding {
        get { Self[AnalyticsKey.self] }
        set { Self[AnalyticsKey.self] = newValue }
    }

    var dataProvider: DataProviding {
        get { Self[DataProviderKey.self] }
        set { Self[DataProviderKey.self] = newValue }
    }

    var counter: Int {
        get { Self[CounterKey.self] }
        set { Self[CounterKey.self] = newValue }
    }

    fileprivate var optionalAnalytics: AnalyticsProviding? {
        get { Self[OptionalAnalyticsKey.self] }
        set { Self[OptionalAnalyticsKey.self] = newValue }
    }
}

// MARK: - Factory Tests

final class FactoryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        InjectedValues.resetAll()
    }

    override func tearDown() {
        super.tearDown()
        InjectedValues.resetAll()
    }

    // MARK: - Production Pattern Tests

    func testProductionPattern_FactoryWithFatalErrorDefault() {
        class DummyAnalyticsThatCrashes: AnalyticsProviding {
            var trackingCalls: [String] { fatalError("Factory cast failed! Dummy was used instead of factory.") }
            func track(event: String) { fatalError("Factory cast failed! Dummy was used instead of factory.") }
        }

        struct ProductionAnalyticsKey: InjectionKey {
            static var defaultValue: AnalyticsProviding {
                DummyAnalyticsThatCrashes()
            }
        }

        InjectedValues.setFactory(ProductionAnalyticsKey.self) {
            ProductionAnalytics()
        }

        let analytics = InjectedValues[ProductionAnalyticsKey.self]
        analytics.track(event: "test_event")

        XCTAssertTrue(analytics is ProductionAnalytics, "Factory must return concrete implementation")
        XCTAssertEqual(analytics.trackingCalls, ["test_event"], "Factory implementation must be functional")
    }

    // MARK: - Protocol Casting Tests (Critical for verifying the claim)

    func testFactoryWithProtocolReturnType() {
        // This is the key test: Set a factory that returns a concrete type
        // but is typed as returning a protocol
        InjectedValues.setFactory(AnalyticsKey.self) {
            ProductionAnalytics()
        }

        // Access via the protocol type
        let analytics = InjectedValues[\.analytics]

        // Verify we got the production implementation
        XCTAssertTrue(analytics is ProductionAnalytics, "Should receive ProductionAnalytics instance")

        analytics.track(event: "test_event")
        XCTAssertEqual(analytics.trackingCalls, ["test_event"], "Should track events correctly")
    }

    func testMultipleProtocolFactories() {
        // Set factories for multiple protocol-based dependencies
        InjectedValues.setFactory(AnalyticsKey.self) {
            ProductionAnalytics()
        }

        InjectedValues.setFactory(DataProviderKey.self) {
            ProductionDataProvider()
        }

        // Access both
        let analytics = InjectedValues[\.analytics]
        let dataProvider = InjectedValues[\.dataProvider]

        // Verify both work correctly
        XCTAssertTrue(analytics is ProductionAnalytics)
        XCTAssertTrue(dataProvider is ProductionDataProvider)
        XCTAssertEqual(dataProvider.fetchData(), "Production Data")
    }

    func testFactoryCastSucceeds() {
        // Explicitly test that the cast from Any to () -> ProtocolType succeeds
        let factoryCallCount = ThreadSafeCounter()

        InjectedValues.setFactory(AnalyticsKey.self) {
            factoryCallCount.increment()
            return ProductionAnalytics()
        }

        // First access should call the factory
        let analytics1 = InjectedValues[\.analytics]
        XCTAssertEqual(factoryCallCount.value, 1, "Factory should be called on first access")
        XCTAssertTrue(analytics1 is ProductionAnalytics)

        // Second access should use cached value, not call factory again
        let analytics2 = InjectedValues[\.analytics]
        XCTAssertEqual(factoryCallCount.value, 1, "Factory should not be called again")
        XCTAssertTrue(analytics2 is ProductionAnalytics)
    }

    // MARK: - Factory Lifecycle Tests

    func testFactoryLazyInitialization() {
        let factoryCallCount = ThreadSafeCounter()

        InjectedValues.setFactory(AnalyticsKey.self) {
            factoryCallCount.increment()
            return ProductionAnalytics()
        }

        // Factory should not be called yet
        XCTAssertEqual(factoryCallCount.value, 0, "Factory should not be called until first access")

        // Access the dependency
        _ = InjectedValues[\.analytics]

        // Now factory should have been called
        XCTAssertEqual(factoryCallCount.value, 1, "Factory should be called on first access")
    }

    func testSetValueClearsFactory() {
        let factoryCallCount = ThreadSafeCounter()

        InjectedValues.setFactory(AnalyticsKey.self) {
            factoryCallCount.increment()
            return ProductionAnalytics()
        }

        // Set a value directly (should clear the factory)
        let mockAnalytics = MockAnalytics()
        InjectedValues[AnalyticsKey.self] = mockAnalytics

        // Access the dependency
        let analytics = InjectedValues[\.analytics]

        // Should get the manually set value, not call the factory
        XCTAssertEqual(factoryCallCount.value, 0, "Factory should not be called after setValue")
        XCTAssertTrue(analytics is MockAnalytics, "Should use the manually set value")
    }

    func testSetFactoryClearsValue() {
        // Set a value first
        let mockAnalytics = MockAnalytics()
        InjectedValues[AnalyticsKey.self] = mockAnalytics

        // Verify the value is set
        let analytics1 = InjectedValues[\.analytics]
        XCTAssertTrue(analytics1 is MockAnalytics)

        // Now set a factory (should clear the previous value)
        InjectedValues.setFactory(AnalyticsKey.self) {
            ProductionAnalytics()
        }

        // Access again - should use the factory, not the old value
        let analytics2 = InjectedValues[\.analytics]
        XCTAssertTrue(analytics2 is ProductionAnalytics, "Should use factory, not old value")
    }

    func testResetClearsBothValueAndFactory() {
        // Set a factory
        InjectedValues.setFactory(AnalyticsKey.self) {
            ProductionAnalytics()
        }

        // Access it to create the cached value
        let analytics1 = InjectedValues[\.analytics]
        XCTAssertTrue(analytics1 is ProductionAnalytics)

        // Reset the dependency
        InjectedValues.reset(key: AnalyticsKey.self)

        // Access again - should use defaultValue, not the factory
        let analytics2 = InjectedValues[\.analytics]
        XCTAssertTrue(analytics2 is MockAnalytics, "Should use defaultValue after reset")
    }

    // MARK: - Integration Tests

    func testFactoryWithPropertyWrapper() {
        class TestViewModel {
            @Injected(\.analytics) var analytics: AnalyticsProviding
        }

        // Set factory
        InjectedValues.setFactory(AnalyticsKey.self) {
            ProductionAnalytics()
        }

        // Create view model
        let viewModel = TestViewModel()

        // Verify it uses the factory
        XCTAssertTrue(viewModel.analytics is ProductionAnalytics)
        viewModel.analytics.track(event: "test")
        XCTAssertEqual(viewModel.analytics.trackingCalls, ["test"])
    }

    func testFactoryWithKeyPathAccess() {
        // Set factory
        InjectedValues.setFactory(AnalyticsKey.self) {
            ProductionAnalytics()
        }

        // Access via keypath
        let analytics = InjectedValues[\.analytics]

        XCTAssertTrue(analytics is ProductionAnalytics)
    }

    func testFactoryWithDirectKeyAccess() {
        // Set factory
        InjectedValues.setFactory(AnalyticsKey.self) {
            ProductionAnalytics()
        }

        // Access via key directly
        let analytics = InjectedValues[AnalyticsKey.self]

        XCTAssertTrue(analytics is ProductionAnalytics)
    }

    func testFactoryWithValueType() {
        let factoryCallCount = ThreadSafeCounter()

        InjectedValues.setFactory(CounterKey.self) {
            factoryCallCount.increment()
            return 42
        }

        // First access
        let counter1 = InjectedValues[\.counter]
        XCTAssertEqual(counter1, 42)
        XCTAssertEqual(factoryCallCount.value, 1)

        // Second access (should use cached value)
        let counter2 = InjectedValues[\.counter]
        XCTAssertEqual(counter2, 42)
        XCTAssertEqual(factoryCallCount.value, 1, "Factory should only be called once")
    }

    // MARK: - Thread Safety Tests

    func testFactoryThreadSafety() {
        let expectation = self.expectation(description: "Concurrent factory access")
        expectation.expectedFulfillmentCount = 20

        let factoryCallCount = ThreadSafeCounter()
        let queue = DispatchQueue(label: "test", attributes: .concurrent)

        // Set factory
        InjectedValues.setFactory(AnalyticsKey.self) {
            factoryCallCount.increment()
            return ProductionAnalytics()
        }

        // Try to access from multiple threads simultaneously
        for _ in 0..<20 {
            queue.async {
                _ = InjectedValues[\.analytics]
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 5) { error in
            XCTAssertNil(error)
            // Factory should only be called once despite concurrent access
            XCTAssertEqual(factoryCallCount.value, 1, "Factory should only be called once despite concurrent access")
        }
    }

    // MARK: - Edge Cases

    func testFactoryReturningNil() {
        InjectedValues.setFactory(OptionalAnalyticsKey.self) {
            return nil
        }

        let analytics = InjectedValues[\.optionalAnalytics]
        XCTAssertNil(analytics, "Should correctly handle nil from factory")
    }

    func testFactoryReturningDifferentConcreteTypes() {
        var useMock = false

        InjectedValues.setFactory(AnalyticsKey.self) {
            if useMock {
                return MockAnalytics()
            } else {
                return ProductionAnalytics()
            }
        }

        // First access - production
        let analytics1 = InjectedValues[\.analytics]
        XCTAssertTrue(analytics1 is ProductionAnalytics)

        // Reset and change flag
        InjectedValues.reset(key: AnalyticsKey.self)
        useMock = true

        // Factory was cleared by reset, so this will use defaultValue
        let analytics2 = InjectedValues[\.analytics]
        XCTAssertTrue(analytics2 is MockAnalytics, "Should use defaultValue after reset")

        // Set factory again
        InjectedValues.setFactory(AnalyticsKey.self) {
            if useMock {
                return MockAnalytics()
            } else {
                return ProductionAnalytics()
            }
        }

        // Now should use factory
        let analytics3 = InjectedValues[\.analytics]
        XCTAssertTrue(analytics3 is MockAnalytics, "Should use factory with mock")
    }
}
