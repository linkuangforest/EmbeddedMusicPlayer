//
//  ChatMusicController.swift
//  MusicPlayer
//
//  Created by Lin Kuang on 11/15/25.
//

import Foundation
import Dispatch

// MARK: - Chatbot Interaction Controller
class ChatMusicController {
    static let shared = ChatMusicController()
    weak var playerViewModel: MusicPlayerViewModel?

    func setup(viewModel: MusicPlayerViewModel) {
        self.playerViewModel = viewModel
    }

    func handleChatCommand(command: String, parameters: [String: Any]) {
        guard let viewModel = playerViewModel else {
            print("Player ViewModel not set up")
            return
        }

        DispatchQueue.main.async { // Ensure UI updates on main thread
            switch command {
            case "PLAY_LOCAL_LOST_FREQUCIES":
                self.playDefaultTrack()
            case "PLAY_SONG":
                 if let title = parameters["title"] as? String,
                   let artist = parameters["artist"] as? String,
                   let audioURLString = parameters["audioURL"] as? String,
                   let url = URL(string: audioURLString) {
                    let duration = parameters["duration"] as? Double ?? 0
                    let track = MusicTrack(title: title, artist: artist,
                                         albumArtURL: URL(string: parameters["albumArtURL"] as? String ?? ""),
                                         audioURL: url,
                                         duration: duration)
                    viewModel.loadPlaylist([track]) // Load as a single-item playlist
                } else {
                    print("Missing parameters for PLAY_SONG")
                }
            case "PAUSE": viewModel.pause()
            case "RESUME": viewModel.play()
            default:
                print("Unknown chat command: \(command)")
            }
        }
    }

    private func playDefaultTrack() {
        let fileName = "Black Friday (pretty like the sun) - Lost Frequencies"
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") else {
            print("ERROR: Local file \(fileName).mp3 not found in bundle.")
            return
        }
        let track = MusicTrack(
            title: "Black Friday (pretty like the sun)",
            artist: "Lost Frequencies, Tom Odells, Poppy Baskcomb",
            albumArtAssetName: "Washed_Out_-_Purple_Noon",
            audioURL: url,
            duration: 0
        )
        playerViewModel?.loadPlaylist([track]) // Load as a single-item playlist
    }
}
