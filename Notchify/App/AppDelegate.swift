import Cocoa
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var islandPanel: DynamicIslandPanel!
    var statusItem: NSStatusItem!
    var isIslandEnabled: Bool = true // Variable de estado

    // El panel se ajusta al contenido para no bloquear los clics de las ventanas de abajo.
    private let compactPanelSize = NSSize(width: 266, height: 38)
    private let expandedPanelSize = NSSize(width: 340, height: 175)
    private let islandState = IslandState()
    private var isIslandExpanded = false
    private var collapseWorkItem: DispatchWorkItem?
    private var pointerTimer: Timer?
    private var stateCancellable: AnyCancellable?

    private var currentPanelSize: NSSize {
        isIslandExpanded ? expandedPanelSize : compactPanelSize
    }

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
        let initialFrame = NSRect(origin: .zero, size: compactPanelSize)
        islandPanel = DynamicIslandPanel(contentRect: initialFrame)
        let hostingView = FirstMouseHostingView(rootView: DynamicIslandView(state: islandState))
        islandState.onWillExpand = { [weak self] in
            self?.collapseWorkItem?.cancel()
            self?.isIslandExpanded = true
            self?.updateIslandVisibility()
        }
        stateCancellable = islandState.$isExpanded
            .removeDuplicates()
            .sink { [weak self] expanded in
                self?.islandExpandedChanged(expanded)
            }
        hostingView.safeAreaRegions = []
        hostingView.sizingOptions = []
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
    
    private func islandExpandedChanged(_ expanded: Bool) {
        collapseWorkItem?.cancel()

        if expanded {
            startPointerMonitoring()
        } else {
            stopPointerMonitoring()
            // Esperamos a que termine la animación de colapso antes de reducir la ventana.
            let work = DispatchWorkItem { [weak self] in
                self?.isIslandExpanded = false
                self?.updateIslandVisibility()
            }
            collapseWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
        }
    }

    // El evento de hover de SwiftUI es poco fiable al cambiar el tamaño de la ventana,
    // así que mientras está expandida se comprueba la posición real del ratón.
    private func startPointerMonitoring() {
        pointerTimer?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.collapseIfPointerLeftIsland()
        }
        RunLoop.main.add(timer, forMode: .common)
        pointerTimer = timer
    }

    private func stopPointerMonitoring() {
        pointerTimer?.invalidate()
        pointerTimer = nil
    }

    private func collapseIfPointerLeftIsland() {
        guard islandState.isExpanded, let panel = islandPanel else { return }

        let size = IslandLayout.expandedSize
        let margin: CGFloat = 6
        let islandRect = NSRect(
            x: panel.frame.midX - size.width / 2,
            y: panel.frame.maxY - size.height,
            width: size.width,
            height: size.height
        ).insetBy(dx: -margin, dy: -margin)

        if !islandRect.contains(NSEvent.mouseLocation) {
            islandState.isExpanded = false
        }
    }

    @objc func updateIslandVisibility() {
        guard isIslandEnabled else {
            islandPanel.animator().alphaValue = 0.0
            return
        }
        
        guard let screen = NSScreen.main else { return }
        
        let panelWidth = currentPanelSize.width
        let panelHeight = currentPanelSize.height
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
