import SwiftUI
import AppKit
import LaunchAtLogin
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject var chatManager: ChatManager
    @State private var selectedTab = "General"
    
    @AppStorage("playSounds") private var playSounds = true
    @AppStorage("fontSize") private var fontSize = 14.0
    @AppStorage("windowOpacity") private var windowOpacity = 0.8
    @AppStorage("temperature") private var temperature = 0.7
    @AppStorage("maxTokens") private var maxTokens = 1000

    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar with tabs
            HStack(spacing: 20) {
                // General tab
                Button(action: { selectedTab = "General" }) {
                    VStack(spacing: 4) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == "General" ? Color.accentColor : Color.clear)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "gear")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(selectedTab == "General" ? .white : .primary)
                        }
                        
                        Text("General")
                            .font(.system(size: 11))
                            .foregroundColor(selectedTab == "General" ? .primary : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 64)
                
                // Models tab
                Button(action: { selectedTab = "Models" }) {
                    VStack(spacing: 4) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == "Models" ? Color.accentColor : Color.clear)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "cpu")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(selectedTab == "Models" ? .white : .primary)
                        }
                        
                        Text("Models")
                            .font(.system(size: 11))
                            .foregroundColor(selectedTab == "Models" ? .primary : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 64)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Content based on selected tab
            if selectedTab == "General" {
                generalTabContent
            } else if selectedTab == "Models" {
                modelsTabContent
            }
        }
        .frame(width: 580, height: 480)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // General tab content
    private var generalTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Startup Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Startup:")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 120, alignment: .leading)
                        
                        LaunchAtLogin.Toggle()
                            .toggleStyle(.checkbox)
                    }
                }
                
                // Hotkey Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Hotkey:")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 120, alignment: .leading)
                        
                        KeyboardShortcuts.Recorder("", name: .toggleChattrBox)
                            .frame(maxWidth: 200, alignment: .leading)
                        
                        Spacer()
                    }
                }
                
                // Sounds Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Sounds:")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 120, alignment: .leading)
                        
                        Toggle("Play sounds", isOn: $playSounds)
                            .toggleStyle(.checkbox)
                    }
                }
                
                // Appearance Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Font Size:")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 120, alignment: .leading)
                        
                        Slider(value: $fontSize, in: 10...20, step: 1)
                            .frame(maxWidth: 200)
                        
                        Text("\(Int(fontSize))pt")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .leading)
                    }
                    
                    HStack {
                        Text("Window Opacity:")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 120, alignment: .leading)
                        
                        Slider(value: $windowOpacity, in: 0.3...1.0, step: 0.1)
                            .frame(maxWidth: 200)
                        
                        Text("\(Int(windowOpacity * 100))%")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // Models tab content
    private var modelsTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // AI Model Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("AI Settings")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("Model:")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 120, alignment: .leading)
                        
                        CustomModelPicker(
                            selectedModel: $chatManager.selectedModel,
                            models: sortedModels
                        )
                        .frame(maxWidth: 200, alignment: .leading)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("Temperature:")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 120, alignment: .leading)
                        
                        Slider(value: $temperature, in: 0.0...2.0, step: 0.1)
                            .frame(maxWidth: 200)
                        
                        Text(String(format: "%.1f", temperature))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .leading)
                    }
                    
                    HStack {
                        Text("Max Tokens:")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 120, alignment: .leading)
                        
                        Slider(value: Binding(
                            get: { Double(maxTokens) },
                            set: { maxTokens = Int($0) }
                        ), in: 100...4000, step: 100)
                            .frame(maxWidth: 200)
                        
                        Text("\(maxTokens)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .leading)
                    }
                }
                
                // Server Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Server Connection")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Server URL:")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 120, alignment: .leading)
                            
                            TextField("http://localhost:1234/v1", text: $chatManager.serverURL)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 300)
                        }
                        
                        HStack {
                            Text("")
                                .frame(width: 120, alignment: .leading)
                            
                            HStack(spacing: 12) {
                                Button("Test Connection") {
                                    Task {
                                        await chatManager.refreshModels()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                
                                if chatManager.isLoadingModels {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else if chatManager.connectionStatus.isSuccess {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Connected (\(chatManager.availableModels.count) models)")
                                            .foregroundColor(.green)
                                            .font(.system(size: 12))
                                    }
                                } else if chatManager.connectionStatus.isFailure {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                        Text("Connection failed")
                                            .foregroundColor(.red)
                                            .font(.system(size: 12))
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    /// Sorted models by parameter size, consistent with ContentView
    private var sortedModels: [ModelInfo] {
        return chatManager.availableModels.sorted { model1, model2 in
            let size1 = extractModelSize(from: model1.displayName)
            let size2 = extractModelSize(from: model2.displayName)
            
            // If both have sizes, sort by size ascending
            if let s1 = size1, let s2 = size2 {
                return s1 < s2
            }
            
            // Models with sizes come before models without sizes
            if size1 != nil && size2 == nil {
                return true
            }
            if size1 == nil && size2 != nil {
                return false
            }
            
            // If neither has a size, sort alphabetically
            return model1.displayName.localizedCompare(model2.displayName) == .orderedAscending
        }
    }
    
    /// Extracts the parameter size from a model name (e.g., "4B" from "llama-4B-instruct")
    /// Returns the size in billions as a Double for easier comparison
    private func extractModelSize(from modelName: String) -> Double? {
        let lowercased = modelName.lowercased()
        
        // Pattern to match sizes like "4b", "8b", "32b", "270b", etc.
        let pattern = #"(\d+(?:\.\d+)?)b"#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: lowercased, options: [], range: NSRange(lowercased.startIndex..., in: lowercased)),
           let range = Range(match.range(at: 1), in: lowercased) {
            let sizeString = String(lowercased[range])
            return Double(sizeString)
        }
        
        return nil
    }
}

// Custom Model Picker with solid black background and persistent scroll bars
struct CustomModelPicker: View {
    @Binding var selectedModel: String
    let models: [ModelInfo]
    
    @State private var isExpanded = false
    @State private var searchText = ""
    @State private var hoveredModelId: String?
    @Environment(\.colorScheme) var colorScheme
    
    private var filteredModels: [ModelInfo] {
        if searchText.isEmpty {
            return models
        } else {
            return models.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var selectedModelDisplayName: String {
        if let selected = models.first(where: { $0.id == selectedModel }) {
            return selected.displayName
        }
        return "Select a model..."
    }
    
    var body: some View {
        ZStack {
            // Button to toggle dropdown
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(selectedModelDisplayName)
                        .foregroundColor(selectedModel == "" ? .white.opacity(0.7) : .white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.9))
                        .overlay(
                            Capsule()
                                .stroke(Color.orange.opacity(0.3), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)
            
            // Dropdown content - positioned absolutely below the button
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        TextField("Choose an ambient chat model...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Rectangle()
                            .fill(colorScheme == .dark ? Color.black : Color.white)
                    )
                    
                    // Models list with persistent scroll bar
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredModels, id: \.id) { model in
                                Button(action: {
                                    selectedModel = model.id
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isExpanded = false
                                    }
                                    searchText = ""
                                    hoveredModelId = nil
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
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        // Checkmark for selected model
                                        if model.id == selectedModel {
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
                                                model.id == selectedModel ? 
                                                    Color.accentColor.opacity(0.1) :
                                                hoveredModelId == model.id ?
                                                    Color.primary.opacity(0.1) :
                                                    Color.clear
                                            )
                                    )
                                    .onHover { isHovered in
                                        DispatchQueue.main.async {
                                            hoveredModelId = isHovered ? model.id : nil
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                if model.id != filteredModels.last?.id {
                                    Divider()
                                        .padding(.leading, 48)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                    .background(
                        Rectangle()
                            .fill(colorScheme == .dark ? Color.black : Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(maxWidth: 300)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colorScheme == .dark ? Color.black : Color.white)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                )
                .offset(y: 35) // Position closer to the button
                .transition(.opacity.combined(with: .move(edge: .top)))
                .zIndex(9999)
            }
        }
    }
}



