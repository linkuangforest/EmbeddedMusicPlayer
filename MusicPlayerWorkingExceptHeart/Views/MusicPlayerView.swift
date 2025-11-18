//
//  MusicPlayerView.swift
//  MusicPlayer
//
//  Created by Lin Kuang on 11/15/25.
//

import SwiftUI
import UIKit // For UIFont

// MARK: - SwiftUI View
struct MusicPlayerView: View {
    @ObservedObject var viewModel: MusicPlayerViewModel

    // Colors & Styling
    let backgroundColor = Color(hex: "#2e3240")
    let primaryTextColor = Color(hex: "#FFFFFF")
    let secondaryTextColor = Color(hex: "#B3B3B3")
    let iconColor = Color(hex: "#FFFFFF")
    let accentColor = Color(hex: "#004a77")
    let defaultImageName = "Gemini_music_player_logo"

    // Fonts
    private let titleFont = Font.custom("GoogleSans-Medium", size: 24)
    private let titleUIFont = UIFont(name: "GoogleSans-Medium", size: 24) ?? UIFont.systemFont(ofSize: 24, weight: .medium)
    private let artistFont = Font.custom("GoogleSansText-Regular", size: 16)
    private let artistUIFont = UIFont(name: "GoogleSansText-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)

    var body: some View {
        if let track = viewModel.currentTrack {
            VStack(spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    Group {
                        if let assetName = track.albumArtAssetName {
                            Image(assetName)
                                .resizable().scaledToFill()
                        } else if let uiImage = track.extractedAlbumArt {
                            Image(uiImage: uiImage)
                                .resizable().scaledToFill()
                        } else if let imageURL = track.albumArtURL {
                            AsyncImage(url: imageURL) { image in image.resizable().scaledToFill() }
                            placeholder: { Image(defaultImageName).resizable().scaledToFill() }
                        } else {
                            Image(defaultImageName).resizable().scaledToFill()
                        }
                    }
                    .frame(width: 88, height: 88)
                    .background(Color.gray.opacity(0.1)).cornerRadius(8).clipped()
                    .accessibilityLabel("Album art")

                    VStack(alignment: .leading, spacing: 16) {
                        TapToMarqueeText(text: track.title, font: titleFont, uiFont: titleUIFont, color: primaryTextColor)
                            .id("title-\(track.id)")
                            .accessibilityIdentifier("trackTitleText")
                            .frame(height: 32)
                        TapToMarqueeText(text: track.artist, font: artistFont, uiFont: artistUIFont, color: primaryTextColor.opacity(0.5))
                            .id("artist-\(track.id)")
                            .accessibilityIdentifier("trackArtistText")
                            .frame(height: 24)
                    }
                }.frame(height: 88)

                VStack(spacing: 4) {
                    BufferedSlider(
                        value: $viewModel.currentTime,
                        bounds: 0...(track.duration > 0 ? track.duration : 1),
                        buffered: viewModel.bufferedTime,
                        onEditingChanged: { editing in
                            if editing {
                                viewModel.isUserScrubbing = true
                                viewModel.pauseTimeObserver()
                            } else {
                                viewModel.userDidEndScrubbing(to: viewModel.currentTime)
                            }
                        }
                    )
                    .environmentObject(viewModel)
                    .accessibilityLabel("Track progress")
                    .accessibilityValue("\(timeString(from: viewModel.currentTime)) of \(timeString(from: track.duration))")

                    HStack {
                        Text(timeString(from: viewModel.currentTime)).font(.caption).foregroundColor(secondaryTextColor).accessibilityHidden(true)
                        Spacer()
                        Text(timeString(from: track.duration)).font(.caption).foregroundColor(secondaryTextColor).accessibilityHidden(true)
                    }
                }
                .padding(.top, 16)

                 HStack {
                    Spacer()
                    ControlButton(systemName: viewModel.repeatMode == .one ? "repeat.1" : "repeat", size: 20, color: viewModel.repeatMode == .off ? iconColor : accentColor, accessibilityLabel: "Repeat mode: \(viewModel.repeatMode == .off ? "Off" : viewModel.repeatMode == .one ? "Repeat One" : "Repeat All")") { viewModel.cycleRepeatMode() }
                    Spacer()
                     Button(action: { viewModel.previousTrack() }) {
                             PreviousTrackIcon()
                                 .frame(width: 20, height: 20)
                                 .foregroundColor(iconColor)
                         }
                         .accessibilityLabel("Previous track")
                         .accessibilityIdentifier("previousTrackButton")
                    Spacer()
                     Button(action: { viewModel.isPlaying ? viewModel.pause() : viewModel.play() }) {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 72))
                            .frame(width: 72, height: 72)
                            .symbolRenderingMode(.palette).foregroundStyle(.white, accentColor)
                    }.accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
                         .accessibilityIdentifier("playPauseButton")
                    Spacer()
                     Button(action: { viewModel.nextTrack() }) {
                             NextTrackIcon()
                                 .frame(width: 20, height: 20)
                                 .foregroundColor(iconColor)
                         }
                         .accessibilityLabel("Next track")
                         .accessibilityIdentifier("nextTrackButton")
                    Spacer()
                     ControlButton(
                        systemName: track.isFavorited ? "heart.fill" : "heart",
                        size: 20,
//                        color: track.isFavorited ? accentColor : iconColor,
                        color: track.isFavorited ? iconColor : iconColor,
                        accessibilityLabel: track.isFavorited ? "Favorited" : "Not favorited"
                     ) {
                        viewModel.toggleFavorite()
                    }
                    Spacer()
                }
            }
            .padding(32).background(backgroundColor).cornerRadius(16).frame(maxWidth: 480)
        } else {
            Text("No track loaded").foregroundColor(primaryTextColor).padding().background(backgroundColor).cornerRadius(16)
        }
    }

    private func timeString(from timeInterval: TimeInterval) -> String {
        if timeInterval.isNaN || timeInterval.isInfinite { return "0:00" }
        let totalSeconds = Int(timeInterval)
        let seconds = totalSeconds % 60
        let minutes = totalSeconds / 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#if DEBUG
struct MusicPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = MusicPlayerViewModel()
         let sampleTrack = MusicTrack(
            title: "Black Friday (pretty like the sun)",
            artist: "Lost Frequencies, Tom Odell, Poppy Baskcomb",
            albumArtAssetName: "Washed_Out_-_Purple_Noon",
            audioURL: URL(fileURLWithPath: "Black Friday (pretty like the sun) - Lost Frequencies.mp3"), // Placeholder for preview
            duration: 145 // Example duration
            // No isLocal argument here
        )

        // Use loadPlaylist to set the track
        viewModel.loadPlaylist([sampleTrack])

        // Adjust other @Published properties as needed for the preview
        viewModel.currentTime = 90
        viewModel.isPlaying = true // Optional: Set to true if you want to preview the playing state

        return MusicPlayerView(viewModel: viewModel)
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.black)
    }
}
#endif
