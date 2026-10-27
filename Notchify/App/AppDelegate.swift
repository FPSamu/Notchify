import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var islandPanel: DynamicIslandPanel!
    var statusItem: NSStatusItem!
    var isIslandEnabled: Bool = true // Variable de estado

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupPanel()
        setupMenuBar() // Inicia el icono en la barra superior

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateIslandVisibility),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        updateIslandVisibility()
    }

    private func setupPanel() {
        let initialFrame = NSRect(x: 0, y: 0, width: 400, height: 120)
        islandPanel = DynamicIslandPanel(contentRect: initialFrame)
        let hostingView = NSHostingView(rootView: DynamicIslandView())
        islandPanel.contentView = hostingView
        islandPanel.orderFront(nil)
    }
    
    private func setupMenuBar() {
        // Configura el elemento en la barra de estado del sistema
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Asigna un icono de SF Symbols (puedes cambiar "capsule.fill" por otro)
            button.image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Notchify")
        }
        
        let menu = NSMenu()
        
        // Botón de activación/desactivación
        let toggleItem = NSMenuItem(title: "Desactivar Dynamic Island", action: #selector(toggleIsland(_:)), keyEquivalent: "")
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Botón para cerrar la aplicación completamente
        let quitItem = NSMenuItem(title: "Salir de Notchify", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc func toggleIsland(_ sender: NSMenuItem) {
        isIslandEnabled.toggle()
        // Cambia el texto del menú según el estado actual
        sender.title = isIslandEnabled ? "Desactivar Dynamic Island" : "Activar Dynamic Island"
        updateIslandVisibility()
    }
    
    @objc func updateIslandVisibility() {
        guard isIslandEnabled else {
            islandPanel.animator().alphaValue = 0.0
            return
        }
        
        guard let screen = NSScreen.main else { return }
        
        let panelWidth: CGFloat = 400
        let panelHeight: CGFloat = 120
        let xPos = screen.frame.minX + (screen.frame.width - panelWidth) / 2
        
        // Detecta si la pantalla tiene notch (MacBook integrada vs Monitor externo)
        let hasNotch = screen.safeAreaInsets.top > 0
        
        let yPos: CGFloat
        if hasNotch {
            // Pegado al borde superior exacto en la MacBook
            yPos = screen.frame.maxY - panelHeight
        } else {
            // Flotando con separación en pantallas externas
            // (Ajusta el '10' si quieres que flote más o menos abajo)
            yPos = screen.frame.maxY - panelHeight - 10
        }
        
        islandPanel.setFrame(NSRect(x: xPos, y: yPos, width: panelWidth, height: panelHeight), display: true)
        islandPanel.animator().alphaValue = 1.0
    }
}
