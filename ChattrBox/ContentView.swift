import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject private var chatManager = ChatManager.shared
    @State private var messageText = ""
    @State private var showingModelPicker = false

    @State private var shouldAutoScroll = true // Track if we should auto-scroll
    @State private var modelSearchText = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var cursorVisible = true
    @AppStorage("fontSize") private var fontSize = 14.0
    @AppStorage("windowOpacity") private var windowOpacity = 0.8
    @Environment(\.colorScheme) var colorScheme
    
    // Reference to AppDelegate
    weak var appDelegate: AppDelegate?
    
    // Initializer to accept AppDelegate reference
    init(appDelegate: AppDelegate? = nil) {
        self.appDelegate = appDelegate
    }
    
    var body: some View {
        ZStack {
        VStack(spacing: 0) {
            // Full-width title bar with native controls + app controls
            titleBarView
            
            // Chat messages area
            chatMessagesView
            
            // Input area
            inputView
            }
            
            // Model picker overlay
            modelPickerOverlay
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
                .opacity(windowOpacity)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            startCursorAnimation()
            
            // Ensure text field gets focus when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isTextFieldFocused = true
            }
        }
        .onDisappear {
            // Cleanup when view disappears
        }
    }
    
    private var titleBarView: some View {
        HStack(spacing: 16) {
            // Left side - close button
            Button(action: {
                if let window = NSApp.keyWindow {
                    window.close()
                }
            }) {
                ZStack {
                    // Simple subtle background
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                        )
                        .frame(width: 20, height: 20)
                    
                    // Simple icon
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .help("Close window")
            .scaleEffect(1.0)
            .animation(.easeInOut(duration: 0.15), value: colorScheme)
            
            Spacer()
            
            // Model picker - centered
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
                        .fill(Color.orange.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .help("Select AI model")
            
            Spacer()
            
            // Right side action buttons
            HStack(spacing: 8) {
                // Clear chat button - only show when there are messages
                if !chatManager.messages.isEmpty {
                    Button(action: clearChat) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear chat")
                }
                
                // Settings button
                Button(action: {
                    print("🔘 Settings button clicked in ContentView")
                    openSettings()
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var chatMessagesView: some View {
            ScrollViewReader { proxy in
                ScrollView {
                LazyVStack(spacing: 12) {
                        ForEach(chatManager.messages) { message in
                        SimpleChatBubble(
                            message: message, 
                            onRegenerate: !message.isUser ? { 
                                Task { 
                                    await chatManager.regenerateResponse(for: message.id) 
                                } 
                            } : nil,
                            onVersionChange: !message.isUser ? { versionIndex in
                                chatManager.navigateToVersion(messageId: message.id, versionIndex: versionIndex)
                            } : nil,
                            fontSize: fontSize
                        )
                            .id(message.id)
                        }
                        
                    // Loading indicator
                    if chatManager.isLoading && !chatManager.isStreaming {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 20, height: 20)
                            
                            Text("Thinking...")
                                .font(.system(size: fontSize - 2))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.secondary.opacity(0.1))
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            // Auto-scroll disabled - let user control scrolling freely
            // Drag gesture removed - no more auto-scroll detection
            // Tap gesture removed - no more auto-scroll interference
        }
    }
    
    private var modelPickerOverlay: some View {
        VStack(spacing: 0) {
            // Spacer to push the picker right below the title bar
            Spacer()
                .frame(height: 60) // Height of title bar area
            
            HStack {
                Spacer()
                
                if showingModelPicker {
                    modelPickerContent
                }
                
                Spacer()
            }
            
            Spacer() // Fill remaining space
        }
    }
    
    private var modelPickerContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                TextField("Choose a chat model...", text: $modelSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Rectangle()
                    .fill(Color(red: 28/255, green: 25/255, blue: 23/255))
            )
            
            // Models list with persistent scroll bar
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sortedModels, id: \.id) { model in
                        Button(action: {
                            chatManager.selectedModel = model.id
                            showingModelPicker = false
                            modelSearchText = ""
                        }) {
                            HStack {
                                // Model icon (first letter)
                                ZStack {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.2))
                                        .frame(width: 24, height: 24)
                                    
                                    Text(String(model.displayName.prefix(1)))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.accentColor)
                                }
                                
                                Text(model.displayName)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                // Checkmark for selected model
                                if model.id == chatManager.selectedModel {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Rectangle()
                                    .fill(
                                        model.id == chatManager.selectedModel ? 
                                            Color.accentColor.opacity(0.1) :
                                            Color.clear
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        
                        if model.id != sortedModels.last?.id {
                            Divider()
                                .padding(.leading, 48)
                                .opacity(0.3)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
            .background(
                Rectangle()
                    .fill(Color(red: 28/255, green: 25/255, blue: 23/255))
            )
            .scrollIndicators(.visible)
        }
        .frame(width: 250)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 28/255, green: 25/255, blue: 23/255))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .zIndex(9999)
    }
    
    private var inputView: some View {
        HStack(spacing: 12) {
            // Text input field
            TextField("Ask me anything...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: fontSize))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                    .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.primary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.2), lineWidth: 0.5)
                        )
                )
                .focused($isTextFieldFocused)
                .onSubmit {
                    sendMessage()
                }
                .onKeyPress(.return) {
                    sendMessage()
                    return .handled
                }
                .onAppear {
                    // Ensure the text field can receive keyboard shortcuts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isTextFieldFocused = true
                    }
                }
                .onTapGesture {
                    // Ensure focus when tapping the text field
                    isTextFieldFocused = true
                }

            
            // Send/Stop button
            Button(action: {
                if chatManager.isLoading && !chatManager.isStreaming {
                    chatManager.stopGeneration()
                } else {
                    sendMessage()
                }
            }) {
                Image(systemName: chatManager.isLoading ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(chatManager.isLoading ? .red : .blue)
            }
            .buttonStyle(.plain)
            .disabled(messageText.isEmpty && !chatManager.isLoading)
            .help(chatManager.isLoading ? "Stop generation" : "Send message")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .animation(.easeInOut(duration: 0.3), value: !messageText.isEmpty)
    }
    
    // MARK: - Computed Properties
    
    private var currentModelDisplayName: String {
        if chatManager.isLoadingModels {
            return "Loading..."
        }
        
        if let selectedModel = chatManager.availableModels.first(where: { $0.id == chatManager.selectedModel }) {
            return selectedModel.displayName
        }
        
        return "Select Model"
    }
    
    private var models: [ModelInfo] {
        if modelSearchText.isEmpty {
            return chatManager.availableModels
        } else {
            return chatManager.availableModels.filter { model in
                model.displayName.localizedCaseInsensitiveContains(modelSearchText)
            }
        }
    }
    
    private var sortedModels: [ModelInfo] {
        return models.sorted { model1, model2 in
            // Extract size information from model names
            let size1 = extractModelSize(from: model1.displayName)
            let size2 = extractModelSize(from: model2.displayName)
            
            // If both have sizes, sort numerically
            if let size1 = size1, let size2 = size2 {
                return size1 < size2
            }
            
            // If only one has size, prioritize the one with size
            if size1 != nil && size2 == nil {
                return true
            }
            if size1 == nil && size2 != nil {
                return false
            }
            
            // If neither has size, sort alphabetically
            return model1.displayName < model2.displayName
        }
    }
    
    // MARK: - Methods
    
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
    
    private func openSettings() {
        // Use the direct AppDelegate reference
        if let appDelegate = appDelegate {
            appDelegate.openSettings()
        } else {
            print("❌ Could not find AppDelegate")
        }
    }
    

    

    

    

    
    private func startCursorAnimation() {
        cursorVisible = true
        
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                    self.cursorVisible.toggle()
            }
        }
    }
    
    private func extractModelSize(from modelName: String) -> Int? {
        // Look for patterns like "7B", "13B", "70B", etc.
        let pattern = #"(\d+)B"#
        let regex = try? NSRegularExpression(pattern: pattern)
        
        if let match = regex?.firstMatch(in: modelName, range: NSRange(modelName.startIndex..., in: modelName)) {
            let range = Range(match.range(at: 1), in: modelName)!
            let sizeString = String(modelName[range])
            return Int(sizeString)
        }
        
        return nil
    }
}

#Preview {
    ContentView()
}


