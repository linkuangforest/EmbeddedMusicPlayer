import SwiftUI
import AVFoundation
import UIKit

/*extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0) // Invalid hex, defaults to clear
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}*/

// MARK: - TapToMarqueeText View
struct TapToMarqueeText: View {
    let text: String
    let font: Font
    let uiFont: UIFont
    let color: Color
    let tabWidth: CGFloat = 20
    let baseSpeed: CGFloat = 60.0 // Points per second for marquee

    @State private var showMarquee = false
    @State private var animationOffset: CGFloat = 0

    private var textWidth: CGFloat {
        let attributes = [NSAttributedString.Key.font: uiFont]
        return (text as NSString).size(withAttributes: attributes).width
    }

    var body: some View {
        GeometryReader { geometry in
            let containerWidth = geometry.size.width
            let shouldMarquee = textWidth > containerWidth

            if shouldMarquee {
                ZStack(alignment: .leading) {
                    if showMarquee {
                        let animationDistance = -(textWidth + tabWidth)
                        HStack(spacing: 0) {
                            Text(text).font(font).foregroundColor(color).lineLimit(1)
                            Spacer().frame(width: tabWidth)
                            Text(text).font(font).foregroundColor(color).lineLimit(1)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .offset(x: animationOffset)
                        .onAppear {
                            startAnimation(animationDistance: animationDistance)
                        }
                    } else {
                        Text(text)
                            .font(font)
                            .foregroundColor(color)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .contentShape(Rectangle()) // Make the whole area tappable
                .onTapGesture {
                    if !showMarquee {
                        self.showMarquee = true
                    }
                }
                .accessibilityLabel(text)
                .accessibilityHint("Double tap to scroll text")
            } else {
                Text(text)
                    .font(font)
                    .foregroundColor(color)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(text)
            }
        }
        .frame(height: uiFont.lineHeight)
        .clipped()
    }

    private func startAnimation(animationDistance: CGFloat) {
        let dynamicDuration = Double(abs(animationDistance) / baseSpeed)
        self.animationOffset = 0 // Ensure starting position

        DispatchQueue.main.async {
            withAnimation(Animation.linear(duration: dynamicDuration).delay(0.2)) {
                self.animationOffset = animationDistance
            } completion: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.showMarquee = false
                    self.animationOffset = 0 // Reset offset
                }
            }
        }
    }
}

// MARK: - Data Model
struct MusicTrack: Identifiable {
    let id = UUID()
    var title: String
    var artist: String
    var albumArtURL: URL?
    var albumArtAssetName: String?
    var extractedAlbumArt: UIImage? = nil
    var audioURL: URL
    var duration: TimeInterval
    var isLocal: Bool { audioURL.isFileURL }
    var isFavorited: Bool = false
}

// MARK: - AVURLAsset Extension
extension AVURLAsset {
    func extractAlbumArt() async -> UIImage? {
        do {
            let metadata = try await self.load(.commonMetadata)

            if let artItem = metadata.first(where: { $0.commonKey?.rawValue == AVMetadataKey.commonKeyArtwork.rawValue }) {
                if let data = try await artItem.load(.dataValue) {
                    return UIImage(data: data)
                }
            }

            let id3Metadata = try await self.loadMetadata(for: .id3Metadata)
            if let artItem = id3Metadata.first(where: { $0.identifier?.rawValue == "APIC" }) {
                 if let data = try await artItem.load(.dataValue) {
                    return UIImage(data: data)
                }
            }
        } catch {
            print("Error loading metadata for album art: \(error)")
        }
        return nil
    }
}

// MARK: - ViewModel
class MusicPlayerViewModel: NSObject, ObservableObject {
    @Published var playlist: [MusicTrack] = []
    @Published var currentTrackIndex: Int? = nil
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var bufferedTime: TimeInterval = 0
    @Published var isUserScrubbing: Bool = false

    enum RepeatMode { case off, one, all }
    @Published var repeatMode: RepeatMode = .off

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserverToken: Any?
    private var isTimeObserverPaused = false
    private var ignoreNextEndTimeNotification = false

    var currentTrack: MusicTrack? {
        guard let index = currentTrackIndex, index >= 0 && index < playlist.count else {
            return nil
        }
        return playlist[index]
    }
    
    // MARK: - Playlist Loading (Fixed for Persistence)
    func loadPlaylist(_ tracks: [MusicTrack], startIndex: Int = 0) {
        guard !tracks.isEmpty else {
            resetPlayer()
            self.playlist = []
            return
        }
        
        var syncedTracks = tracks
        
        // SYNC: Check persistent store using the FILENAME, not the full path
        for index in 0..<syncedTracks.count {
            let filename = syncedTracks[index].audioURL.lastPathComponent
            if AppState.shared.favoriteIDs.contains(filename) {
                syncedTracks[index].isFavorited = true
            }
        }
        
        self.playlist = syncedTracks
        let validStartIndex = max(0, min(startIndex, tracks.count - 1))
        loadAndPlayTrack(at: validStartIndex, autoplay: true)
    }

    private func loadAndPlayTrack(at index: Int, autoplay: Bool = true) {
        guard index >= 0 && index < playlist.count else { return }

        self.currentTrackIndex = index
        let track = playlist[index]
        self.isPlaying = false
        self.currentTime = 0
        self.bufferedTime = 0

        if track.albumArtAssetName == nil && track.albumArtURL == nil && track.extractedAlbumArt == nil {
            let audioURL = track.audioURL
            Task {
                let asset = AVURLAsset(url: audioURL)
                let image = await asset.extractAlbumArt()
                await MainActor.run { [weak self] in
                    guard let self = self, self.currentTrackIndex == index else { return }
                    if let image = image {
                        self.playlist[index].extractedAlbumArt = image
                    }
                }
            }
        }

        preparePlayer(with: track.audioURL) { [weak self] duration in
            guard let self = self, self.currentTrackIndex == index else { return }

            if self.playlist[index].duration == 0 || self.playlist[index].duration.isNaN {
                var mutableTrack = self.playlist[index]
                mutableTrack.duration = duration
                self.playlist[index] = mutableTrack
            }
             // Initial buffer update for local files
            if self.playlist[index].isLocal {
                self.updateBufferTime()
            }
        }
    }

    private func preparePlayer(with url: URL, completion: @escaping (TimeInterval) -> Void) {
        removeObservers()
        player?.pause()
        player = nil
        playerItem = nil
        bufferedTime = 0

        let asset = AVURLAsset(url: url)
        playerItem = AVPlayerItem(asset: asset)

        playerItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.new, .initial], context: nil)
        playerItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges), options: [.new], context: nil)

        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true

        Task {
            do {
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                await MainActor.run {
                    completion(durationSeconds.isNaN ? 0 : durationSeconds)
                }
            } catch {
                print("Failed to load asset duration: \(error)")
                await MainActor.run { completion(0) }
            }
        }
    }

    // MARK: - Audio Playback Controls
    func play() {
        guard let player = player, player.currentItem != nil else {
            print("ViewModel: Player not ready for play")
            return
        }
        if player.timeControlStatus != .playing {
            player.play()
        }
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func userDidEndScrubbing(to time: TimeInterval) {
        self.isUserScrubbing = false
         guard let player = player, self.playerItem != nil, let trackDuration = currentTrack?.duration, trackDuration > 0 else {
            resumeTimeObserver()
            return
        }

        let newTime = max(0, min(time, trackDuration))
        let cmTime = CMTime(seconds: newTime, preferredTimescale: 600)

        if trackDuration > 0 && trackDuration - newTime < 0.5 {
            self.ignoreNextEndTimeNotification = true
        }

        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard let self = self else { return }
            self.resumeTimeObserver()
            if self.currentTrack?.isLocal == true {
                 self.updateBufferTime()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.ignoreNextEndTimeNotification = false
            }
        }
    }

    // MARK: - Observers
    override init() {
        super.init()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }

    func pauseTimeObserver() {
        if !isTimeObserverPaused {
            isTimeObserverPaused = true
            removePeriodicTimeObserver()
        }
    }

    func resumeTimeObserver() {
        if isTimeObserverPaused {
            isTimeObserverPaused = false
            addPeriodicTimeObserver()
        }
    }

    private func addPeriodicTimeObserver() {
        guard let player = player, timeObserverToken == nil else { return }
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, !self.isUserScrubbing else { return }
            self.currentTime = CMTimeGetSeconds(time)
            if self.currentTrack?.isLocal == true {
                 self.updateBufferTime()
            }
        }
    }

    private func removePeriodicTimeObserver() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    private func setupEndTimeObserver() {
        guard let playerItem = playerItem else { return }
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            if self.ignoreNextEndTimeNotification { self.ignoreNextEndTimeNotification = false; return }
            if self.isUserScrubbing { return }
            self.handleTrackCompletion()
        }
    }

    private func handleTrackCompletion() {
        switch self.repeatMode {
        case .one:
            self.player?.seek(to: .zero) { [weak self] _ in self?.play() }
        case .all:
            self.playNextTrack(loop: true)
        case .off:
            self.playNextTrack(loop: false)
        }
    }

    private func playNextTrack(loop: Bool) {
        guard let currentIndex = currentTrackIndex else { isPlaying = false; return }
        let nextIndex = currentIndex + 1
        if nextIndex < playlist.count {
            loadAndPlayTrack(at: nextIndex)
        } else if loop {
            loadAndPlayTrack(at: 0)
        } else {
            player?.seek(to: .zero)
            currentTime = 0
            isPlaying = false
        }
    }

    private func removeObservers() {
        removePeriodicTimeObserver()
         if let item = playerItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
             item.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), context: nil)
             item.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges), context: nil)
        }
    }

    private func resetPlayer() {
        removeObservers()
        player?.pause()
        player = nil
        playerItem = nil
        isPlaying = false
        currentTime = 0
        bufferedTime = 0
    }

    deinit {
        resetPlayer()
    }

    // MARK: - Buffer Time Update
    private func updateBufferTime() {
        guard let track = currentTrack else {
            bufferedTime = 0
            return
        }

        let trackDuration = track.duration
        if track.isLocal {
            // Simulate buffer 8 seconds ahead for local files
            bufferedTime = min(currentTime + 15.0, trackDuration)
        } else {
            // Actual buffer for remote files
            guard let playerItem = playerItem else {
                bufferedTime = currentTime
                return
            }
            let timeRanges = playerItem.loadedTimeRanges
            if let timeRange = timeRanges.first?.timeRangeValue {
                let startSeconds = CMTimeGetSeconds(timeRange.start)
                let durationSeconds = CMTimeGetSeconds(timeRange.duration)
                bufferedTime = min(startSeconds + durationSeconds, trackDuration)
            } else {
                bufferedTime = currentTime
            }
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue) ?? .unknown
            } else { status = .unknown }

            DispatchQueue.main.async { [weak self] in
                guard let self = self, let item = object as? AVPlayerItem, item == self.playerItem else { return }
                switch status {
                case .readyToPlay:
                    if self.currentTrack?.duration == 0 || self.currentTrack?.duration.isNaN == true,
                       let itemDuration = self.playerItem?.duration, !CMTimeGetSeconds(itemDuration).isNaN {
                         let durationSeconds = CMTimeGetSeconds(itemDuration)
                         if let index = self.currentTrackIndex {
                            var mutableTrack = self.playlist[index]
                            mutableTrack.duration = durationSeconds
                            self.playlist[index] = mutableTrack
                         }
                    }
                    self.addPeriodicTimeObserver()
                    self.setupEndTimeObserver()
                    self.updateBufferTime() // Initial buffer update
                    self.play()
                case .failed:
                    print("PlayerItem failed: \(self.playerItem?.error?.localizedDescription ?? "Unknown error")")
                    self.isPlaying = false
                case .unknown:
                    print("PlayerItem status unknown")
                @unknown default: break
                }
            }
        } else if keyPath == #keyPath(AVPlayerItem.loadedTimeRanges) {
            DispatchQueue.main.async { [weak self] in
                self?.updateBufferTime()
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    // MARK: - Navigation Controls
    func nextTrack() {
        guard !playlist.isEmpty else { return }
        let currentIndex = currentTrackIndex ?? -1
        let nextIndex = (currentIndex + 1) % playlist.count
        loadAndPlayTrack(at: nextIndex)
    }

    func previousTrack() {
        guard !playlist.isEmpty else { return }
        let currentIndex = currentTrackIndex ?? 0
        let prevIndex = (currentIndex - 1 + playlist.count) % playlist.count
        loadAndPlayTrack(at: prevIndex)
    }

    // MARK: - Favorite Control
   // func toggleFavorite() {
     //   guard let index = currentTrackIndex else { return }
       // playlist[index].isFavorited.toggle()
        //print("ViewModel: Toggled favorite for track \(playlist[index].title) to \(playlist[index].isFavorited)")
    //}
    
    // MARK: - Favorite Control (Fixed for Persistence)
    func toggleFavorite() {
        guard let index = currentTrackIndex else { return }
        
        // 1. Update UI instantly
        playlist[index].isFavorited.toggle()
        
        // 2. Update Storage using FILENAME
        let filename = playlist[index].audioURL.lastPathComponent
        
        if playlist[index].isFavorited {
            // Add if not present
            if !AppState.shared.favoriteIDs.contains(filename) {
                AppState.shared.favoriteIDs.append(filename)
            }
        } else {
            // Remove
            AppState.shared.favoriteIDs.removeAll { $0 == filename }
        }
        
        print("ViewModel: Toggled favorite for \(filename). Total saved: \(AppState.shared.favoriteIDs.count)")
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .one
        case .one: repeatMode = .all
        case .all: repeatMode = .off
        }
    }
}

// MARK: - BufferedSlider View
struct BufferedSlider: View {
    @Binding var value: TimeInterval
    let bounds: ClosedRange<TimeInterval>
    let buffered: TimeInterval
    let onEditingChanged: (Bool) -> Void

    let trackHeight: CGFloat = 4
    let thumbSize: CGFloat = 16
    let bufferColor = Color(hex: "#585b66")
    let trackColor = Color.gray.opacity(0.2)
    let playedColor = Color(hex: "#96989f")

    var body: some View {
        GeometryReader { geometry in
            let totalDuration = bounds.upperBound - bounds.lowerBound
            let containerWidth = geometry.size.width

            // Calculate widths
            let playedFraction = totalDuration > 0 ? self.value / totalDuration : 0
            let bufferedFraction = totalDuration > 0 ? self.buffered / totalDuration : 0

            let playedWidth = CGFloat(playedFraction) * containerWidth
            let bufferedWidth = CGFloat(bufferedFraction) * containerWidth

            ZStack(alignment: .leading) {
                // Background Track
                Rectangle()
                    .fill(trackColor)
                    .frame(height: trackHeight)
                    .cornerRadius(trackHeight / 2)

                // Buffered Track
                Rectangle()
                    .fill(bufferColor)
                    .frame(width: min(bufferedWidth, containerWidth), height: trackHeight)
                    .cornerRadius(trackHeight / 2)

                // Played Track
                Rectangle()
                    .fill(playedColor)
                    .frame(width: min(playedWidth, containerWidth), height: trackHeight)
                    .cornerRadius(trackHeight / 2)

                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                    .offset(x: min(playedWidth, containerWidth) - (thumbSize / 2))
            }
            .frame(height: thumbSize) // Ensure ZStack can contain the thumb
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gestureValue in
                        if !viewModel.isUserScrubbing {
                            onEditingChanged(true)
                        }
                        let percentage = min(max(0, gestureValue.location.x / containerWidth), 1)
                        self.value = TimeInterval(percentage) * totalDuration
                    }
                    .onEnded { _ in
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: thumbSize) // Overall height for the slider
    }

    @EnvironmentObject var viewModel: MusicPlayerViewModel
}

// MARK: - SwiftUI View
struct MusicPlayerView: View {
    @ObservedObject var viewModel: MusicPlayerViewModel

    // Colors & Styling (Unchanged)
    let backgroundColor = Color(hex: "#2e3240")
    let primaryTextColor = Color(hex: "#FFFFFF")
    let secondaryTextColor = Color(hex: "#B3B3B3")
    let iconColor = Color(hex: "#FFFFFF")
    let accentColor = Color(hex: "#004a77")
    let defaultImageName = "Gemini_music_player_logo"

    // Fonts (Unchanged)
    private let titleFont = Font.custom("Google Sans Medium", size: 24)
    private let titleUIFont = UIFont(name: "Google Sans Medium", size: 24) ?? UIFont.systemFont(ofSize: 24, weight: .medium)
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

                    VStack(alignment: .leading, spacing: 4) {
                        TapToMarqueeText(text: track.title, font: titleFont, uiFont: titleUIFont, color: primaryTextColor)
                            .id("title-\(track.id)")
                        TapToMarqueeText(text: track.artist, font: artistFont, uiFont: artistUIFont, color: primaryTextColor.opacity(0.5))
                            .id("artist-\(track.id)")
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

                 HStack {
                    Spacer()
                    ControlButton(systemName: viewModel.repeatMode == .one ? "repeat.1" : "repeat", size: 36, color: viewModel.repeatMode == .off ? iconColor : accentColor, accessibilityLabel: "Repeat mode: \(viewModel.repeatMode == .off ? "Off" : viewModel.repeatMode == .one ? "Repeat One" : "Repeat All")") { viewModel.cycleRepeatMode() }
                    Spacer()
                     // --- new button icon - previous ---
                     Button(action: { viewModel.previousTrack() }) {
                             PreviousTrackIcon()
                                 .frame(height: 24)
                                 .foregroundColor(iconColor)
                         }
                         .accessibilityLabel("Previous track")
                    Spacer()
                     Button(action: { viewModel.isPlaying ? viewModel.pause() : viewModel.play() }) {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 72)).frame(width: 72, height: 72).foregroundColor(accentColor)
                    }.accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
                    Spacer()
                     // --- new button icon - next ---
                     Button(action: { viewModel.nextTrack() }) {
                             NextTrackIcon()
                                 .frame(height: 24)
                                 .foregroundColor(iconColor)
                         }
                         .accessibilityLabel("Next track")
                    Spacer()
                     ControlButton(
                        systemName: track.isFavorited ? "heart.fill" : "heart",
                        size: 36,
                        color: track.isFavorited ? accentColor : iconColor,
                        accessibilityLabel: track.isFavorited ? "Favorited" : "Not favorited"
                     ) {
                        viewModel.toggleFavorite()
                    }
                    Spacer()
                }
            }
            .padding(24).background(backgroundColor).cornerRadius(16).frame(maxWidth: 480)
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

// MARK: - ControlButton
struct ControlButton: View {
    let systemName: String
    let size: CGFloat
    var color: Color = .white
    var accessibilityLabel: String
    var accessibilityHint: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .resizable().scaledToFit().frame(width: size, height: size).foregroundColor(color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .if(accessibilityHint != nil) { view in
            view.accessibilityHint(accessibilityHint!)
        }
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - View Extension
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - Chatbot Interaction Controller
class ChatMusicController {
    static let shared = ChatMusicController()
    var playerViewModel: MusicPlayerViewModel?

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

class AppState: ObservableObject {
    static let shared = AppState() // Singleton for easy access
    
    @Published var favoriteIDs: [String] = [] {
        didSet {
            // Automatically save to UserDefaults whenever the array changes
            UserDefaults.standard.set(favoriteIDs, forKey: "favorites_list")
        }
    }

    init() {
        // Automatically load from UserDefaults on initialization
        self.favoriteIDs = UserDefaults.standard.stringArray(forKey: "favorites_list") ?? []
    }
}
