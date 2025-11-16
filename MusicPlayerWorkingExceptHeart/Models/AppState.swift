//
//  AppState.swift
//  MusicPlayer
//
//  Created by Lin Kuang on 11/15/25.
//

import SwiftUI
import Combine
import Foundation

// MARK: - App State
class AppState: ObservableObject {
    static let shared = AppState() // Singleton for easy access
    private let userDefaultsKey = "favorites_list"

    @Published var favoriteIDs: [String] = [] {
        didSet {
            // Automatically save to UserDefaults whenever the array changes
            UserDefaults.standard.set(favoriteIDs, forKey: userDefaultsKey)
        }
    }

    private init() {
        // Automatically load from UserDefaults on initialization
        loadFromUserDefaults()
    }

    // MARK: - Testability Methods

    /// Reloads favoriteIDs from UserDefaults.
    internal func loadFromUserDefaults() {
        self.favoriteIDs = UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? []
    }

    /// Clears the favoriteIDs from UserDefaults.
    internal func clearUserDefaults() {
         UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
