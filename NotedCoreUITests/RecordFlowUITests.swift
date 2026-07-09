import XCTest

/// End-to-end proof that the offline pipeline works in the running app: tapping record then stop
/// runs capture → queue → (mock) transcribe/extract/note and an encounter appears on the shift list.
final class RecordFlowUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    func testRecordingProducesAnEncounter() {
        let app = XCUIApplication()
        app.launch()

        let mic = app.buttons["recordButton"]
        XCTAssertTrue(mic.waitForExistence(timeout: 15), "record button should be on screen")

        mic.tap()                               // start recording
        Thread.sleep(forTimeInterval: 1.2)
        mic.tap()                               // stop → pipeline runs

        // The generated encounter should show up in the list.
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 20),
                      "an encounter should appear on the shift list after recording")

        // Open it and confirm a note was generated (Sign appears only when a draft exists).
        firstCell.tap()
        let signButton = app.buttons["Sign"]
        XCTAssertTrue(signButton.waitForExistence(timeout: 20),
                      "a signable note should have been generated")
    }
}
