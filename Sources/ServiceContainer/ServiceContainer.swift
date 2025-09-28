//
//  ServiceContainer.swift
//
//
//  Created by Sergejs Smirnovs on 09.11.21.
//

import Foundation

// MARK: - Lazy Storage Implementation

/// Thread-safe lazy storage for dependency values
private final class LazyStore {
    private var storage: [String: Any] = [:]
    private var factories: [String: Any] = [:]
    private let lock = NSLock()

    func getValue<T>(for key: String, factory: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }

        if let existing = storage[key] as? T {
            return existing
        }

        let value = factory()
        storage[key] = value
        return value
    }

    func setValue<T>(_ value: T, for key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = value
    }

    func reset(key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }

    func resetAll() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }
}

private let lazyStore = LazyStore()

// MARK: - InjectionKey Protocol

public protocol InjectionKey {
    associatedtype Value

    /// The default value factory. Override this to provide lazy initialization.
    static var defaultValue: Value { get }
}

// Default implementation that makes it backward compatible
public extension InjectionKey {
    static var currentValue: Value {
        get {
            let key = String(reflecting: Self.self)
            return lazyStore.getValue(for: key) {
                Self.defaultValue
            }
        }
        set {
            let key = String(reflecting: Self.self)
            lazyStore.setValue(newValue, for: key)
        }
    }
}

// MARK: - Property Wrapper

@propertyWrapper
public struct Injected<T> {
    private let keyPath: WritableKeyPath<InjectedValues, T>
    public var wrappedValue: T {
        get { InjectedValues[keyPath] }
        set { InjectedValues[keyPath] = newValue }
    }

    public init(_ keyPath: WritableKeyPath<InjectedValues, T>) {
        self.keyPath = keyPath
    }
}

// MARK: - InjectedValues Registry

public struct InjectedValues {
    private static var current = InjectedValues()

    /// A static subscript for updating the `currentValue` of `InjectionKey` instances.
    public static subscript<K>(key: K.Type) -> K.Value where K: InjectionKey {
        get { key.currentValue }
        set { key.currentValue = newValue }
    }

    /// A static subscript accessor for updating and references dependencies directly.
    public static subscript<T>(_ keyPath: WritableKeyPath<InjectedValues, T>) -> T {
        get { current[keyPath: keyPath] }
        set { current[keyPath: keyPath] = newValue }
    }

    public static func resolve<T>(_ keyPath: WritableKeyPath<InjectedValues, T>) -> T {
        current[keyPath: keyPath]
    }

    /// Reset a specific dependency to force re-creation on next access
    public static func reset<K>(key: K.Type) where K: InjectionKey {
        let keyString = String(reflecting: K.self)
        lazyStore.reset(key: keyString)
    }

    /// Reset all dependencies (useful for testing)
    public static func resetAll() {
        lazyStore.resetAll()
    }
}
