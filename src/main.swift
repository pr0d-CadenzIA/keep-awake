import AppKit
import IOKit.pwr_mgt

/// Menu bar button that keeps the Mac awake.
///
/// By default it blocks both idle system sleep and display sleep. The right-click menu can let the
/// display turn off while the Mac keeps running, which is the effect of the button in the Claude app.
/// Closing the lid still puts the Mac to sleep. macOS releases the assertion by itself when the
/// process ends, so a crash cannot leave the Mac awake forever.
final class KeepAwakeController: NSObject, NSApplicationDelegate {
    private static let keepsDisplayOnKey = "keepsDisplayOn"

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var sleepAssertionID = IOPMAssertionID(0)
    private var displayAssertionID: IOPMAssertionID?
    private var isKeepingAwake = false
    private var keepsDisplayOn =
        UserDefaults.standard.object(forKey: KeepAwakeController.keepsDisplayOnKey) as? Bool ?? true

    private var stateDescription: String {
        guard isKeepingAwake else { return "Veille normale" }
        return displayAssertionID != nil ? "Mac éveillé, écran allumé" : "Mac éveillé, écran libre de s'éteindre"
    }

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

    /// The system assertion is never touched here, so the Mac stays protected whatever the choice.
    @objc private func toggleKeepDisplayOn() {
        let newChoice = !keepsDisplayOn
        if isKeepingAwake {
            if newChoice {
                guard let assertionID = createAssertion(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString)
                else { return }
                displayAssertionID = assertionID
            } else if !releaseDisplayAssertion() {
                return
            }
        }
        keepsDisplayOn = newChoice
        UserDefaults.standard.set(newChoice, forKey: KeepAwakeController.keepsDisplayOnKey)
        refreshButton()
    }

    /// Holds both assertions when the display stays on: a display assertion alone does not count
    /// as blocking system sleep (`pmset -g` does not list it under `sleep`).
    private func startKeepingAwake() {
        guard let assertionID = createAssertion(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString)
        else { return }
        sleepAssertionID = assertionID
        isKeepingAwake = true
        if keepsDisplayOn {
            displayAssertionID = createAssertion(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString)
        }
    }

    private func createAssertion(_ assertionType: CFString) -> IOPMAssertionID? {
        var assertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            assertionType,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            // ASCII only: pmset prints this name in MacRoman, so an accent shows up garbled.
            "KeepAwake: enabled from the menu bar" as CFString,
            &assertionID
        )
        guard result == kIOReturnSuccess else {
            showError("macOS a refusé ce blocage (code \(result)). Le Mac ou l'écran peut s'endormir.")
            return nil
        }
        return assertionID
    }

    /// Returns false if macOS refused, in which case the assertion is still held.
    private func releaseDisplayAssertion() -> Bool {
        guard let assertionID = displayAssertionID else { return true }
        let result = IOPMAssertionRelease(assertionID)
        guard result == kIOReturnSuccess else {
            showError("macOS a refusé de laisser l'écran s'éteindre (code \(result)). Quitter KeepAwake le permet.")
            return false
        }
        displayAssertionID = nil
        return true
    }

    private func stopKeepingAwake() {
        guard releaseDisplayAssertion() else { return }
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
        let description = stateDescription
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
        let stateItem = NSMenuItem(title: stateDescription, action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(.separator())
        let displayItem = NSMenuItem(title: "Garder l'écran allumé",
                                     action: #selector(toggleKeepDisplayOn), keyEquivalent: "")
        displayItem.target = self
        displayItem.state = keepsDisplayOn ? .on : .off
        menu.addItem(displayItem)
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
