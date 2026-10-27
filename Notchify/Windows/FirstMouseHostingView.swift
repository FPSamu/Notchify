import SwiftUI

/// Hosting view that handles clicks even when the app is not frontmost,
/// so the first click on the island works instead of only focusing the window.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
