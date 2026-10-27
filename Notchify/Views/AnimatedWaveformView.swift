import Combine
import SwiftUI

struct AnimatedWaveformView: View {
    var colors: [Color]
    var isPlaying: Bool

    private let barCount = 6
    private let totalWidth: CGFloat = 21 // original 4-bar width (4 * 3 + 3 * 3), kept constant
    private let barSpacing: CGFloat = 1.5
    private let restHeight: CGFloat = 3
    private let heightRange: ClosedRange<CGFloat> = 4...16
    private let tick = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    @State private var heights: [CGFloat]

    init(colors: [Color], isPlaying: Bool) {
        self.colors = colors
        self.isPlaying = isPlaying
        _heights = State(initialValue: Array(repeating: 3, count: 6))
    }

    private var barWidth: CGFloat {
        (totalWidth - CGFloat(barCount - 1) * barSpacing) / CGFloat(barCount)
    }

    private var gradientColors: [Color] {
        colors.count >= 2 ? colors : [colors.first ?? .green, (colors.first ?? .green).opacity(0.4)]
    }

    private func refreshHeights() {
        withAnimation(.easeInOut(duration: 0.25)) {
            heights = (0..<barCount).map { _ in
                isPlaying ? CGFloat.random(in: heightRange) : restHeight
            }
        }
    }

    var body: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .leading,
            endPoint: .trailing
        )
        .mask(
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .frame(width: barWidth, height: heights[index])
                }
            }
        )
        .frame(width: totalWidth, height: 16)
        .animation(.easeInOut(duration: 0.6), value: colors)
        .onAppear { refreshHeights() }
        .onChange(of: isPlaying) { _, _ in refreshHeights() }
        .onReceive(tick) { _ in
            if isPlaying { refreshHeights() }
        }
    }
}
