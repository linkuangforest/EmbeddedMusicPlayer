//
//  TapToMarqueeText.swift
//  MusicPlayer
//
//  Created by Lin Kuang on 11/15/25.
//

import SwiftUI
import UIKit // For UIFont

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

