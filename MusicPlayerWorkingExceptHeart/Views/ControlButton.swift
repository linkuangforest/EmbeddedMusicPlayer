//
//  ControlButton.swift
//  MusicPlayer
//
//  Created by Lin Kuang on 11/15/25.
//

import SwiftUI

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
