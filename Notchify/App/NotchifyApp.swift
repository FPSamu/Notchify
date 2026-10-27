import SwiftUI

@main
struct NotchifyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Settings evita que SwiftUI cree una ventana estándar con barra de título
        Settings {
            EmptyView()
        }
    }
}
