import AppKit
import IOKit.pwr_mgt

/// Menu bar button that keeps the Mac awake.
///
/// Same effect as the button in the Claude app: it blocks idle system sleep. The display may
/// still turn off, and closing the lid still puts the Mac to sleep. macOS releases the assertion
/// by itself when the process ends, so a crash cannot leave the Mac awake forever.
final class KeepAwakeController: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var sleepAssertionID = IOPMAssertionID(0)
    private var isKeepingAwake = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let button = statusItem.button else {
            showError("Impossible de créer le bouton dans la barre de menus.")
            NSApp.terminate(nil)
            return
        }
        button.target = self
        button.action = #selector(handleButtonClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        refreshButton()
    }

    /// Left click toggles, right click opens the menu (the only way to quit the app).
    @objc private func handleButtonClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            toggleKeepAwake()
        }
    }

    @objc private func toggleKeepAwake() {
        if isKeepingAwake {
            stopKeepingAwake()
        } else {
            startKeepingAwake()
        }
        refreshButton()
    }

    private func startKeepingAwake() {
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            // ASCII only: pmset prints this name in MacRoman, so an accent shows up garbled.
            "KeepAwake: enabled from the menu bar" as CFString,
            &sleepAssertionID
        )
        guard result == kIOReturnSuccess else {
            showError("macOS a refusé de bloquer la veille (code \(result)). Le Mac peut s'endormir.")
            return
        }
        isKeepingAwake = true
    }

    private func stopKeepingAwake() {
        let result = IOPMAssertionRelease(sleepAssertionID)
        guard result == kIOReturnSuccess else {
            showError("macOS a refusé de rétablir la veille (code \(result)). Quitter KeepAwake la rétablit.")
            return
        }
        isKeepingAwake = false
    }

    private func refreshButton() {
        guard let button = statusItem.button else { return }
        let symbolName = isKeepingAwake ? "cup.and.saucer.fill" : "cup.and.saucer"
        let description = isKeepingAwake ? "Mac maintenu éveillé" : "Veille normale"
        let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)
        if isKeepingAwake {
            // contentTintColor had no visible effect in the menu bar: the color goes in the image itself.
            let orangeSymbol = symbol?.withSymbolConfiguration(.init(paletteColors: [.systemOrange]))
            orangeSymbol?.isTemplate = false
            button.image = orangeSymbol
        } else {
            button.image = symbol
        }
        button.toolTip = "\(description). Clic : basculer. Clic droit : menu."
    }

    private func showMenu() {
        guard let button = statusItem.button else { return }
        let menu = NSMenu()
        let stateItem = NSMenuItem(title: isKeepingAwake ? "Mac maintenu éveillé" : "Veille normale",
                                   action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quitter KeepAwake",
                                  action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        menu.addItem(quitItem)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    private func showError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "KeepAwake"
        alert.informativeText = message
        alert.runModal()
    }
}

let application = NSApplication.shared
let controller = KeepAwakeController()
application.delegate = controller
application.setActivationPolicy(.accessory)
application.run()
