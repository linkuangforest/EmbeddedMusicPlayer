//
//  MusicTrack.swift
//  MusicPlayer
//
//  Created by Lin Kuang on 11/15/25.
//

import Foundation
import UIKit // For UIImage

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
