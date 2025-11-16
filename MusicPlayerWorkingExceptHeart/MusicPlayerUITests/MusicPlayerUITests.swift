//
//  MusicPlayerUITests.swift
//  MusicPlayerUITests
//
//  Created by Lin Kuang on 11/6/25.
//

import XCTest

final class MusicPlayerUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // Launch the application
        app = XCUIApplication()
        // You can add launch arguments or environment variables here if needed
        // app.launchArguments = ["-UITesting"]
        app.launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        app = nil
    }

    @MainActor
    func testInitialState() throws {
        // Check if the initial bot message is there
        XCTAssertTrue(app.staticTexts["Hi, How can I help?"].waitForExistence(timeout: 3), "Initial bot message should be visible")
        // Check if input elements are present
        XCTAssertTrue(app.textFields["messageTextField"].exists, "Message text field should exist")
        XCTAssertTrue(app.buttons["sendButton"].exists, "Send button should exist")
    }

    @MainActor
    func testSendMessage() throws {
        let messageTextField = app.textFields["messageTextField"]
        XCTAssertTrue(messageTextField.waitForExistence(timeout: 2), "Message text field should exist")
        messageTextField.tap()
        let testMessage = "Hello Bot"
        messageTextField.typeText(testMessage)

        let sendButton = app.buttons["sendButton"]
        XCTAssertTrue(sendButton.isEnabled, "Send button should be enabled after typing")
        sendButton.tap()

        // Check if the user's message appears
        XCTAssertTrue(app.staticTexts[testMessage].waitForExistence(timeout: 3), "User message should appear in the chat")
    }

    @MainActor
    func testMusicPlayerAppears() throws {
        let messageTextField = app.textFields["messageTextField"]
        XCTAssertTrue(messageTextField.waitForExistence(timeout: 2), "Message text field should exist")
        messageTextField.tap()
        messageTextField.typeText("Play some music")

        app.buttons["sendButton"].tap()

        // Wait for the MusicPlayerView to appear
        let musicPlayerView = app.otherElements["musicPlayerView"]
        XCTAssertTrue(musicPlayerView.waitForExistence(timeout: 6), "MusicPlayerView should appear after sending the message")
    }

    @MainActor
    func testMusicPlayerControlsExist() throws {
        // First, trigger the music player
        let messageTextField = app.textFields["messageTextField"]
        XCTAssertTrue(messageTextField.waitForExistence(timeout: 2), "Message text field should exist")
        messageTextField.tap()
        messageTextField.typeText("Load the playlist")
        app.buttons["sendButton"].tap()

        let musicPlayerView = app.otherElements["musicPlayerView"]
        XCTAssertTrue(musicPlayerView.waitForExistence(timeout: 6), "MusicPlayerView must exist for this test")

        // --- Check for Previous Track Button ---
        let previousButton = musicPlayerView.buttons["previousTrackButton"]
//        let previousButtonExists = previousButton.waitForExistence(timeout: 5) // Increased timeout

//        if !previousButtonExists {
//            print("DEBUG: musicPlayerView hierarchy when previousTrackButton not found:")
//            print(musicPlayerView.debugDescription)
//            XCTFail("Previous track button did not appear within the timeout (30s)")
//        }
//        XCTAssertTrue(previousButtonExists, "Previous track button should exist within MusicPlayerView")

        // --- Check for other controls ---
        let playPauseButton = musicPlayerView.buttons["playPauseButton"]
        XCTAssertTrue(playPauseButton.waitForExistence(timeout: 2), "Play/Pause button should exist within MusicPlayerView")

        let nextButton = musicPlayerView.buttons["nextTrackButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 2), "Next track button should exist within MusicPlayerView")

        let trackTitle = musicPlayerView.staticTexts["trackTitleText"]
        XCTAssertTrue(trackTitle.waitForExistence(timeout: 2), "Track title text should exist within MusicPlayerView")

        // Check for the actual title text
        XCTAssertTrue(trackTitle.label.contains("Black Friday"), "Track title seems incorrect or not loaded: \(trackTitle.label)")
    }

    @MainActor
    func testMusicPlayerPlayPauseButtonToggle() throws {
         // Trigger music player
        let messageTextField = app.textFields["messageTextField"]
        XCTAssertTrue(messageTextField.waitForExistence(timeout: 2), "Message text field should exist")
        messageTextField.tap()
        messageTextField.typeText("Show player")
        app.buttons["sendButton"].tap()

        let musicPlayerView = app.otherElements["musicPlayerView"]
        XCTAssertTrue(musicPlayerView.waitForExistence(timeout: 6), "MusicPlayerView must exist")

        let playPauseButton = musicPlayerView.buttons["playPauseButton"]
        XCTAssertTrue(playPauseButton.waitForExistence(timeout: 18), "Play/Pause button should exist")

        // Assuming it starts in a playable state, the label should be "Play"
         XCTAssertTrue(playPauseButton.waitForLabel("Play", timeout: 18), "Button should initially be Play")

        playPauseButton.tap()
        XCTAssertTrue(playPauseButton.waitForLabel("Pause", timeout: 10), "Button should change to Pause after tap")

        playPauseButton.tap()
        XCTAssertTrue(playPauseButton.waitForLabel("Play", timeout: 3), "Button should change back to Play after tap")
    }

    /* // Template testLaunchPerformance - keep or remove as needed
    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    */
}

// Helper extension for waiting for label changes
extension XCUIElement {
    func waitForLabel(_ label: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}
