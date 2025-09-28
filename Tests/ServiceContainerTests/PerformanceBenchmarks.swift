import XCTest
@testable import ServiceContainer

// MARK: - Mock Heavy Services for Benchmarking

private class HeavyService {
    let data: [Int]

    init() {
        // Simulate expensive initialization
        data = (0..<1000).map { _ in Int.random(in: 0..<1000) }
        Thread.sleep(forTimeInterval: 0.001) // Simulate 1ms of work
    }
}

private struct HeavyServiceKey: InjectionKey {
    static var defaultValue: HeavyService { HeavyService() }
}

private class EagerHeavyService {
    static let shared = HeavyService()
}

// MARK: - Performance Benchmarks

final class PerformanceBenchmarks: XCTestCase {

    override func setUp() {
        super.setUp()
        InjectedValues.resetAll()
    }

    override func tearDown() {
        super.tearDown()
        InjectedValues.resetAll()
    }

    // MARK: - Lazy vs Eager Initialization

    func testLazyInitializationPerformance() {
        // This test measures the time to define 100 lazy dependencies without accessing them
        measure {
            for i in 0..<100 {
                // These are just defined, not accessed - should be instant
                _ = defineService(index: i)
            }
        }
    }

    func testEagerInitializationPerformance() {
        // This test measures the time to create 100 eager dependencies
        measure {
            var services: [HeavyService] = []
            for _ in 0..<100 {
                services.append(HeavyService()) // Actually creates the service
            }
        }
    }

    // MARK: - Lock Performance Comparison

    func testConcurrentAccessPerformance() {
        // Test concurrent access performance with os_unfair_lock
        let queue = DispatchQueue(label: "test", attributes: .concurrent)
        let group = DispatchGroup()
        let iterations = 10000

        measure {
            for _ in 0..<iterations {
                group.enter()
                queue.async {
                    _ = InjectedValues[HeavyServiceKey.self]
                    group.leave()
                }
            }
            group.wait()
        }
    }

    // MARK: - Startup Time Simulation

    func testAppStartupWithLazyDependencies() {
        // Simulate app startup with 50 dependencies defined but only 5 accessed
        measure {
            // Define 50 services (should be instant)
            defineManyServices(count: 50)

            // Access only 5 services (simulating actual startup needs)
            for i in 0..<5 {
                accessService(index: i)
            }

            InjectedValues.resetAll()
        }
    }

    func testAppStartupWithEagerDependencies() {
        // Simulate app startup with 50 eager dependencies
        measure {
            var services: [HeavyService] = []
            // All 50 services are created immediately
            for _ in 0..<50 {
                services.append(HeavyService())
            }

            // Access only 5 services
            for i in 0..<5 {
                _ = services[i].data.count
            }
        }
    }

    // MARK: - Memory Usage Pattern

    func testMemoryEfficiencyWithLazyLoading() {
        // Define many services but only access a few
        defineManyServices(count: 100)

        // Only access 10% of services
        for i in 0..<10 {
            accessService(index: i)
        }

        // The other 90 services are never created, saving memory
        XCTAssertNotNil(InjectedValues[HeavyServiceKey.self])
    }

    // MARK: - Helper Methods

    private func defineService(index: Int) -> String {
        // Just returns a key, doesn't create the service
        return "Service_\(index)"
    }

    private func defineManyServices(count: Int) {
        for i in 0..<count {
            _ = defineService(index: i)
        }
    }

    private func accessService(index: Int) {
        // Actually accesses and creates the service
        _ = InjectedValues[HeavyServiceKey.self]
    }
}

// For up-to-date performance benchmark results, see `PerformanceBenchmarks.md` or the relevant section in the project README.