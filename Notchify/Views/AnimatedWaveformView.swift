import SwiftUI

struct AnimatedWaveformView: View {
    var colors: [Color]
    var isPlaying: Bool
    @State private var isAnimating = false

    private let barCount = 6
    private let totalWidth: CGFloat = 21 // original 4-bar width (4 * 3 + 3 * 3), kept constant
    private let barSpacing: CGFloat = 1.5

    private var barWidth: CGFloat {
        (totalWidth - CGFloat(barCount - 1) * barSpacing) / CGFloat(barCount)
    }

    private var gradientColors: [Color] {
        colors.count >= 2 ? colors : [colors.first ?? .green, (colors.first ?? .green).opacity(0.4)]
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
                        .frame(width: barWidth, height: isAnimating ? CGFloat.random(in: 4...16) : 3)
                        .animation(
                            isAnimating
                                ? Animation.easeInOut(duration: 0.35)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.08)
                                : .easeOut(duration: 0.2),
                            value: isAnimating
                        )
                }
            }
        )
        .frame(width: totalWidth, height: 16)
        .animation(.easeInOut(duration: 0.6), value: colors)
        .onAppear {
            isAnimating = isPlaying
        }
        .onChange(of: isPlaying) { _, newValue in
            isAnimating = newValue
        }
    }
}
