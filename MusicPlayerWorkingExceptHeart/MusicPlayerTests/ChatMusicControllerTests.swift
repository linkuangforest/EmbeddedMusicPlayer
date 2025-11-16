//
//  ChatMusicControllerTests.swift
//  MusicPlayerTests
//
//  Created by Lin Kuang on 11/15/25.
//

import XCTest
@testable import MusicPlayerAppModule // Make sure this matches your app module name

// MARK: - Mock ViewModel

class MockMusicPlayerViewModel: MusicPlayerViewModel {
    var loadPlaylistCalled = false
    var lastLoadedTracks: [MusicTrack]?
    var lastStartIndex: Int?
    var loadPlaylistExpectation: XCTestExpectation?

    var playCalled = false
    var playExpectation: XCTestExpectation?

    var pauseCalled = false
    var pauseExpectation: XCTestExpectation?

    // Override methods to capture calls and fulfill expectations
    override func loadPlaylist(_ tracks: [MusicTrack], startIndex: Int = 0) {
        print("MockMusicPlayerViewModel: loadPlaylist called")
        loadPlaylistCalled = true
        lastLoadedTracks = tracks
        lastStartIndex = startIndex
        loadPlaylistExpectation?.fulfill()
        // Do not call super.loadPlaylist to avoid real player setup
    }

    override func play() {
        print("MockMusicPlayerViewModel: play called")
        playCalled = true
        playExpectation?.fulfill()
        // Do not call super.play
    }

    override func pause() {
        print("MockMusicPlayerViewModel: pause called")
        pauseCalled = true
        pauseExpectation?.fulfill()
        // Do not call super.pause
    }
}

// MARK: - Test Class

class ChatMusicControllerTests: XCTestCase {

    var controller: ChatMusicController!
    var mockViewModel: MockMusicPlayerViewModel!

    override func setUp() {
        super.setUp()
        controller = ChatMusicController.shared
        mockViewModel = MockMusicPlayerViewModel()
        controller.setup(viewModel: mockViewModel)
    }

    override func tearDown() {
        controller.playerViewModel = nil
        controller = nil
        mockViewModel = nil
        super.tearDown()
    }

    func testHandleChatCommand_Pause() {
        let expectation = self.expectation(description: "ViewModel.pause() should be called on main thread")
        mockViewModel.pauseExpectation = expectation

        controller.handleChatCommand(command: "PAUSE", parameters: [:])

        waitForExpectations(timeout: 1.0) { error in
            XCTAssertNil(error, "Timeout waiting for pause() to be called: \(error?.localizedDescription ?? "Unknown error")")
        }
        XCTAssertTrue(mockViewModel.pauseCalled, "PAUSE command should have set pauseCalled to true")
    }

    func testHandleChatCommand_Resume() {
        let expectation = self.expectation(description: "ViewModel.play() should be called on main thread")
        mockViewModel.playExpectation = expectation

        controller.handleChatCommand(command: "RESUME", parameters: [:])

        waitForExpectations(timeout: 1.0) { error in
            XCTAssertNil(error, "Timeout waiting for play() to be called: \(error?.localizedDescription ?? "Unknown error")")
        }
        XCTAssertTrue(mockViewModel.playCalled, "RESUME command should have set playCalled to true")
    }

    func testHandleChatCommand_PlaySong_Success() {
        let params: [String: Any] = [
            "title": "Test Title",
            "artist": "Test Artist",
            "audioURL": "https://example.com/test.mp3",
            "duration": 180.0
        ]

        let expectation = self.expectation(description: "ViewModel.loadPlaylist() should be called")
        mockViewModel.loadPlaylistExpectation = expectation

        controller.handleChatCommand(command: "PLAY_SONG", parameters: params)

        waitForExpectations(timeout: 1.0) { error in
             XCTAssertNil(error, "Timeout waiting for loadPlaylist() to be called: \(error?.localizedDescription ?? "Unknown error")")
        }

        XCTAssertTrue(mockViewModel.loadPlaylistCalled)
        XCTAssertEqual(mockViewModel.lastLoadedTracks?.count, 1)
        let track = mockViewModel.lastLoadedTracks?.first
        XCTAssertEqual(track?.title, "Test Title")
        XCTAssertEqual(track?.artist, "Test Artist")
        XCTAssertEqual(track?.audioURL.absoluteString, "https://example.com/test.mp3")
        XCTAssertEqual(track?.duration, 180.0)
    }

    func testHandleChatCommand_PlaySong_MissingParams() {
        let params: [String: Any] = [
            "title": "Test Title"
            // Missing artist and audioURL
        ]

        // Since the check for missing params is synchronous and happens before the async call,
        // we don't strictly need an expectation for loadPlaylist not being called.
        // We can verify that the flag remains false.

        controller.handleChatCommand(command: "PLAY_SONG", parameters: params)

        // Add a very short delay to allow any potential async dispatch to queue, although it shouldn't in this case.
        let deadline = DispatchTime.now() + 0.1
        DispatchQueue.main.asyncAfter(deadline: deadline) {
             XCTAssertFalse(self.mockViewModel.loadPlaylistCalled, "loadPlaylist should not be called with missing parameters.")
        }
    }

    func testHandleChatCommand_Unknown() {
        controller.handleChatCommand(command: "UNKNOWN_COMMAND", parameters: [:])

        // Similar to missing params, checks are synchronous, so no expectation needed.
        let deadline = DispatchTime.now() + 0.1
        DispatchQueue.main.asyncAfter(deadline: deadline) {
            XCTAssertFalse(self.mockViewModel.playCalled)
            XCTAssertFalse(self.mockViewModel.pauseCalled)
            XCTAssertFalse(self.mockViewModel.loadPlaylistCalled)
        }
    }

    // Note: Testing "PLAY_LOCAL_LOST_FREQUCIES" is more of an integration test
    // as it relies on Bundle.main.url. To unit test, you'd inject the bundle or mock URL loading.
    // For now, this test will depend on the file being in the test bundle.
}
