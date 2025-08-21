import SwiftUI
import AppKit

// Custom window class that can always become key
class AlwaysKeyWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

@main
struct LMStudioChatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: AlwaysKeyWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up global hotkey for Alt+Space
        setupGlobalHotkey()
        
        // Create our custom window with proper transparency
        let frame = NSRect(x: 0, y: 0, width: 400, height: 600)
        
        // Create our custom window with titled style for proper transparency
        let customWindow = AlwaysKeyWindow(
            contentRect: frame,
            styleMask: [.titled, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Configure the custom window for complete transparency (handled by ContentView)
        customWindow.titlebarAppearsTransparent = true
        customWindow.titleVisibility = .hidden
        customWindow.backgroundColor = NSColor.clear
        customWindow.isOpaque = false
        customWindow.hasShadow = true
        customWindow.level = .normal
        customWindow.isMovableByWindowBackground = true
        
        // Window is transparent, ContentView provides the glass effect
        customWindow.alphaValue = 1.0
        customWindow.ignoresMouseEvents = false
        
        // Show close button only, hide minimize and zoom (maximize ruins the app)
        customWindow.standardWindowButton(.closeButton)?.isHidden = false
        customWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        customWindow.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Additional settings to ensure no title bar is visible
        customWindow.toolbar = nil
        
        // Create and set the ContentView
        let hostingController = NSHostingController(rootView: ContentView())
        customWindow.contentView = hostingController.view
        
        // Set constraints
        customWindow.minSize = NSSize(width: 350, height: 400)
        
        // Center the window on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - frame.width / 2
            let y = screenFrame.midY - frame.height / 2
            customWindow.setFrame(NSRect(x: x, y: y, width: frame.width, height: frame.height), display: true)
        }
        
        // Make it key and visible
        customWindow.makeKeyAndOrderFront(nil)
        
        self.window = customWindow
        customWindow.delegate = self
    }
    
    private func setupGlobalHotkey() {
        // Register Alt+Space hotkey for global monitoring
        _ = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.option) && event.keyCode == 49 { // Space key
                self.toggleWindow()
            }
        }
        
        // Also register for local monitoring (when app has focus)
        _ = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.option) && event.keyCode == 49 { // Space key
                self.toggleWindow()
                return nil // Consume the event
            }
            return event
        }
    }
    
    @objc private func toggleWindow() {
        DispatchQueue.main.async {
            if let window = self.window {
                if window.isVisible && NSApplication.shared.isActive {
                    // Hide the app
                    window.orderOut(nil)
                    NSApplication.shared.hide(nil)
                } else {
                    // Show and bring to front
                    NSApplication.shared.unhide(nil)
                    window.makeKeyAndOrderFront(nil)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    
                    // Bring window to front of all spaces
                    window.level = .floating
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        window.level = .normal
                    }
                }
            }
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
    
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        // Ensure minimum size constraints are respected
        let minSize = NSSize(width: 350, height: 400)
        return NSSize(
            width: max(frameSize.width, minSize.width),
            height: max(frameSize.height, minSize.height)
        )
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        // Window became key - this should help with focus
        if let window = notification.object as? NSWindow {
            print("Window became key: \(window)")
        }
    }
}
