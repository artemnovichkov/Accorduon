import SwiftUI

/// The pleated bellows between the two ends of the accordion.
///
/// The ends stay put so keys don't slide under your thumbs. Instead, the pleats
/// deepen and darken as the bellows close, and ripple while air flows.
struct Bellows: View {
    /// 0 when closed, 1 when fully stretched.
    var stretch: Double
    /// Air pressure, 0...1.
    var pressure: Double
    /// Seconds, drives the ripple.
    var time: Double

    private let pleatCount = 10

    var body: some View {
        Canvas { context, size in
            let pleatWidth = size.width / Double(pleatCount)
            let compression = 1 - stretch
            let litFace = Color(white: 0.2 + 0.15 * stretch)
            let shadedFace = Color(white: 0.06 + 0.06 * stretch)

            for index in 0..<pleatCount {
                let ripple = pressure * 5 * sin(time * 16 + Double(index) * 0.9)
                let depth = 6 + 28 * compression + ripple
                let left = Double(index) * pleatWidth
                let middle = left + pleatWidth / 2
                let right = left + pleatWidth
                let bottom = size.height

                context.fill(Path { path in
                    path.addLines([
                        CGPoint(x: left, y: 0), CGPoint(x: middle, y: depth),
                        CGPoint(x: middle, y: bottom - depth), CGPoint(x: left, y: bottom),
                    ])
                }, with: .color(litFace))
                context.fill(Path { path in
                    path.addLines([
                        CGPoint(x: middle, y: depth), CGPoint(x: right, y: 0),
                        CGPoint(x: right, y: bottom), CGPoint(x: middle, y: bottom - depth),
                    ])
                }, with: .color(shadedFace))

                // A white ridge on every outer fold, like classic bellows tape.
                context.stroke(Path { path in
                    path.move(to: CGPoint(x: left, y: 0))
                    path.addLine(to: CGPoint(x: left, y: bottom))
                }, with: .color(.white.opacity(0.75)), lineWidth: 1.5)

                // Metal corner guards on the ridges.
                for (y, direction) in [(0.0, 1.0), (bottom, -1.0)] {
                    context.fill(Path { path in
                        path.addLines([
                            CGPoint(x: left - 5, y: y), CGPoint(x: left + 5, y: y),
                            CGPoint(x: left, y: y + 12 * direction),
                        ])
                    }, with: .linearGradient(
                        Gradient(colors: [.white, .gray]),
                        startPoint: CGPoint(x: left - 5, y: y),
                        endPoint: CGPoint(x: left + 5, y: y)
                    ))
                }
            }
        }
        .accessibilityLabel("Bellows")
    }
}

#Preview {
    Bellows(stretch: 0.5, pressure: 0, time: 0)
        .frame(width: 200, height: 400)
}
