@testable import ServiceContainer
import XCTest

final class ServiceContainerTests: XCTestCase {
    typealias StorageType = [String: Data]
    var sut: ServiceContainable = ServiceContainer.shared

    func testSuccess() {
        (sut as? ServiceContainer)?.components.removeAll()

        var stotorage = StorageType()
        let data = "String".data(using: .utf8)!
        stotorage["key"] = data

        sut.register(type: StorageType.self, component: stotorage)

        let storable = sut.resolve(type: StorageType.self)
        XCTAssertEqual(storable, storable)
    }

    func testFail() {
        (sut as? ServiceContainer)?.components.removeAll()

        let storable = sut.resolve(type: StorageType.self)
        XCTAssertNil(storable)
    }

    func testRemoveAll() {
        (sut as? ServiceContainer)?.components.removeAll()

        let stotorage = StorageType()
        sut.register(type: StorageType.self, component: stotorage)
        XCTAssertEqual((sut as? ServiceContainer)?.components.count, 1)
        (sut as? ServiceContainer)?.components.removeAll()
        XCTAssertEqual((sut as? ServiceContainer)?.components.count, 0)
    }
}
