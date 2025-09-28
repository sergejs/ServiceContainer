# ServiceContainer

[![Swift CI](https://github.com/sergejs/ServiceContainer/actions/workflows/swift.yml/badge.svg)](https://github.com/sergejs/ServiceContainer/actions/workflows/swift.yml)
[![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Linux-lightgrey.svg)](https://github.com/sergejs/ServiceContainer)

A lightweight, type-safe dependency injection container for Swift using property wrappers. Based on the pattern described in [this article](https://www.avanderlee.com/swift/dependency-injection/).

## Features

- ✅ **Lazy initialization** - Dependencies are only created when first accessed
- ✅ Compile-time safe dependency injection
- ✅ Property wrapper syntax with `@Injected`
- ✅ Easy mocking for tests
- ✅ Support for optional dependencies
- ✅ Thread-safe
- ✅ No external dependencies
- ✅ Minimal boilerplate

## Installation

### Swift Package Manager

Add this to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/sergejs/ServiceContainer.git", from: "1.0.0")
]
```

## Usage

### 1. Define Your Service Protocol

```swift
protocol NetworkService {
    func fetchUser(id: Int) async throws -> User
}

class APINetworkService: NetworkService {
    func fetchUser(id: Int) async throws -> User {
        // Real implementation
    }
}
```

### 2. Create an InjectionKey

```swift
private struct NetworkServiceKey: InjectionKey {
    // Now using computed property for true lazy initialization
    static var defaultValue: NetworkService {
        print("Creating NetworkService instance...")
        return APINetworkService()
    }
}
```

### 3. Extend InjectedValues

```swift
extension InjectedValues {
    var networkService: NetworkService {
        get { Self[NetworkServiceKey.self] }
        set { Self[NetworkServiceKey.self] = newValue }
    }
}
```

### 4. Use @Injected in Your Classes

```swift
class UserViewModel: ObservableObject {
    @Injected(\.networkService) private var networkService
    @Published var user: User?

    func loadUser(id: Int) async {
        do {
            user = try await networkService.fetchUser(id: id)
        } catch {
            print("Failed to load user: \(error)")
        }
    }
}
```

## Testing

Replace dependencies with mocks for testing:

```swift
class MockNetworkService: NetworkService {
    var mockUser = User(id: 1, name: "Test User")
    var shouldThrowError = false

    func fetchUser(id: Int) async throws -> User {
        if shouldThrowError {
            throw NetworkError.notFound
        }
        return mockUser
    }
}

class UserViewModelTests: XCTestCase {
    func testLoadUser() async {
        // Arrange
        let mockService = MockNetworkService()
        mockService.mockUser = User(id: 42, name: "Mocked")
        InjectedValues[NetworkServiceKey.self] = mockService

        // Act
        let viewModel = UserViewModel()
        await viewModel.loadUser(id: 42)

        // Assert
        XCTAssertEqual(viewModel.user?.name, "Mocked")
    }

    override func tearDown() {
        // Reset all dependencies to their defaults
        InjectedValues.resetAll()
        super.tearDown()
    }
}
```

## Advanced Usage

### Lazy Initialization

All dependencies are now lazily initialized by default. They're only created when first accessed:

```swift
private struct ExpensiveServiceKey: InjectionKey {
    static var defaultValue: ExpensiveService {
        // This will only be called on first access
        print("Creating expensive service...")
        return ExpensiveService()
    }
}

// Service is NOT created yet
let viewModel = ViewModel()

// Service is created on first access
viewModel.performAction() // triggers service creation
```

### Setting Dependencies Manually

Due to lazy initialization, when setting dependencies manually (e.g., for testing), use the Key type directly:

```swift
// ✅ Correct - won't trigger initialization
InjectedValues[NetworkServiceKey.self] = MockNetworkService()

// ❌ Avoid - will trigger lazy initialization before setting
InjectedValues[\.networkService] = MockNetworkService()
```

### Optional Dependencies

```swift
private struct AnalyticsServiceKey: InjectionKey {
    static var defaultValue: AnalyticsService? { nil }

extension InjectedValues {
    var analyticsService: AnalyticsService? {
        get { Self[AnalyticsServiceKey.self] }
        set { Self[AnalyticsServiceKey.self] = newValue }
    }
}

class ViewModel {
    @Injected(\.analyticsService) private var analytics

    func trackEvent() {
        analytics?.track("button_tapped") // Safe optional call
    }
}
```

### Multiple Environments

```swift
// AppDelegate or App init
#if DEBUG
    InjectedValues[NetworkServiceKey.self] = MockNetworkService()
#else
    // Production will use the lazy default
    // No need to set anything
#endif
```

### Reset Dependencies

Useful for testing to ensure clean state:

```swift
// Reset specific dependency
InjectedValues.reset(key: NetworkServiceKey.self)

// Reset all dependencies
InjectedValues.resetAll()
```

### Direct Access Without Property Wrapper

```swift
// Using subscript
let service = InjectedValues[\.networkService]

// Using resolve method
let resolved = InjectedValues.resolve(\.networkService)
```

## Platform Requirements

- iOS 13.0+
- macOS 10.15+
- tvOS 13.0+
- watchOS 6.0+
- Swift 5.5+

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.