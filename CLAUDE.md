# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ServiceContainer is a Swift package implementing modern dependency injection using property wrappers, based on the pattern described in [avanderlee.com's dependency injection article](https://www.avanderlee.com/swift/dependency-injection/).

## Build & Test Commands

```bash
# Build the package
swift build

# Run tests
swift test

# Build for release
swift build -c release

# Clean build artifacts
swift package clean

# Run a specific test
swift test --filter ServiceContainerTests.testInjectedPropertyWrapper
```

## Architecture

The implementation in `Sources/ServiceContainer/ServiceContainer.swift` provides a compile-time safe, lazy dependency injection system with the following components:

### 1. Lazy Storage
Thread-safe storage that creates dependencies only when first accessed. Dependencies are cached after creation. Uses `os_unfair_lock` for optimal performance (~15-20% faster than NSLock).

### 2. InjectionKey Protocol
Defines dependencies with lazy initialization:
```swift
protocol InjectionKey {
    associatedtype Value
    static var defaultValue: Value { get }  // Computed property for lazy init
}
```
**Important**: Use computed properties (with `{ get }`) not stored properties to ensure lazy initialization.

### 3. @Injected Property Wrapper
Provides clean syntax for dependency injection in classes:
```swift
@propertyWrapper
struct Injected<T> {
    private let keyPath: WritableKeyPath<InjectedValues, T>
    var wrappedValue: T {
        get { InjectedValues[keyPath] }
        set { InjectedValues[keyPath] = newValue }
    }
}
```

### 4. InjectedValues Registry
Central storage for all dependencies with static subscripts for access:
- `InjectedValues[KeyType.self]` - Access by InjectionKey type (use for setting to avoid triggering lazy init)
- `InjectedValues[\.keyPath]` - Access by keyPath (triggers lazy init on get)
- `InjectedValues.resolve(\.keyPath)` - Programmatic resolution
- `InjectedValues.reset(key:)` - Reset specific dependency
- `InjectedValues.resetAll()` - Reset all dependencies

## Testing Strategy

Tests demonstrate proper usage patterns:

1. **Define test dependencies**: Create protocols and concrete/mock implementations
2. **Create InjectionKeys**: Define keys with default values
3. **Extend InjectedValues**: Add computed properties for type-safe access
4. **Test scenarios**:
   - Default value provision
   - Dependency replacement for mocking
   - Property wrapper injection
   - Optional dependency handling
   - Direct and programmatic access

Example test setup:
```swift
// 1. Define protocol
protocol NetworkProviding {
    func fetchData() -> String
}

// 2. Create key with lazy initialization
struct NetworkProviderKey: InjectionKey {
    static var defaultValue: NetworkProviding { NetworkProvider() }
}

// 3. Extend InjectedValues
extension InjectedValues {
    var networkProvider: NetworkProviding {
        get { Self[NetworkProviderKey.self] }
        set { Self[NetworkProviderKey.self] = newValue }
    }
}

// 4. Use in tests (use Key type to avoid triggering lazy init)
InjectedValues[NetworkProviderKey.self] = MockNetworkProvider(mockData: "Test")
```

## Platform Requirements

- macOS 10.15+
- iOS 13.0+
- watchOS 6.0+
- tvOS 13.0+
- Swift 5.5+

## Key Implementation Patterns

When adding new dependencies:

1. **Create the InjectionKey**: Define a struct conforming to InjectionKey with a computed `defaultValue` property (not stored!)
2. **Extend InjectedValues**: Add a computed property for type-safe access
3. **Use @Injected**: Apply the property wrapper in your classes
4. **Mock in tests**: Replace dependencies using `InjectedValues[KeyType.self] = mock` to avoid triggering lazy initialization

### Lazy Initialization Benefits

- Dependencies are created only when first accessed
- Reduces app startup time
- Saves memory for unused dependencies
- Thread-safe implementation ensures single instance creation

### Important Notes

- Always use computed properties for `defaultValue` to ensure lazy behavior
- When setting mocks for tests, use `InjectedValues[KeyType.self]` not keyPath syntax
- Use `InjectedValues.resetAll()` in test tearDown for clean state
- Thread safety is handled internally - dependencies can be accessed from any thread

### Technical Note: Swift Static Lazy Behavior

Swift static properties are already lazy by default - they're initialized on first access. However, our implementation adds:
- Ability to reset dependencies (crucial for testing)
- Thread-safe storage with os_unfair_lock
- Consistent lazy behavior across all dependency types
- Proper cleanup and memory management