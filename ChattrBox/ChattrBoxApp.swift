import SwiftUI
import AppKit
import KeyboardShortcuts

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
struct ChattrBoxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Empty scene - we manage windows manually in AppDelegate
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: AlwaysKeyWindow?

    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    var settingsDelegate: SettingsWindowDelegate?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 Starting ChattrBox...")
        
        // Start with regular activation to ensure proper system registration
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        // Set up status bar FIRST while we're still regular
        setupStatusBar()
        
        // Give the status bar time to register properly
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
            // Switch to accessory mode after status bar is established
            NSApplication.shared.setActivationPolicy(.accessory)
            
            // Force status bar visibility after policy change
            if let button = self.statusItem?.button {
                button.needsDisplay = true
                button.window?.display()
                button.superview?.needsDisplay = true
            }
            
            print("✅ Menu bar setup completed with accessory policy")
        }
        
        // Set up global hotkey for Alt+Space
        setupGlobalHotkey()
        

        
        // Create our custom window with proper transparency
        let frame = NSRect(x: 0, y: 0, width: 400, height: 600)
        
        // Create borderless window for true spotlight-like experience
        let customWindow = AlwaysKeyWindow(
            contentRect: frame,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // Configure the window as a floating, always-on-top overlay
        customWindow.backgroundColor = NSColor.clear
        customWindow.isOpaque = false
        customWindow.hasShadow = true
        customWindow.level = .floating // Always on top
        customWindow.isMovableByWindowBackground = true
        customWindow.collectionBehavior = [.canJoinAllSpaces, .stationary] // Appears on all spaces
        
        // Window is completely transparent, ContentView provides all styling
        customWindow.alphaValue = 1.0
        customWindow.ignoresMouseEvents = false
        
        // Hide from mission control and dock
        customWindow.collectionBehavior.insert(.transient)
        customWindow.collectionBehavior.insert(.ignoresCycle)
        
        // Create and set the ContentView with AppDelegate reference
        let contentView = ContentView(appDelegate: self)
        let hostingController = NSHostingController(rootView: contentView)
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
        
        // Start completely hidden - window only appears when Alt+Space is pressed
        customWindow.orderOut(nil) // Ensure it starts hidden
        customWindow.isReleasedWhenClosed = false // Prevent window from being deallocated
        
        // Additional hiding to ensure no window appears
        customWindow.alphaValue = 0.0
        
        self.window = customWindow
        customWindow.delegate = self
        
        print("✅ Window created and stored - ready for toggle")
    }
    

    
    private func setupStatusBar() {
        print("🔧 Setting up status bar...")
        
        // Create the status bar item with square length for consistency
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        print("🔍 Status item created: \(String(describing: statusItem))")
        
        guard let statusItem = statusItem, let button = statusItem.button else {
            print("❌ Failed to get status bar button")
            return
        }
        
        // Configure the button with explicit settings
        button.image = NSImage(systemSymbolName: "message.circle.fill", accessibilityDescription: "ChattrBox")
        
        // Ensure image is properly configured
        if let image = button.image {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true // This helps with dark/light mode
        }
        
        button.action = #selector(statusBarClicked)
        button.target = self
        button.toolTip = "ChattrBox - Alt+Space to toggle"
        
        // Enable both left and right click
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        // Ensure visibility
        button.isEnabled = true
        button.isHidden = false
        button.alphaValue = 1.0
        
        // Create the context menu for right-click
        setupContextMenu()
        
        // Force display immediately
        button.needsDisplay = true
        
        print("✅ Status bar setup complete")
        
        // Additional refresh to ensure visibility
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            button.needsDisplay = true
            if let window = button.window {
                window.display()
            }
            print("🔄 Status bar display refreshed")
        }
    }
    
    private func setupContextMenu() {
        let menu = NSMenu()
        
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit ChattrBox", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    private func setupGlobalHotkey() {
        // Setup keyboard shortcut listener using KeyboardShortcuts package
        KeyboardShortcuts.onKeyUp(for: .toggleChattrBox) { [weak self] in
            DispatchQueue.main.async {
                self?.toggleWindow()
            }
        }
        
        // Also register for local monitoring (when app has focus) for Escape key
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Hide on Escape key (standard for spotlight-like apps)
            if event.keyCode == 53 { // Escape key
                if let window = self?.window, window.isVisible {
                    self?.hideWindow()
                    return nil // Consume the event
                }
            }
            return event
        }
        
        print("✅ Global hotkey (Alt+Space) and Escape monitoring registered")
    }
    
    @objc func statusBarClicked(_ sender: NSStatusBarButton) {
        // Check for right-click
        if let event = NSApp.currentEvent {
            if event.type == .rightMouseUp {
                // Right-click shows the menu automatically (handled by statusItem.menu)
                return
            }
        }
        
        // Left-click toggles the window
        toggleWindow()
    }
    
    @objc func toggleWindow() {
        DispatchQueue.main.async {
            guard let window = self.window else {
                print("❌ No window available for toggle")
                return
            }
            
            print("🔄 Toggling window - currently visible: \(window.isVisible)")
            
            if window.isVisible {
                self.hideWindow()
            } else {
                self.showWindow()
            }
        }
    }
    
    @MainActor @objc func openSettings() {
        print("📝 Opening ChattrBox Settings")
        
        // Check if settings window already exists and is valid
        if let existingWindow = settingsWindow {
            print("🔄 Using existing settings window")
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        print("🏗️ Creating new settings window...")
        
        // Create new settings window
        let settingsView = SettingsView(chatManager: ChatManager.shared)
        let hostingController = NSHostingController(rootView: settingsView)
        
        let newSettingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        newSettingsWindow.title = "ChattrBox Settings"
        newSettingsWindow.contentViewController = hostingController
        newSettingsWindow.center()
        newSettingsWindow.level = .normal
        newSettingsWindow.isReleasedWhenClosed = false
        
        // Set up delegate to handle window closing
        self.settingsDelegate = SettingsWindowDelegate(appDelegate: self)
        newSettingsWindow.delegate = self.settingsDelegate
        
        // Store reference to prevent deallocation
        self.settingsWindow = newSettingsWindow
        
        // Just show the window - it will appear in front by default
        newSettingsWindow.makeKeyAndOrderFront(nil)
        
        print("✅ Settings window created and visible")
    }
    
    @objc func quitApp() {
        print("👋 Quitting ChattrBox")
        NSApplication.shared.terminate(nil)
    }
    

    
    private func hideWindow() {
        guard let window = self.window else { return }
        
        print("👻 Hiding window")
        
        // Hide with smooth animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 0.0
        }, completionHandler: {
            window.orderOut(nil)
            window.alphaValue = 1.0 // Reset for next show
            print("✅ Window hidden")
        })
    }
    
    private func showWindow() {
        guard let window = self.window else { return }
        
        print("👁️ Showing window")
        
        // Show with smooth animation
        window.alphaValue = 0.0
        window.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 1.0
        })
        
        // Activate app and focus window
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        print("✅ Window shown")
    }
}

// Separate delegate for settings window to handle cleanup
class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    weak var appDelegate: AppDelegate?
    
    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }
    
    func windowWillClose(_ notification: Notification) {
        // Clean up the references when window is closed
        appDelegate?.settingsWindow = nil
        appDelegate?.settingsDelegate = nil
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hideWindow()
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
    
    func windowDidResignKey(_ notification: Notification) {
        // Don't auto-hide on focus loss - only hide on Alt+Space or Escape
        // This prevents the window from disappearing when other shortcuts are used
        print("Window resigned key, but staying visible")
    }
}
