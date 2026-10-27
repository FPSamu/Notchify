import SwiftUI

struct DynamicIslandView: View {
    @ObservedObject var state: IslandState
    @State private var isHovering: Bool = false
    @State private var isPressed: Bool = false
    @StateObject private var spotify = SpotifyManager()

    private var isExpanded: Bool { state.isExpanded }

    private let hoverScale: CGFloat = 1.06
    private let pressedScale: CGFloat = 0.97

    private var islandScale: CGFloat {
        if isExpanded { return 1 }
        if isPressed { return pressedScale }
        return isHovering ? hoverScale : 1
    }

    let activeWidth = IslandLayout.compactSize.width
    let activeHeight = IslandLayout.compactSize.height

    let expandedWidth = IslandLayout.expandedSize.width
    let expandedHeight = IslandLayout.expandedSize.height
    
    var currentWidth: CGFloat {
        return isExpanded ? expandedWidth : activeWidth
    }
    
    var currentHeight: CGFloat {
        return isExpanded ? expandedHeight : activeHeight
    }
    
    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isExpanded ? 28 : activeHeight / 2, style: .continuous)
                .fill(Color.black)
                .frame(width: currentWidth, height: currentHeight)
                .shadow(color: .black.opacity(isExpanded ? 0.3 : 0), radius: 10, x: 0, y: 5)
            
            if isExpanded {
                VStack(spacing: 12) {
                    // Fila 1: Portada, Título y Artista
                    HStack(spacing: 10) {
                        albumArt(size: 42, cornerRadius: 8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(spotify.trackName)
                                .font(.subheadline).bold().foregroundColor(.white).lineLimit(1)
                            Text(spotify.artistName)
                                .font(.caption).foregroundColor(.gray).lineLimit(1)
                        }
                        
                        Spacer()

                        AnimatedWaveformView(colors: spotify.waveformColors, isPlaying: spotify.isPlaying)
                    }

                    // Fila 2: Barra de progreso con actualización fluida
                    TimelineView(
                        .periodic(from: .now, by: 0.25)
                    ) { context in

                        let elapsedSinceFetch: Double = spotify.isPlaying
                            ? max(0, context.date.timeIntervalSince(spotify.lastFetchTime))
                            : 0

                        let currentPosition = min(
                            max(0, spotify.trackPosition + elapsedSinceFetch),
                            spotify.trackDuration
                        )

                        let progress: Double = spotify.trackDuration > 0
                            ? currentPosition / spotify.trackDuration
                            : 0

                        VStack(spacing: 4) {

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {

                                    // Fondo de la barra
                                    Capsule()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(height: 4)

                                    // Progreso de la canción
                                    Capsule()
                                        .fill(spotify.accentColor)
                                        .frame(
                                            width: geometry.size.width
                                                * CGFloat(progress),
                                            height: 4
                                        )
                                }
                            }
                            .frame(height: 4)

                            // Tiempo transcurrido y restante
                            HStack {
                                Text(formatTime(currentPosition))
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)

                                Spacer()

                                Text("-" + formatTime(
                                    max(0, spotify.trackDuration - currentPosition)
                                ))
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    // Fila 3: Controles
                    HStack(spacing: 22) {
                        Button(action: { spotify.toggleLike() }) {
                            Image(systemName: spotify.isLiked ? "heart.fill" : "heart")
                                .foregroundColor(spotify.isLiked ? spotify.accentColor : .white)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { spotify.previousTrack() }) {
                            Image(systemName: "backward.fill")
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { spotify.togglePlayPause() }) {
                            Image(systemName: spotify.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { spotify.nextTrack() }) {
                            Image(systemName: "forward.fill")
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { spotify.updateAudioOutputDevice() }) {
                            Image(systemName: spotify.audioOutputIcon)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.system(size: 16))
                }
                .padding(.horizontal, 14)
                .padding(.top, 28)
                .padding(.bottom, 14)
                .frame(width: expandedWidth, height: expandedHeight, alignment: .top)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                
            } else {
                HStack {
                    albumArt(size: 18, cornerRadius: 9)
                    Spacer()
                    AnimatedWaveformView(colors: spotify.waveformColors, isPlaying: spotify.isPlaying)
                }
                .padding(.horizontal, 6)
                .frame(width: activeWidth, height: activeHeight)
                .transition(.opacity)

                Color.clear
                    .frame(width: activeWidth, height: activeHeight)
                    .contentShape(RoundedRectangle(cornerRadius: activeHeight / 2, style: .continuous))
                    .onContinuousHover { phase in
                        switch phase {
                        case .active: NSCursor.pointingHand.set()
                        case .ended: NSCursor.arrow.set()
                        }
                    }
                    .onTapGesture { state.expand() }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in isPressed = true }
                            .onEnded { _ in isPressed = false }
                    )
            }
        }
        .scaleEffect(islandScale, anchor: .top)
        .onHover { hovering in
            if !isExpanded { isHovering = hovering }
        }
        .onChange(of: isExpanded) { _, expanded in
            if !expanded {
                isHovering = false
                isPressed = false
            }
        }
        .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.65, blendDuration: 0.1), value: isExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovering)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)

        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 0)
        .ignoresSafeArea()
    }
    
    @ViewBuilder
    func albumArt(size: CGFloat, cornerRadius: CGFloat) -> some View {
        if let url = spotify.artworkURL {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.gray.opacity(0.3)
                }
            }
            .frame(width: size, height: size)
            .cornerRadius(cornerRadius)
        } else {
            Rectangle().fill(Color.gray.opacity(0.3))
                .frame(width: size, height: size)
                .cornerRadius(cornerRadius)
        }
    }
}
