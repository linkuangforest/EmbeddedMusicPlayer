//
//  View.swift
//  MusicPlayer
//
//  Created by Lin Kuang on 11/15/25.
//

import SwiftUI

// MARK: - View Extension
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}
