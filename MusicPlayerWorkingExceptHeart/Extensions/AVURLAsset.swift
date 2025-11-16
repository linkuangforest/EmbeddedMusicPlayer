//
//  AVURLAsset.swift
//  MusicPlayer
//
//  Created by Lin Kuang on 11/15/25.
//

import AVFoundation
import UIKit // For UIImage

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
