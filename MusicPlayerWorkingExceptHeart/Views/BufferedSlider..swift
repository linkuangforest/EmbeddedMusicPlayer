//
//  BufferedSlider..swift
//  MusicPlayer
//
//  Created by Lin Kuang on 11/15/25.
//

import SwiftUI

// MARK: - BufferedSlider View
struct BufferedSlider: View {
    @Binding var value: TimeInterval
    let bounds: ClosedRange<TimeInterval>
    let buffered: TimeInterval
    let onEditingChanged: (Bool) -> Void

    let trackHeight: CGFloat = 4
    let thumbSize: CGFloat = 12
    let bufferColor = Color(hex: "#585b66")
    let trackColor = Color.gray.opacity(0.2)
    let playedColor = Color(hex: "#96989f")

    @EnvironmentObject var viewModel: MusicPlayerViewModel

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
}
