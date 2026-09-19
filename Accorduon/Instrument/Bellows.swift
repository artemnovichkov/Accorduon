import SwiftUI

/// The pleated bellows between the two ends of the accordion.
///
/// The ends stay put so keys don't slide under your thumbs. Instead, the pleats
/// deepen and darken as the bellows close, and ripple while air flows.
/// Opening fills them with air: they sag inward when closed and bulge outward when open.
struct Bellows: View {
    /// 0 when closed, 1 when fully stretched.
    var stretch: Double
    /// Air pressure, 0...1.
    var pressure: Double
    /// Seconds, drives the ripple.
    var time: Double

    private let pleatCount = 10
    /// Room above and below for the bulge.
    private let margin = 12.0

    var body: some View {
        Canvas { context, size in
            let pleatWidth = size.width / Double(pleatCount)
            let compression = 1 - stretch
            let litFace = Color(white: 0.2 + 0.15 * stretch)
            let shadedFace = Color(white: 0.06 + 0.06 * stretch)
            // A pump of air puffs them up a little more.
            let inflation = min(stretch + 0.3 * pressure, 1)
            let sag = size.height * 0.12 * (1 - inflation)
            let bulge = margin * inflation
            // Distance from the top (and bottom) edge, deepest in the middle, zero at the ends.
            func edge(_ x: Double) -> Double {
                margin + (sag - bulge) * sin(.pi * x / size.width)
            }

            for index in 0..<pleatCount {
                let ripple = pressure * 5 * sin(time * 16 + Double(index) * 0.9)
                let depth = 6 + 28 * compression + ripple
                let left = Double(index) * pleatWidth
                let middle = left + pleatWidth / 2
                let right = left + pleatWidth
                let height = size.height
                let (leftEdge, middleEdge, rightEdge) = (edge(left), edge(middle) + depth, edge(right))

                context.fill(Path { path in
                    path.addLines([
                        CGPoint(x: left, y: leftEdge), CGPoint(x: middle, y: middleEdge),
                        CGPoint(x: middle, y: height - middleEdge), CGPoint(x: left, y: height - leftEdge),
                    ])
                }, with: .color(litFace))
                context.fill(Path { path in
                    path.addLines([
                        CGPoint(x: middle, y: middleEdge), CGPoint(x: right, y: rightEdge),
                        CGPoint(x: right, y: height - rightEdge), CGPoint(x: middle, y: height - middleEdge),
                    ])
                }, with: .color(shadedFace))

                // A white ridge on every outer fold, like classic bellows tape.
                context.stroke(Path { path in
                    path.move(to: CGPoint(x: left, y: leftEdge))
                    path.addLine(to: CGPoint(x: left, y: height - leftEdge))
                }, with: .color(.white.opacity(0.75)), lineWidth: 1.5)

                // Metal corner guards on the ridges.
                for (y, direction) in [(leftEdge, 1.0), (height - leftEdge, -1.0)] {
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
