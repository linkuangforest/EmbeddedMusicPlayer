//
//  MusicPlayerViewModelTests.swift
//  MusicPlayerTests
//
//  Created by Lin Kuang on 11/15/25.
//

import XCTest
import AVFoundation
@testable import MusicPlayerAppModule // Replace with your actual module name

class MusicPlayerViewModelTests: XCTestCase {

    var viewModel: MusicPlayerViewModel!
    var sampleTracks: [MusicPlayerAppModule.MusicTrack]!

    override func setUp() {
        super.setUp()
        viewModel = MusicPlayerViewModel()

        // Reset AppState favorites
        AppState.shared.favoriteIDs = []

        // Create some sample tracks
        let url1 = URL(fileURLWithPath: "test1.mp3")
        let url2 = URL(fileURLWithPath: "test2.mp3")
        let url3 = URL(string: "https://example.com/test3.mp3")!

        sampleTracks = [
            MusicTrack(title: "Track 1", artist: "Artist 1", audioURL: url1, duration: 180),
            MusicTrack(title: "Track 2", artist: "Artist 2", audioURL: url2, duration: 200),
            MusicTrack(title: "Track 3", artist: "Artist 3", audioURL: url3, duration: 220),
        ]
    }

    override func tearDown() {
        viewModel = nil
        sampleTracks = nil
        AppState.shared.favoriteIDs = []
        super.tearDown()
    }

    func testLoadPlaylist_Empty() {
        viewModel.loadPlaylist([])
        XCTAssertTrue(viewModel.playlist.isEmpty)
        XCTAssertNil(viewModel.currentTrackIndex)
        XCTAssertNil(viewModel.currentTrack)
    }

    func testLoadPlaylist_WithTracks() {
        viewModel.loadPlaylist(sampleTracks)
        XCTAssertEqual(viewModel.playlist.count, 3)
        XCTAssertEqual(viewModel.currentTrackIndex, 0)
        XCTAssertEqual(viewModel.currentTrack?.title, "Track 1")
    }

    func testLoadPlaylist_WithStartIndex() {
        viewModel.loadPlaylist(sampleTracks, startIndex: 1)
        XCTAssertEqual(viewModel.currentTrackIndex, 1)
        XCTAssertEqual(viewModel.currentTrack?.title, "Track 2")
    }

    func testLoadPlaylist_InvalidStartIndex() {
        viewModel.loadPlaylist(sampleTracks, startIndex: 5)
        XCTAssertEqual(viewModel.currentTrackIndex, 2, "Start index should be clamped to the last valid index.")

        viewModel.loadPlaylist(sampleTracks, startIndex: -1)
        XCTAssertEqual(viewModel.currentTrackIndex, 0, "Start index should be clamped to 0.")
    }

    func testLoadPlaylist_SyncsFavorites() {
        let track2Filename = sampleTracks[1].audioURL.lastPathComponent
        AppState.shared.favoriteIDs = [track2Filename]

        viewModel.loadPlaylist(sampleTracks)

        XCTAssertFalse(viewModel.playlist[0].isFavorited)
        XCTAssertTrue(viewModel.playlist[1].isFavorited)
        XCTAssertFalse(viewModel.playlist[2].isFavorited)
    }

    func testPlayPauseState() {
        // This test is limited as it doesn't mock AVPlayer.
        // It mainly checks the isPlaying state property on the ViewModel.
        viewModel.loadPlaylist([sampleTracks[0]])
        // Assuming the player doesn't become ready instantly in a test environment.
        viewModel.isPlaying = false // Set initial state

        viewModel.play()
        XCTAssertTrue(viewModel.isPlaying, "isPlaying should be true after play()")

        viewModel.pause()
        XCTAssertFalse(viewModel.isPlaying, "isPlaying should be false after pause()")
    }

    func testNextTrack() {
        viewModel.loadPlaylist(sampleTracks)
        XCTAssertEqual(viewModel.currentTrackIndex, 0)

        viewModel.nextTrack()
        XCTAssertEqual(viewModel.currentTrackIndex, 1)

        viewModel.nextTrack()
        XCTAssertEqual(viewModel.currentTrackIndex, 2)

        viewModel.nextTrack() // Wrap around
        XCTAssertEqual(viewModel.currentTrackIndex, 0)
    }

    func testPreviousTrack() {
        viewModel.loadPlaylist(sampleTracks, startIndex: 1)
        XCTAssertEqual(viewModel.currentTrackIndex, 1)

        viewModel.previousTrack()
        XCTAssertEqual(viewModel.currentTrackIndex, 0)

        viewModel.previousTrack() // Wrap around
        XCTAssertEqual(viewModel.currentTrackIndex, 2)
    }

    func testCycleRepeatMode() {
        XCTAssertEqual(viewModel.repeatMode, .off)
        viewModel.cycleRepeatMode()
        XCTAssertEqual(viewModel.repeatMode, .one)
        viewModel.cycleRepeatMode()
        XCTAssertEqual(viewModel.repeatMode, .all)
        viewModel.cycleRepeatMode()
        XCTAssertEqual(viewModel.repeatMode, .off)
    }

    func testToggleFavorite() {
        viewModel.loadPlaylist(sampleTracks)
        let track1Filename = sampleTracks[0].audioURL.lastPathComponent

        XCTAssertFalse(viewModel.currentTrack!.isFavorited)
        XCTAssertFalse(AppState.shared.favoriteIDs.contains(track1Filename))

        viewModel.toggleFavorite()
        XCTAssertTrue(viewModel.currentTrack!.isFavorited)
        XCTAssertTrue(AppState.shared.favoriteIDs.contains(track1Filename))

        viewModel.toggleFavorite()
        XCTAssertFalse(viewModel.currentTrack!.isFavorited)
        XCTAssertFalse(AppState.shared.favoriteIDs.contains(track1Filename))
    }
}
