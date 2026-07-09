import XCTest
@testable import NotedCoreKit

final class AudioRoutePolicyTests: XCTestCase {

    private let builtIn = AudioInputOption(name: "iPhone Microphone", kind: .builtIn)
    private let bt = AudioInputOption(name: "AirPods Pro", kind: .bluetooth)
    private let wired = AudioInputOption(name: "USB-C Mic", kind: .wired)

    func testBluetoothWinsOverBuiltIn() {
        XCTAssertEqual(AudioRoutePolicy.preferred(from: [builtIn, bt]), bt)
    }

    func testWiredWinsOverBuiltInButLosesToBluetooth() {
        XCTAssertEqual(AudioRoutePolicy.preferred(from: [builtIn, wired]), wired)
        XCTAssertEqual(AudioRoutePolicy.preferred(from: [builtIn, wired, bt]), bt)
    }

    func testBuiltInWhenAlone() {
        XCTAssertEqual(AudioRoutePolicy.preferred(from: [builtIn]), builtIn)
    }

    func testNilWhenNoInputs() {
        XCTAssertNil(AudioRoutePolicy.preferred(from: []))
    }

    func testManualPreferenceHonoredWhenAvailable() {
        // Clinician explicitly chose the built-in mic even though BT is present.
        XCTAssertEqual(AudioRoutePolicy.preferred(from: [builtIn, bt], manual: builtIn), builtIn)
    }

    func testManualPreferenceIgnoredWhenGone() {
        // The chosen BT mic disconnected — fall back to the ranked default.
        XCTAssertEqual(AudioRoutePolicy.preferred(from: [builtIn], manual: bt), builtIn)
    }

    func testHasBluetooth() {
        XCTAssertTrue(AudioRoutePolicy.hasBluetooth([builtIn, bt]))
        XCTAssertFalse(AudioRoutePolicy.hasBluetooth([builtIn, wired]))
    }
}
