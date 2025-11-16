//
//  MusicPlayerViewModel.swift
//  MusicPlayer
//
//  Created by Lin Kuang on 11/15/25.
//

import SwiftUI
import AVFoundation
import Combine

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

    override init() {
        super.init()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }

    deinit {
        resetPlayer()
    }

    // MARK: - Playlist Loading
    func loadPlaylist(_ tracks: [MusicTrack], startIndex: Int = 0) {
        guard !tracks.isEmpty else {
            resetPlayer()
            self.playlist = []
            return
        }

        var syncedTracks = tracks

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
                self.playlist[index].duration = duration
            }
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
             try? AVAudioSession.sharedInstance().setActive(true)
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

    // MARK: - Time Observers
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

    // MARK: - Other Controls
    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .one
        case .one: repeatMode = .all
        case .all: repeatMode = .off
        }
    }

    func toggleFavorite() {
        guard let index = currentTrackIndex else { return }
        playlist[index].isFavorited.toggle()
        let filename = playlist[index].audioURL.lastPathComponent
        if playlist[index].isFavorited {
            if !AppState.shared.favoriteIDs.contains(filename) {
                AppState.shared.favoriteIDs.append(filename)
            }
        } else {
            AppState.shared.favoriteIDs.removeAll { $0 == filename }
        }
        print("ViewModel: Toggled favorite for \(filename). Total saved: \(AppState.shared.favoriteIDs.count)")
    }

    // MARK: - KVO & Observers
    private func removeObservers() {
        removePeriodicTimeObserver()
         if let item = playerItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
             item.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), context: nil)
             item.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges), context: nil)
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
                            self.playlist[index].duration = durationSeconds
                         }
                    }
                    self.addPeriodicTimeObserver()
                    self.setupEndTimeObserver()
                    self.updateBufferTime()
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

    // MARK: - Buffer Time Update
    private func updateBufferTime() {
        guard let track = currentTrack else {
            bufferedTime = 0
            return
        }

        let trackDuration = track.duration
        if track.isLocal {
            bufferedTime = min(currentTime + 15.0, trackDuration)
        } else {
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

    // MARK: - Player Reset
    private func resetPlayer() {
        removeObservers()
        player?.pause()
        player = nil
        playerItem = nil
        isPlaying = false
        currentTime = 0
        bufferedTime = 0
    }
}
