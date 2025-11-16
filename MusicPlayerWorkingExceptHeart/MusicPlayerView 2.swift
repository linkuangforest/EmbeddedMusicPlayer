import SwiftUI
import AVFoundation // Import for actual audio playback
//import googlemac_iPhone_Shared_GoogleMaterial_swiftui_components_GoogleSans_Regular

// MARK: - Color Extension for Hex
extension Color {
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
}

// MARK: - Data Model
struct MusicTrack: Identifiable {
    let id = UUID()
    var title: String
    var artist: String
    var albumArtURL: URL?
    var audioURL: URL // Non-optional for playback
    var duration: TimeInterval
    var isLocal: Bool { audioURL.isFileURL }
}

// MARK: - ViewModel
class MusicPlayerViewModel: NSObject, ObservableObject { // Inherit from NSObject
    @Published var currentTrack: MusicTrack?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0

    enum RepeatMode { case off, one, all }
    @Published var repeatMode: RepeatMode = .off
    @Published var isFavorited: Bool = false

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserverToken: Any?

    // MARK: - Audio Playback Controls

    func loadAndPlay(track: MusicTrack) {
        preparePlayer(with: track.audioURL) { [weak self] duration in
             guard let self = self else { return }
             var updatedTrack = track
             if track.duration == 0 { // Update duration if not provided
                updatedTrack.duration = duration
             }
             self.currentTrack = updatedTrack
             self.currentTime = 0
             // self.isPlaying = true // Set isPlaying to true to trigger play in KVO
             self.play()
        }
    }

    private func preparePlayer(with url: URL, completion: @escaping (TimeInterval) -> Void) {
        // Clean up previous player
        removeObservers()
        player?.pause()
        player = nil
        playerItem = nil

        let asset = AVAsset(url: url)
        playerItem = AVPlayerItem(asset: asset)

        // Observe item status to know when it's ready
        playerItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.new, .initial], context: nil)

        player = AVPlayer(playerItem: playerItem)

        // Load duration
        asset.loadValuesAsynchronously(forKeys: ["duration"]) {
            DispatchQueue.main.async {
                let durationSeconds = CMTimeGetSeconds(asset.duration)
                 completion(durationSeconds.isNaN ? 0 : durationSeconds)
            }
        }
    }

    func play() {
        guard let player = player else { return }
        if player.currentItem != nil {
             if player.timeControlStatus != .playing {
                player.play()
            }
            isPlaying = true // Reflect state
            print("ViewModel: Play")
        } else {
            print("ViewModel: Player item not ready for play")
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        print("ViewModel: Pause")
    }

    func seek(to time: TimeInterval) {
        guard let player = player, let currentItem = player.currentItem else { return }
        let duration = CMTimeGetSeconds(currentItem.duration)
        if duration.isNaN { return } // Not ready yet
        let newTime = max(0, min(time, duration))
        let cmTime = CMTime(seconds: newTime, preferredTimescale: 600)
        player.seek(to: cmTime) { [weak self] finished in
            if finished {
                 DispatchQueue.main.async {
                    self?.currentTime = newTime
                }
            }
        }
        print("ViewModel: Seek to \(newTime)")
    }

    // MARK: - Observers

    override init() {
        super.init()
        // Setup audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }

    private func addPeriodicTimeObserver() {
        guard let player = player else { return }
        removePeriodicTimeObserver() // Remove any existing observer

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = CMTimeGetSeconds(time)
        }
    }

    private func removePeriodicTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }

    private func setupEndTimeObserver() {
        guard let playerItem = playerItem else { return }
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak self] _ in
            print("ViewModel: Track finished")
            self?.isPlaying = false
            self?.currentTime = 0 // Reset to start
            self?.player?.seek(to: .zero)
            // TODO: Implement repeat or next track logic here based on self.repeatMode
        }
    }

    private func removeObservers() {
        removePeriodicTimeObserver()
         if let item = playerItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
            item.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        }
    }

    deinit {
        removeObservers()
        print("MusicPlayerViewModel deinit")
    }

    // KVO for player item status
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                switch status {
                case .readyToPlay:
                    print("PlayerItem ready to play")
                    if let itemDuration = self.playerItem?.duration {
                         let durationSeconds = CMTimeGetSeconds(itemDuration)
                         if self.currentTrack != nil && !durationSeconds.isNaN {
                            self.currentTrack?.duration = durationSeconds
                        }
                    }
                    self.addPeriodicTimeObserver()
                    self.setupEndTimeObserver()
                    if self.isPlaying { // Autoplay if isPlaying was set true
                         self.player?.play()
                    }
                case .failed:
                    print("PlayerItem failed: \(self.playerItem?.error?.localizedDescription ?? "Unknown error")")
                    self.isPlaying = false
                case .unknown:
                    print("PlayerItem status unknown")
                @unknown default:
                    break
                }
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    // MARK: - Other Controls
    func nextTrack() { /* TODO: Implement */ print("ViewModel: Next Track") }
    func previousTrack() { /* TODO: Implement */ print("ViewModel: Previous Track") }
    func toggleFavorite() { isFavorited.toggle(); print("ViewModel: Toggle Favorite to \(isFavorited)") }
    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .one
        case .one: repeatMode = .all
        case .all: repeatMode = .off
        }
        print("ViewModel: Cycle Repeat Mode to \(repeatMode)")
    }
}

// MARK: - SwiftUI View
struct MusicPlayerView: View {
    @ObservedObject var viewModel: MusicPlayerViewModel

    // MARK: - Colors & Styling based on Screenshot
    let backgroundColor = Color(hex: "#2e3240") // Dark Blue-Gray
    let primaryTextColor = Color(hex: "#FFFFFF") // White
    let secondaryTextColor = Color(hex: "#B3B3B3") // Light Gray for artist/time
    let sliderColor = Color(hex: "#FFFFFF")
    let iconColor = Color(hex: "#FFFFFF")
    let accentColor = Color(hex: "#004a77") // Blue for Play/Pause button

    var body: some View {
        if let track = viewModel.currentTrack {
            VStack(spacing: 16) {
                // ... (HStack for Track Info - No changes)
                HStack(spacing: 12) {
                    AsyncImage(url: track.albumArtURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 88, height: 88)
                    .cornerRadius(8)
                    .clipped()

                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            //.font(.system(size: 20, weight: .bold))
                            .font(.custom("GoogleSansText-Medium", size: 24))
                            .foregroundColor(primaryTextColor)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(track.artist)
                            //.font(.system(size: 16))
                            .font(.custom("GoogleSansText-Regular", size: 16))
                            .foregroundColor(secondaryTextColor)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer()
                }

                // MARK: - Progress Bar
                VStack(spacing: 4) {
                    Slider(value: $viewModel.currentTime, in: 0...(track.duration > 0 ? track.duration : 1), onEditingChanged: { editing in
                        if !editing {
                            viewModel.seek(to: viewModel.currentTime)
                        }
                    })
                    .accentColor(sliderColor)

                    HStack {
                        Text(timeString(from: viewModel.currentTime))
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                        Spacer()
                        Text(timeString(from: track.duration))
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                    }
                }

                // ... (HStack for Controls - No changes)
                 HStack {
                    Spacer()
                    ControlButton(systemName: viewModel.repeatMode == .one ? "repeat.1" : "repeat", size: 36, color: viewModel.repeatMode == .off ? secondaryTextColor : iconColor) {
                        viewModel.cycleRepeatMode()
                    }
                    .frame(width: 36, height: 36)
                    Spacer()
                    ControlButton(systemName: "backward.end.fill", size: 28, color: iconColor) { viewModel.previousTrack() }
                    Spacer()
                     Button(action: { viewModel.isPlaying ? viewModel.pause() : viewModel.play() }) {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            //.resizable()
                            //.scaledToFit()
                            .font(.system(size: 72))
                            .frame(width: 72, height: 72)
                            .foregroundColor(accentColor)
                    }
                    Spacer()
                    ControlButton(systemName: "forward.end.fill", size: 28, color: iconColor) { viewModel.nextTrack() }
                    Spacer()
                     ControlButton(systemName: viewModel.isFavorited ? "heart.fill" : "heart", size: 36, color: viewModel.isFavorited ? .red : iconColor) {
                        viewModel.toggleFavorite()
                    }
                    Spacer()
                }
            }
            .padding(24)
            .background(backgroundColor)
            .cornerRadius(16)
            .frame(maxWidth: 480)
        } else {
            EmptyView()
        }
    }

    private func timeString(from timeInterval: TimeInterval) -> String {
        // Check for NaN or Infinite on the TimeInterval (Double) first
        if timeInterval.isNaN || timeInterval.isInfinite {
            return "0:00"
        }

        let totalSeconds = Int(timeInterval)
        let seconds = totalSeconds % 60
        let minutes = totalSeconds / 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// ... (ControlButton, PreviewProvider remain the same)
struct ControlButton: View {
    let systemName: String
    let size: CGFloat
    var color: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(color)
        }
    }
}

struct MusicPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = MusicPlayerViewModel()
         let sampleTrack = MusicTrack(
            title: "Black Friday (pretty like the sun) - Lost Frequencies",
            artist: "Lost Frequencies",
             audioURL: URL(fileURLWithPath: "Black Friday (pretty like the sun) - Lost Frequencies.mp3"), // Placeholder for preview
            duration: 0
        )
         viewModel.currentTrack = sampleTrack

        return MusicPlayerView(viewModel: viewModel)
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.black)
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
            case "PLAY_LOCAL_LOST_FREQUENCIES":
                self.playLostFrequenciesTrack()
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
                    viewModel.loadAndPlay(track: track)
                } else {
                    print("Missing parameters for PLAY_SONG")
                }
            case "PAUSE": viewModel.pause()
            case "RESUME": viewModel.play()
            // ... other commands
            default:
                print("Unknown chat command: \(command)")
            }
        }
    }

    private func playLostFrequenciesTrack() {
        let fileName = "Black Friday (pretty like the sun) - Lost Frequencies"
        let fileExtension = "mp3"

        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            print("ERROR: Local file \(fileName).\(fileExtension) not found in bundle.")
            // Optionally, provide feedback to the user through the chat interface
            return
        }

        let track = MusicTrack(
            title: "Black Friday (pretty like the sun)",
            artist: "Lost Frequencies",
            albumArtURL: nil, // Add a local image URL if you have one
            audioURL: url,
            duration: 0 // Duration will be loaded by the player
        )
        playerViewModel?.loadAndPlay(track: track)
    }
}

