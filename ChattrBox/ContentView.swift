import SwiftUI

struct ContentView: View {
    @StateObject private var chatManager = ChatManager()
    @State private var messageText = ""
    @State private var isFloating = true
    
    var body: some View {
        ZStack {
            // Glass background effect
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with controls
                headerView
                
                // Chat messages area
                chatMessagesView
                
                // Input area
                inputView
            }
        }
        .frame(width: 350, height: 500)
        .background(.clear)
        .onAppear {
            setupWindow()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("LM Studio Chat")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: toggleFloating) {
                    Image(systemName: isFloating ? "pin.fill" : "pin")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(isFloating ? "Disable Always on Top" : "Enable Always on Top")
                
                Button(action: clearChat) {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear Chat")
            }
            
            // Model picker
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Picker("Model", selection: $chatManager.selectedModel) {
                    if chatManager.availableModels.isEmpty {
                        Text("Loading models...")
                            .foregroundColor(.secondary)
                            .tag("")
                    } else {
                        ForEach(chatManager.availableModels, id: \.id) { model in
                            Text(model.displayName)
                                .tag(model.id)
                        }
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)
                .disabled(chatManager.availableModels.isEmpty)
                
                if chatManager.isLoadingModels {
                    ProgressView()
                        .scaleEffect(0.6)
                }
                
                Button(action: { Task { await chatManager.refreshModels() } }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Refresh Models")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private var chatMessagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(chatManager.messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
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
    }
    
    private var inputView: some View {
        VStack(spacing: 8) {
            if chatManager.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
            
            HStack {
                TextField("Type your message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .onSubmit {
                        sendMessage()
                    }
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(messageText.isEmpty ? .gray : .blue)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(messageText.isEmpty || chatManager.isLoading)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private func sendMessage() {
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
    
    private func toggleFloating() {
        isFloating.toggle()
        if let window = NSApplication.shared.windows.first {
            window.level = isFloating ? .floating : .normal
        }
    }
    
    private func setupWindow() {
        guard let window = NSApplication.shared.windows.first else { return }
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
    }
}
