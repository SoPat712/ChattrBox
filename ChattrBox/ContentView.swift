import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var chatManager = ChatManager()
    @State private var messageText = ""
    @State private var showingModelPicker = false
    @State private var settingsWindow: NSWindow?
    @State private var modelSearchText = ""
    @State private var focusTimer: Timer?
    @State private var windowObserver: Any?
    @State private var cursorVisible = true
    @AppStorage("fontSize") private var fontSize = 14.0
    @AppStorage("windowOpacity") private var windowOpacity = 0.8
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Full-width title bar with native controls + app controls
            titleBarView
            
            // Chat messages area
            chatMessagesView
            
            // Input area
            inputView
        }
        .frame(
            minWidth: 350,
            idealWidth: 400,
            maxWidth: .infinity,
            minHeight: 400,
            idealHeight: 600,
            maxHeight: .infinity
        )

        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(windowOpacity) // CORRECT: 100% = solid glass, 0% = clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            setupWindow()
            setupAggressiveFocusManagement()
            // Start cursor animation
            startCursorAnimation()
        }
        .onDisappear {
            focusTimer?.invalidate()
            if let observer = windowObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    private var titleBarView: some View {
        HStack(spacing: 16) {
            // Left side - native window controls area (invisible, just for spacing)
            Color.clear.frame(width: 20, height: 1) // Reduced space for close button only
            
            // Model picker
            Button(action: { showingModelPicker.toggle() }) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(currentModelDisplayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if !chatManager.isLoadingModels {
                        Image(systemName: showingModelPicker ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.orange.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .help("Select AI model")
            
            Spacer()
            
            // Right side action buttons
            HStack(spacing: 8) {
                // Clear chat button
                Button(action: clearChat) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear Chat")
                
                // Settings button
                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
        }
        .frame(height: 32)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private var currentModelDisplayName: String {
        if chatManager.availableModels.isEmpty {
            return "Loading..."
        } else if let selectedModel = chatManager.availableModels.first(where: { $0.id == chatManager.selectedModel }) {
            return selectedModel.displayName
        } else {
            return "Select Model"
        }
    }
    
    private var chatMessagesView: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(chatManager.messages) { message in
                            SimpleChatBubble(
                                message: message,
                                onRegenerate: message.isUser ? nil : { regenerateResponse(for: message) },
                                fontSize: fontSize,
                                showCursor: !message.isUser && chatManager.isLoading && message.id == chatManager.messages.last?.id,
                                cursorVisible: cursorVisible
                            )
                            .id(message.id)
                        }
                        
                        // Debug info
                        if chatManager.messages.isEmpty {
                            Text("No messages yet. Start a conversation!")
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                    .padding()
                }
                .onChange(of: chatManager.messages.count) {
                    if let lastMessage = chatManager.messages.last {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Model picker overlay with animations
            if showingModelPicker {
                modelPickerOverlay
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.8, anchor: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.8, anchor: .top))
                    ))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showingModelPicker)
        .onTapGesture {
            // Only focus text field if model picker is not open
            if !showingModelPicker {
                isTextFieldFocused = true
            }
        }
        .onChange(of: showingModelPicker) { _, newValue in
            // When model picker opens, remove focus from text field
            if newValue {
                isTextFieldFocused = false
            }
        }
    }
    
    private var modelPickerOverlay: some View {
        VStack(spacing: 0) {
            // Position the overlay directly below the model picker button
            HStack {
                // Align with the model picker button position
                HStack {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        // Search field
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            
                            TextField("Choose a chat model...", text: $modelSearchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(NSColor.controlBackgroundColor))
                        
                        Divider()
                        
                        // Model list
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredModels, id: \.id) { model in
                                    modelRow(for: model)
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                    }
                    .frame(width: 300) // Fixed width to center around the model display
                    .background(
                        VisualEffectView(material: .menu, blendingMode: .behindWindow)
                            .cornerRadius(12)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
                    
                    Spacer()
                }
                .frame(maxWidth: 400) // Constrain the width to keep it centered
            }
            .padding(.top, 8) // Small gap from the model picker button
            
            Spacer()
        }
        .background(Color.black.opacity(0.1))
        .onTapGesture {
            showingModelPicker = false
        }
    }
    
    private var filteredModels: [ModelInfo] {
        if modelSearchText.isEmpty {
            return chatManager.availableModels
        } else {
            return chatManager.availableModels.filter { model in
                model.displayName.localizedCaseInsensitiveContains(modelSearchText)
            }
        }
    }
    
    private func modelRow(for model: ModelInfo) -> some View {
        ModelRowView(
            model: model,
            isSelected: chatManager.selectedModel == model.id,
            onTap: {
                chatManager.selectedModel = model.id
                showingModelPicker = false
                modelSearchText = ""
            }
        )
    }
    
    private var textInputField: some View {
        // Simple, clean text entry like iMessage
        TextField("Ask me anything...", text: $messageText, axis: .vertical)
            .font(.system(size: fontSize))
            .lineLimit(1...4)
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 300) // Limit width to force proper wrapping
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.2), lineWidth: 0.5)
                    )
            )
            .focused($isTextFieldFocused)
            .onKeyPress(.return) {
                if NSEvent.modifierFlags.contains(.shift) {
                    // Shift+Enter: insert new line
                    messageText += "\n"
                    return .handled
                } else {
                    // Enter: send message
                    sendMessage()
                    return .handled
                }
            }
    }
    
    private var inputView: some View {
        VStack(spacing: 0) {
            // Show pulsating dot when waiting for response
            if chatManager.isLoading && !chatManager.isStreaming {
                HStack {
                    Text("Thinking...")
                        .font(.system(size: fontSize - 2))
                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "0d0d0d"))
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 4) // Reduced from 8 to 4
            }
            
            HStack(spacing: 0) {
                // Text input field with placeholder
                textInputField
                    .padding(.horizontal, 16)
                
                // Send button (only show when there's text or loading)
                if !messageText.isEmpty || chatManager.isLoading {
                    Button(action: sendMessage) {
                        Image(systemName: chatManager.isLoading ? "stop.circle.fill" : "arrow.up.circle.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(chatManager.isLoading ? .red : .blue)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 44, height: 44)
                    .padding(.leading, 8)
                    .padding(.trailing, 20)
                    .help(chatManager.isLoading ? "Stop generation" : "Send message")
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale).animation(.easeInOut(duration: 0.2).delay(0.15)),
                        removal: .opacity.combined(with: .scale).animation(.easeInOut(duration: 0.15))
                    ))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: !messageText.isEmpty)
            
            // No cursor in input field - cursor appears in AI response bubble instead
        }
        .padding(.bottom, 16)
        .onTapGesture {
            // Ensure text field gets focus when tapping on input area
            isTextFieldFocused = true
        }
    }
    
    @FocusState private var isTextFieldFocused: Bool
    
    private func sendMessage() {
        if chatManager.isLoading {
            chatManager.stopGeneration()
            return
        }
        
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let message = messageText
        messageText = ""
        
        Task {
            await chatManager.sendMessage(message)
        }
    }
    
    private func clearChat() {
        chatManager.clearMessages()
    }
    
    private func regenerateResponse(for message: ChatMessage) {
        // Find the user message that preceded this AI response
        if let messageIndex = chatManager.messages.firstIndex(where: { $0.id == message.id }),
           messageIndex > 0 {
            let userMessage = chatManager.messages[messageIndex - 1]
            if userMessage.isUser {
                // Remove the current AI response and regenerate
                chatManager.messages.remove(at: messageIndex)
                Task {
                    await chatManager.sendMessage(userMessage.content)
                }
            }
        }
    }
    
    private func openSettings() {
        // Close existing settings window if it exists
        settingsWindow?.close()
        
        // Create new settings window
        let settingsView = SettingsView(chatManager: chatManager)
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Settings"
        window.contentViewController = hostingController
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        
        // Style the window similar to Safari's settings
        window.titlebarAppearsTransparent = false
        window.backgroundColor = NSColor.windowBackgroundColor
        
        // Add observer for when settings window closes to restore main window focus
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            // Restore focus to main window when settings closes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let mainWindow = NSApplication.shared.windows.first(where: { $0 != window }) {
                    mainWindow.makeKeyAndOrderFront(nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.isTextFieldFocused = true
                    }
                }
            }
        }
        
        settingsWindow = window
    }
    
    private func startCursorAnimation() {
        // Start with cursor visible
        cursorVisible = true
        
        // Create a repeating timer for the flashing effect
        Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.cursorVisible.toggle()
                }
            }
        }
    }
    
    private func setupAggressiveFocusManagement() {
        // Force focus immediately (but only if model picker is closed)
        DispatchQueue.main.async {
            if !self.showingModelPicker {
                self.isTextFieldFocused = true
            }
        }
        
        // Simplified but extremely aggressive timer - check every 0.01 seconds!
        focusTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            // If app is active and we're not in settings, force focus
            if NSApplication.shared.isActive {
                if let keyWindow = NSApplication.shared.keyWindow {
                    // Only force focus if we're in the main window (not settings) AND model picker is closed
                    if !keyWindow.title.contains("Settings") && keyWindow.title != "Settings" {
                        if !self.isTextFieldFocused && !self.showingModelPicker {
                            self.isTextFieldFocused = true
                        }
                    }
                }
            }
        }
        
        // Single window observer for key window changes
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let window = notification.object as? NSWindow,
               !window.title.contains("Settings") && window.title != "Settings" {
                // Main window became key - force focus (but only if model picker is closed)
                DispatchQueue.main.async {
                    if !self.showingModelPicker {
                        self.isTextFieldFocused = true
                    }
                }
            }
        }
        
        // App activation observer
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            // App became active - force focus after a tiny delay (but only if model picker is closed)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                if !self.showingModelPicker {
                    self.isTextFieldFocused = true
                }
            }
        }
    }

    private func setupWindow() {
        // Use a safer approach with delayed execution
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first else { 
                print("No window found")
                return 
            }
            
            // Window configuration is now handled by AppDelegate with AlwaysKeyWindow
            print("Setting up window focus for: \(window)")
            
            // Force window to become key immediately
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            
            // Set window constraints - make it resizable
            window.minSize = NSSize(width: 350, height: 400)
            window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            
            // Center the window on screen
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let windowWidth: CGFloat = 400
                let windowHeight: CGFloat = 600
                let x = screenFrame.midX - windowWidth / 2
                let y = screenFrame.midY - windowHeight / 2
                
                let frame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
                window.setFrame(frame, display: true)
            }
            
            // Focus the text field when window appears - multiple attempts
            DispatchQueue.main.async {
                self.isTextFieldFocused = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isTextFieldFocused = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isTextFieldFocused = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isTextFieldFocused = true
            }
            
            // Add window focus observer to restore text field focus
            NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { _ in
                // Multiple immediate focus attempts
                DispatchQueue.main.async {
                    self.isTextFieldFocused = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.isTextFieldFocused = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isTextFieldFocused = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.isTextFieldFocused = true
                }
            }
            
            // Also observe app activation to restore focus
            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                // Aggressive focus restoration on app activation
                DispatchQueue.main.async {
                    self.isTextFieldFocused = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isTextFieldFocused = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.isTextFieldFocused = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isTextFieldFocused = true
                }
            }
        }
    }
}

struct ModelRowView: View {
    let model: ModelInfo
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Model icon based on name
            Image(systemName: modelIcon(for: model.displayName))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 20)
            
            Text(model.displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Group {
                if isSelected {
                    Color.blue.opacity(0.1)
                } else if isHovering {
                    Color.secondary.opacity(0.1)
                } else {
                    Color.clear
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
    
    private func modelIcon(for modelName: String) -> String {
        let name = modelName.lowercased()
        if name.contains("claude") {
            return "brain.head.profile"
        } else if name.contains("gemini") {
            return "sparkles"
        } else if name.contains("grok") {
            return "bolt"
        } else if name.contains("gpt") || name.contains("o1") || name.contains("o3") {
            return "circle.grid.3x3"
        } else {
            return "cpu"
        }
    }
}


