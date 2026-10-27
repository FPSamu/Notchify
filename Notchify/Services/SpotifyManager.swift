import Combine
import Cocoa
import CoreAudio
import SwiftUI

class SpotifyManager: ObservableObject {

    // MARK: - Published Properties

    @Published var isLiked: Bool = false
    @Published var trackName: String = ""
    @Published var artistName: String = ""
    @Published var isPlaying: Bool = false

    @Published var trackDuration: Double = 0
    @Published var trackPosition: Double = 0
    @Published var lastFetchTime: Date = .now

    @Published var accentColor: Color = .green

    @Published var waveformColors: [Color] = [.green, .green.opacity(0.5)]

    @Published var artworkURL: URL?
    @Published var artworkImage: NSImage?

    @Published var lastError: String?
    
    @Published var audioOutputIcon: String = "speaker.wave.2.fill"


    // MARK: - Private Properties

    private let spotifyBundleID = "com.spotify.client"

    private var syncTimer: Timer?

    private let scriptQueue = DispatchQueue(
        label: "com.notchify.spotify.script",
        qos: .userInitiated
    )

    private var isRefreshing = false

    private var lastArtworkTrackID: String?

    // MARK: - Initialization

    init() {
        updateAudioOutputDevice()
        startObservingAudioOutputDevice()
        startSyncTimer()

        // Primera consulta
        refreshState()
    }

    deinit {
        syncTimer?.invalidate()
    }

    // MARK: - Timer

    func startSyncTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            self.syncTimer?.invalidate()

            self.syncTimer = Timer.scheduledTimer(
                withTimeInterval: 2.0,
                repeats: true
            ) { [weak self] _ in
                self?.refreshState()
            }

            if let timer = self.syncTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }

    func stopSyncTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.syncTimer?.invalidate()
            self?.syncTimer = nil
        }
    }

    func updateAudioOutputDevice() {
        audioOutputIcon = AudioSystemObject.iconName(for: AudioSystemObject.defaultOutputDeviceID)
    }

    private func startObservingAudioOutputDevice() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.updateAudioOutputDevice()
        }
    }
    
    // MARK: - Refresh Spotify State

    func refreshState() {
        // Evita ejecutar varias consultas simultáneamente.
        guard !isRefreshing else { return }
        isRefreshing = true

        scriptQueue.async { [weak self] in
            guard let self else { return }

            defer {
                DispatchQueue.main.async {
                    self.isRefreshing = false
                }
            }

            // Comprobamos si Spotify está disponible.
            let appURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: self.spotifyBundleID
            )

            guard appURL != nil else {
                self.reportError(
                    "No se encontró Spotify con bundle ID \(self.spotifyBundleID)"
                )
                return
            }

            /*
             IMPORTANTE:
             No lanzamos Spotify en cada consulta.
             Primero comprobamos si ya está ejecutándose.
             */

            let script = """
            tell application id "\(self.spotifyBundleID)"
                if it is not running then
                    return "NOT_RUNNING"
                end if

                set pState to player state as string

                if pState is "stopped" then
                    return "Stopped"
                end if

                set tName to name of current track
                set tArtist to artist of current track
                set tId to spotify url of current track

                set tDuration to (duration of current track) / 1000
                set tPosition to player position

                return pState & "|||" & ¬
                    tName & "|||" & ¬
                    tArtist & "|||" & ¬
                    tId & "|||" & ¬
                    (tDuration as string) & "|||" & ¬
                    (tPosition as string)
            end tell
            """

            var scriptError: NSDictionary?

            guard let appleScript = NSAppleScript(source: script) else {
                self.reportError(
                    "No se pudo crear la instancia de NSAppleScript."
                )
                return
            }

            let result = appleScript.executeAndReturnError(
                &scriptError
            )

            // Registramos el error completo de AppleScript.
            if let scriptError {
                let message = """
                Error de AppleScript:
                \(scriptError)
                """

                self.reportError(message)
                return
            }

            guard let output = result.stringValue else {
                self.reportError(
                    "AppleScript no devolvió una respuesta de texto."
                )
                return
            }

            print("🎵 Respuesta de Spotify: \(output)")

            if output == "NOT_RUNNING" {
                self.reportError(
                    "Spotify no está ejecutándose. Abre Spotify y vuelve a intentarlo."
                )
                return
            }

            if output == "Stopped" {
                DispatchQueue.main.async {
                    self.isPlaying = false
                    self.trackPosition = 0
                    self.trackDuration = 0
                    self.lastFetchTime = .now
                    self.lastError = nil
                }

                return
            }

            if output.hasPrefix("APPLE_SCRIPT_ERROR|||") {
                self.reportError(output)
                return
            }

            let parts = output.components(separatedBy: "|||")

            guard parts.count >= 6 else {
                self.reportError(
                    "Respuesta de Spotify incompleta: \(output)"
                )
                return
            }

            let newIsPlaying = parts[0].lowercased() == "playing"
            let newTrackName = parts[1]
            let newArtistName = parts[2]
            let spotifyURI = parts[3]

            guard
                let duration = Double(
                    parts[4].trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                ),
                let position = Double(
                    parts[5].trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                )
            else {
                self.reportError(
                    "No se pudieron interpretar posición y duración: \(output)"
                )
                return
            }

            DispatchQueue.main.async {
                let isNewTrack =
                    self.trackName != newTrackName ||
                    self.lastArtworkTrackID != spotifyURI

                self.isPlaying = newIsPlaying
                self.trackName = newTrackName
                self.artistName = newArtistName
                self.isLiked = false

                self.trackDuration = max(0, duration)
                self.trackPosition = max(0, position)

                // Referencia temporal para interpolar el progreso.
                self.lastFetchTime = .now

                self.lastError = nil

                if isNewTrack {
                    self.lastArtworkTrackID = spotifyURI
                    self.fetchArtworkURL(
                        spotifyURI: spotifyURI
                    )
                }

                print("""
                ✅ Estado actualizado:
                   Canción: \(self.trackName)
                   Artista: \(self.artistName)
                   Reproduciendo: \(self.isPlaying)
                   Posición: \(self.trackPosition)
                   Duración: \(self.trackDuration)
                """)
            }
        }
    }

    // MARK: - Error Handling

    private func reportError(_ message: String) {
        print("❌ SpotifyManager: \(message)")

        DispatchQueue.main.async { [weak self] in
            self?.lastError = message
        }
    }

    // MARK: - Like Controls

    func toggleLike() {
        scriptQueue.async { [weak self] in
            guard let self else { return }

            let script = """
            tell application id "\(self.spotifyBundleID)"
                if liked of current track then
                    set liked of current track to false
                else
                    set liked of current track to true
                end if

                return liked of current track
            end tell
            """

            var errorInfo: NSDictionary?

            guard let appleScript = NSAppleScript(source: script) else {
                self.reportError("No se pudo crear el script para favoritos.")
                return
            }

            let result = appleScript.executeAndReturnError(&errorInfo)

            if let errorInfo {
                self.reportError(
                    "Error al cambiar favorito: \(errorInfo)"
                )
                return
            }

            let liked = result.booleanValue

            DispatchQueue.main.async {
                self.isLiked = liked
            }
        }
    }
    
    // MARK: - Playback Controls

    func playPause() {
        executeCommand("""
        tell application id "\(spotifyBundleID)"
            playpause
        end tell
        """)
    }

    func nextTrack() {
        executeCommand("""
        tell application id "\(spotifyBundleID)"
            next track
        end tell
        """)
    }

    func previousTrack() {
        executeCommand("""
        tell application id "\(spotifyBundleID)"
            previous track
        end tell
        """)
    }

    func play() {
        executeCommand("""
        tell application id "\(spotifyBundleID)"
            play
        end tell
        """)
    }

    func pause() {
        executeCommand("""
        tell application id "\(spotifyBundleID)"
            pause
        end tell
        """)
    }

    // MARK: - Execute Commands

    private func executeCommand(_ source: String) {
        scriptQueue.async { [weak self] in
            guard let self else { return }

            var errorInfo: NSDictionary?

            guard let script = NSAppleScript(source: source) else {
                self.reportError(
                    "No se pudo crear el script de control."
                )
                return
            }

            _ = script.executeAndReturnError(&errorInfo)

            if let errorInfo {
                self.reportError(
                    "Error ejecutando comando de Spotify: \(errorInfo)"
                )
                return
            }

            // Actualizamos el estado después de ejecutar el comando.
            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.3
            ) { [weak self] in
                self?.refreshState()
            }
        }
    }

    func togglePlayPause() {
        playPause()
    }
    
    // MARK: - Artwork

    func fetchArtworkURL(spotifyURI: String) {
        guard
            let encodedURI = spotifyURI.addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed
            ),
            let url = URL(
                string: "https://open.spotify.com/oembed?url=\(encodedURI)"
            )
        else {
            return
        }

        URLSession.shared.dataTask(with: url) {
            [weak self] data, _, error in

            guard
                error == nil,
                let data,
                let response = try? JSONSerialization.jsonObject(
                    with: data
                ) as? [String: Any],
                let thumbnail = response["thumbnail_url"] as? String,
                let imageURL = URL(string: thumbnail)
            else {
                return
            }

            DispatchQueue.main.async {
                self?.artworkURL = imageURL
            }

            URLSession.shared.dataTask(with: imageURL) {
                [weak self] imageData, _, _ in

                guard
                    let imageData,
                    let image = NSImage(data: imageData)
                else {
                    return
                }

                let extractedColors = ImageColorExtractor.gradientColors(from: image) ?? []

                DispatchQueue.main.async {
                    self?.artworkImage = image
                    if !extractedColors.isEmpty {
                        self?.waveformColors = extractedColors
                    }
                }
            }.resume()

        }.resume()
    }
}
