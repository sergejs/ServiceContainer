@testable import ServiceContainer
import XCTest

// MARK: - Test Service Protocol and Implementations

protocol NetworkProviding {
    func fetchData() -> String
}

struct NetworkProvider: NetworkProviding {
    func fetchData() -> String {
        "Real Network Data"
    }
}

struct MockNetworkProvider: NetworkProviding {
    var mockData: String

    func fetchData() -> String {
        mockData
    }
}

// MARK: - InjectionKey Implementations

private struct NetworkProviderKey: InjectionKey {
    static var defaultValue: NetworkProviding { NetworkProvider() }
}

private struct OptionalServiceKey: InjectionKey {
    static var defaultValue: String? { nil }
}

// MARK: - Extend InjectedValues

extension InjectedValues {
    var networkProvider: NetworkProviding {
        get { Self[NetworkProviderKey.self] }
        set { Self[NetworkProviderKey.self] = newValue }
    }

    var optionalService: String? {
        get { Self[OptionalServiceKey.self] }
        set { Self[OptionalServiceKey.self] = newValue }
    }
}

// MARK: - Test Class Using @Injected

final class TestViewModel {
    @Injected(\.networkProvider) var networkProvider: NetworkProviding
    @Injected(\.optionalService) var optionalService: String?

    func getData() -> String {
        networkProvider.fetchData()
    }
}

// MARK: - Tests

final class ServiceContainerTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        // Reset all dependencies to defaults
        InjectedValues.resetAll()
    }

    func testInjectionKeyDefaultValue() {
        // Test that default value is provided
        let defaultProvider = InjectedValues[NetworkProviderKey.self]
        XCTAssertTrue(defaultProvider is NetworkProvider)
        XCTAssertEqual(defaultProvider.fetchData(), "Real Network Data")
    }

    func testInjectionKeyValueReplacement() {
        // Replace with mock for testing
        let mockProvider = MockNetworkProvider(mockData: "Mock Data")
        InjectedValues[NetworkProviderKey.self] = mockProvider

        let currentProvider = InjectedValues[NetworkProviderKey.self]
        XCTAssertTrue(currentProvider is MockNetworkProvider)
        XCTAssertEqual(currentProvider.fetchData(), "Mock Data")
    }

    func testInjectedPropertyWrapper() {
        // Set up mock
        let mockProvider = MockNetworkProvider(mockData: "Injected Mock Data")
        InjectedValues[NetworkProviderKey.self] = mockProvider

        // Create instance using @Injected
        let viewModel = TestViewModel()

        // Verify it uses the injected dependency
        XCTAssertEqual(viewModel.getData(), "Injected Mock Data")
        XCTAssertTrue(viewModel.networkProvider is MockNetworkProvider)
    }

    func testInjectedPropertyWrapperMutation() {
        let viewModel = TestViewModel()

        // Initial state
        XCTAssertEqual(viewModel.getData(), "Real Network Data")

        // Change the dependency
        let mockProvider = MockNetworkProvider(mockData: "Updated Mock Data")
        viewModel.networkProvider = mockProvider

        // Verify the change
        XCTAssertEqual(viewModel.getData(), "Updated Mock Data")
    }

    func testOptionalDependency() {
        let viewModel = TestViewModel()

        // Initial state should be nil
        XCTAssertNil(viewModel.optionalService)

        // Set a value
        InjectedValues[OptionalServiceKey.self] = "Optional Service Data"

        // Create new instance to get updated value
        let newViewModel = TestViewModel()
        XCTAssertEqual(newViewModel.optionalService, "Optional Service Data")
    }

    func testResolveMethod() {
        // Set up test data
        let mockProvider = MockNetworkProvider(mockData: "Resolved Data")
        InjectedValues[NetworkProviderKey.self] = mockProvider

        // Test resolve method
        let resolved = InjectedValues.resolve(\.networkProvider)
        XCTAssertTrue(resolved is MockNetworkProvider)
        XCTAssertEqual(resolved.fetchData(), "Resolved Data")
    }

    func testKeyPathSubscript() {
        // Test direct keypath subscript access
        InjectedValues[\.networkProvider] = MockNetworkProvider(mockData: "KeyPath Data")

        let provider = InjectedValues[\.networkProvider]
        XCTAssertTrue(provider is MockNetworkProvider)
        XCTAssertEqual(provider.fetchData(), "KeyPath Data")
    }
}