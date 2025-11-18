//
//  ContentView.swift
//  MusicPlayer
//
//  Created by Lin Kuang on 11/15/25.
//

import SwiftUI

// MARK: - Dark Theme Color Palette
extension Color {
    static let DarkBackground = Color(hex: "#131314") //Grey
    // Other chat-specific colors can be removed if not used elsewhere
    // static let DarkBubbleUser = Color(hex: "#113252") // Blue
    // static let DarkBubbleOther = Color(hex: "#303030") // Greyish
    static let DarkText = Color(hex: "#f8f8f2") //White
    // static let DarkInputBackground = Color(hex: "#44475a") //Greyish
    // static let DarkButton = Color(hex: "#1f2126")  //Greyish
    // static let SendButtonText = Color(hex :"#92ccfb") //Light Blue
}

// MARK: - Content View
struct ContentView: View {
    @StateObject private var musicViewModel = MusicPlayerViewModel()

    var body: some View {
        ZStack {
            Color.DarkBackground.edgesIgnoringSafeArea(.all)

            MusicPlayerView(viewModel: musicViewModel)
                .frame(width: 480, height: 297)
                .accessibilityIdentifier("musicPlayerView")
        }
        .onAppear {
            // Assuming ChatMusicController is still needed to set up the MusicPlayerViewModel
            ChatMusicController.shared.setup(viewModel: musicViewModel)

            let tracks = self.loadBundleTracks()
            if !tracks.isEmpty {
                self.musicViewModel.loadPlaylist(tracks)
            } else {
                print(" ContentView: No tracks were loaded for the music player.")
            }
        }
    }

    // Function to load tracks from the bundle
    func loadBundleTracks() -> [MusicTrack] {
        var tracks: [MusicTrack] = []

        if let track1 = loadBundleTrack(title: "Black Friday (pretty like the sun)", artist: "Lost Frequencies, Tom Odell, Poppy Baskcomb", fileName: "Black Friday (pretty like the sun) - Lost Frequencies", albumArt: "Washed_Out_-_Purple_Noon") {
            tracks.append(track1)
        }
        if let track2 = loadBundleTrack(title: "Let It Be", artist: "The Beatles", fileName: "Let It Be") {
            tracks.append(track2)
        }
        if let track3 = loadBundleTrack(title: "To Get Better", artist: "Wasia Project", fileName: "To Get Better") {
            tracks.append(track3)
        }
        return tracks
    }

    func loadBundleTrack(title: String, artist: String, fileName: String, fileExtension: String = "mp3", albumArt: String? = nil) -> MusicTrack? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            print("ERROR: Local file \(fileName).\(fileExtension) not found in bundle.")
            return nil
        }
        return MusicTrack(title: title, artist: artist, albumArtAssetName: albumArt, audioURL: url, duration: 0)
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif

