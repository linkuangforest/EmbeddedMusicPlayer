//
//  CustomIcons.swift
//  MusicPlayer
//
//  Created by Lin Kuang on 11/15/25.
//

import SwiftUI

// MARK: - 1. The Shapes
struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 2. The Icons

struct NextTrackIcon: View {
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: geometry.size.width * 0.25) { // Your specific spacing
                
                // The Triangle
                TriangleShape()
                    .fill(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: geometry.size.height * 0.12, style: .continuous))
                    .frame(width: geometry.size.width * 0.55)
                
                // The Line
                Capsule(style: .continuous)
                    .fill(Color.white)
                    .frame(width: geometry.size.width * 0.1) // Your specific width
            }
        }
        .aspectRatio(1.1, contentMode: .fit)
    }
}

struct PreviousTrackIcon: View {
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: geometry.size.width * 0.25) {
                
                // The Line
                Capsule(style: .continuous)
                    .fill(Color.white)
                    .frame(width: geometry.size.width * 0.1)
                
                // The Triangle (Rotated)
                TriangleShape()
                    .fill(Color.white)
                    .rotationEffect(.degrees(180))
                    .clipShape(RoundedRectangle(cornerRadius: geometry.size.height * 0.12, style: .continuous))
                    .frame(width: geometry.size.width * 0.55)
            }
        }
        .aspectRatio(1.1, contentMode: .fit)
    }
}

// MARK: - 3. The Animation Style (New Addition)
struct MediaButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Scale down to 0.85 when pressed
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            // Slight opacity change for better feel
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            // "Snap" back animation
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - 4. Preview & Usage
struct PlayerIcons_Preview: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            HStack(spacing: 80) {
                
                // USAGE: Just add .buttonStyle(MediaButtonStyle()) to your buttons
                
                Button(action: { print("Prev") }) {
                    PreviousTrackIcon()
                        .frame(height: 50)
                }
                .buttonStyle(MediaButtonStyle()) // <--- ADDS THE ANIMATION
                
                Button(action: { print("Next") }) {
                    NextTrackIcon()
                        .frame(height: 50)
                }
                .buttonStyle(MediaButtonStyle()) // <--- ADDS THE ANIMATION
            }
        }
    }
}
