//
//  FavoritedTrackID.swift
//  MusicPlayer
//
//  Created by Lin Kuang on 11/15/25.
//

import Foundation
import SwiftData

@Model
class FavoritedTrackID {
    @Attribute(.unique) var id: String // Will store audioURL.absoluteString

    init(id: String) {
        self.id = id
    }
}

