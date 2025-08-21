import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var chatManager: ChatManager
    

    @AppStorage("temperature") private var temperature = 0.7
    @AppStorage("maxTokens") private var maxTokens = 1000

    @AppStorage("fontSize") private var fontSize = 14.0
    @AppStorage("windowOpacity") private var windowOpacity = 0.8
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { 
                    NSApplication.shared.keyWindow?.close()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Settings content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // General Section
                    settingsSection("General") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Font Size")
                                    .frame(width: 120, alignment: .leading)
                                Slider(value: $fontSize, in: 10...20, step: 1)
                                Text("\(Int(fontSize))pt")
                                    .frame(width: 40, alignment: .trailing)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Window Opacity")
                                    .frame(width: 120, alignment: .leading)
                                Slider(value: $windowOpacity, in: 0.3...1.0, step: 0.1)
                                Text("\(Int(windowOpacity * 100))%")
                                    .frame(width: 40, alignment: .trailing)
                                    .foregroundColor(.secondary)
                            }
                            

                        }
                    }
                    
                    // Model Section
                    settingsSection("AI Model") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Current Model")
                                    .frame(width: 120, alignment: .leading)
                                
                                Picker("Model", selection: $chatManager.selectedModel) {
                                    ForEach(chatManager.availableModels, id: \.id) { model in
                                        Text(model.displayName)
                                            .tag(model.id)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
                            HStack {
                                Text("Temperature")
                                    .frame(width: 120, alignment: .leading)
                                Slider(value: $temperature, in: 0.0...2.0, step: 0.1)
                                Text(String(format: "%.1f", temperature))
                                    .frame(width: 40, alignment: .trailing)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Max Tokens")
                                    .frame(width: 120, alignment: .leading)
                                Slider(value: Binding(
                                    get: { Double(maxTokens) },
                                    set: { maxTokens = Int($0) }
                                ), in: 100...4000, step: 100)
                                Text("\(maxTokens)")
                                    .frame(width: 40, alignment: .trailing)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Server Section
                    settingsSection("Server") {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Server URL")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                TextField("http://localhost:1234/v1", text: $chatManager.serverURL)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            HStack {
                                Button("Test Connection") {
                                    Task {
                                        await chatManager.refreshModels()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                
                                if chatManager.isLoadingModels {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else if chatManager.connectionStatus.isSuccess {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Connected")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                    }
                                } else if chatManager.connectionStatus.isFailure {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                        Text("Failed")
                                            .foregroundColor(.red)
                                            .font(.caption)
                                    }
                                }
                                
                                Spacer()
                                
                                Text("\(chatManager.availableModels.count) models")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            
                            if chatManager.connectionStatus.isFailure {
                                Text("Error: \(chatManager.connectionStatus.errorMessage ?? "Unknown error")")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                    }
                    
                    // About Section
                    settingsSection("About") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ChattrBox")
                                .font(.headline)
                            
                            Text("A lightweight AI chat client for macOS")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                            
                            HStack {
                                Text("Version 1.0.0")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                
                                Spacer()
                                
                                Button("GitHub") {
                                    NSWorkspace.shared.open(URL(string: "https://github.com")!)
                                }
                                .buttonStyle(.link)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 480, height: 560)
    }
    
    @ViewBuilder
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            content()
        }
        .padding(.vertical, 8)
    }
}