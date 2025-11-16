//
//  AppStateTests.swift
//  MusicPlayerTests
//
//  Created by Lin Kuang on 11/15/25.
//

import XCTest
@testable import MusicPlayerAppModule // Replace with your actual module name

class AppStateTests: XCTestCase {

    var appState: AppState!
    let userDefaultsKey = "favorites_list" // Match the key in AppState

    override func setUp() {
        super.setUp()
        appState = AppState.shared
        // Ensure a clean state before each test
        appState.clearUserDefaults()
        appState.loadFromUserDefaults()
    }

    override func tearDown() {
        // Clean up after each test
        appState.clearUserDefaults()
        appState = nil
        super.tearDown()
    }

    func testAppStateInitialization_Empty() {
        // setUp ensures UserDefaults is clear and appState is loaded from it.
        XCTAssertTrue(appState.favoriteIDs.isEmpty, "favoriteIDs should be empty on init with no UserDefaults data.")
    }

    func testAppStateInitialization_WithUserDefaultsData() {
        let testIDs = ["track1.mp3", "track2.mp3"]
        UserDefaults.standard.set(testIDs, forKey: userDefaultsKey)

        // Force AppState to reload from the modified UserDefaults
        appState.loadFromUserDefaults()

        XCTAssertEqual(appState.favoriteIDs, testIDs, "AppState should load favoriteIDs from UserDefaults.")
    }

    func testAddFavoritePersists() {
        let trackID = "test1.mp3"

        appState.favoriteIDs.append(trackID)

        XCTAssertEqual(appState.favoriteIDs, [trackID])
        XCTAssertEqual(UserDefaults.standard.stringArray(forKey: userDefaultsKey), [trackID], "Adding to favoriteIDs should update UserDefaults.")

        // Verify re-loading persists
        let anotherAppStateInstance = AppState.shared // Should be the same instance
        anotherAppStateInstance.loadFromUserDefaults()
        XCTAssertEqual(anotherAppStateInstance.favoriteIDs, [trackID], "State should persist in UserDefaults on reload.")
    }

    func testRemoveFavoritePersists() {
        let testIDs = ["track1.mp3", "track2.mp3"]
        UserDefaults.standard.set(testIDs, forKey: userDefaultsKey)
        appState.loadFromUserDefaults() // Load initial state

        appState.favoriteIDs.removeAll { $0 == "track1.mp3" }

        XCTAssertEqual(appState.favoriteIDs, ["track2.mp3"])
        XCTAssertEqual(UserDefaults.standard.stringArray(forKey: userDefaultsKey), ["track2.mp3"], "Removing from favoriteIDs should update UserDefaults.")

        // Verify re-loading persists
        appState.loadFromUserDefaults()
        XCTAssertEqual(appState.favoriteIDs, ["track2.mp3"], "Removal should persist in UserDefaults on reload.")
    }
}
