import SwiftUI
import Foundation

enum ConnectionStatus {
    case unknown
    case connecting
    case success
    case failure(String)
    
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
    
    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
    
    var errorMessage: String? {
        if case .failure(let message) = self { return message }
        return nil
    }
}

@MainActor
class ChatManager: ObservableObject {
    static let shared = ChatManager()
    
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var isStreaming = false
    @Published var availableModels: [ModelInfo] = []
    @Published var selectedModel = ""
    @Published var isLoadingModels = false
    @Published var connectionStatus: ConnectionStatus = .unknown
    @Published var hasTestedConnection: Bool = false
    
    @AppStorage("serverURL") var serverURL = "http://localhost:1234/v1"
    private var currentTask: Task<Void, Never>?
    
    init() {
        // Reset connection status on init
        connectionStatus = .unknown
        hasTestedConnection = false
        
        // Automatically load models on startup
        Task {
            await loadAvailableModels()
        }
    }
    
    func sendMessage(_ content: String) async {
        // Cancel any existing task
        currentTask?.cancel()
        
        print("Sending message: \(content)")
        
        // Add user message
        let userMessage = ChatMessage(content: content, isUser: true)
        messages.append(userMessage)
        print("Added user message, total messages: \(messages.count)")
        
        isLoading = true
        isStreaming = true
        
        // Create AI message for streaming
        let aiMessageId = UUID()
        let aiMessage = ChatMessage(id: aiMessageId, content: "", isUser: false)
        messages.append(aiMessage)
        print("Added AI message with ID: \(aiMessageId), total messages: \(messages.count)")
        
        currentTask = Task {
            var streamingContent = ""
            
            do {
                try await streamLMStudio(messages: Array(messages.dropLast())) { chunk in
                    Task { @MainActor in
                        print("🔄 Processing chunk: '\(chunk)' (length: \(chunk.count))")
                        streamingContent += chunk
                        print("📝 Updated streaming content: '\(streamingContent)' (length: \(streamingContent.count))")
                        
                        // Update the message with streaming content
                        if let lastIndex = self.messages.firstIndex(where: { $0.id == aiMessageId }) {
                            // Update the existing message's content instead of creating a new one
                            self.messages[lastIndex].content = streamingContent
                            // Ensure the versions array is properly updated
                            if self.messages[lastIndex].versions.isEmpty {
                                self.messages[lastIndex].versions = [streamingContent]
                            } else {
                                self.messages[lastIndex].versions[0] = streamingContent
                            }
                            // Set the current version to show the streaming content
                            self.messages[lastIndex].currentVersionIndex = 0
                            print("✅ Updated AI message, content length: \(streamingContent.count)")
                            print("🔍 Message content preview: '\(String(streamingContent.prefix(100)))...'")
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    // Replace the AI message with error
                    if let lastIndex = messages.firstIndex(where: { $0.id == aiMessageId }) {
                        messages[lastIndex] = ChatMessage(
                            id: aiMessageId,
                            content: "Error: \(error.localizedDescription)",
                            isUser: false
                        )
                    }
                }
            }
            
            await MainActor.run {
                print("🏁 Streaming completed. Final content length: \(streamingContent.count)")
                print("🏁 Final content: '\(streamingContent)'")
                isLoading = false
                isStreaming = false
            }
        }
    }
    
    func stopGeneration() {
        currentTask?.cancel()
        isLoading = false
        isStreaming = false
    }
    
    func clearMessages() {
        messages.removeAll()
    }
    
    func refreshModels() async {
        await loadAvailableModels()
    }
    
    func regenerateResponse(for messageId: UUID) async {
        // Find the AI message to regenerate
        guard let messageIndex = messages.firstIndex(where: { $0.id == messageId && !$0.isUser }) else { return }
        
        // Start regeneration
        isLoading = true
        isStreaming = true
        
        currentTask = Task {
            var streamingContent = ""
            
            do {
                // Get all messages before the AI response we're regenerating
                let contextMessages = Array(messages[0..<messageIndex])
                
                try await streamLMStudio(messages: contextMessages) { chunk in
                    Task { @MainActor in
                        streamingContent += chunk
                        
                        // Update the existing message with streaming content
                        self.messages[messageIndex].content = streamingContent
                        // Ensure the versions array is properly updated
                        if self.messages[messageIndex].versions.isEmpty {
                            self.messages[messageIndex].versions = [streamingContent]
                        } else {
                            self.messages[messageIndex].versions[0] = streamingContent
                        }
                        // Set the current version to show the streaming content
                        self.messages[messageIndex].currentVersionIndex = 0
                    }
                }
                
                // After streaming completes, finalize the new version
                await MainActor.run {
                    if !streamingContent.isEmpty {
                        self.messages[messageIndex].addVersion(streamingContent)
                    }
                }
                
            } catch {
                await MainActor.run {
                    // Add error as a new version
                    self.messages[messageIndex].addVersion("Error: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                isLoading = false
                isStreaming = false
            }
        }
    }
    
    func navigateToVersion(messageId: UUID, versionIndex: Int) {
        guard let messageIndex = messages.firstIndex(where: { $0.id == messageId }) else { return }
        messages[messageIndex].setVersion(index: versionIndex)
    }
    
    private func loadAvailableModels() async {
        isLoadingModels = true
        connectionStatus = .connecting
        hasTestedConnection = true
        
        do {
            guard let url = URL(string: "\(serverURL)/models") else {
                isLoadingModels = false
                connectionStatus = .failure("Invalid URL")
                return
            }
            
            // Configure URL session with shorter timeouts to reduce hanging
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0 // 5 second timeout
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check if we got a valid response
            guard let httpResponse = response as? HTTPURLResponse else {
                isLoadingModels = false
                connectionStatus = .failure("Invalid response")
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                isLoadingModels = false
                connectionStatus = .failure("HTTP \(httpResponse.statusCode)")
                return
            }
            
            // Try to decode the response
            do {
                let modelResponse = try JSONDecoder().decode(ModelsResponse.self, from: data)
                
                // Create ModelInfo objects with display names
                let modelInfos = modelResponse.data.map { model in
                    ModelInfo(
                        id: model.id,
                        displayName: formatModelName(model.id)
                    )
                }
                
                availableModels = modelInfos
                
                // Set the first model as selected if none is selected
                if selectedModel.isEmpty && !availableModels.isEmpty {
                    selectedModel = availableModels[0].id
                }
                
                connectionStatus = .success
                
            } catch {
                // If JSON decoding fails, check if we got any data
                if data.count > 0 {
                    let responseString = String(data: data, encoding: .utf8) ?? "Unknown data"
                    connectionStatus = .failure("Invalid JSON: \(responseString.prefix(100))")
                } else {
                    connectionStatus = .failure("Empty response")
                }
            }
            
        } catch {
            print("Failed to load models: \(error)")
            // Provide cleaner error messages
            if error.localizedDescription.contains("Connection refused") {
                connectionStatus = .failure("Server not running on \(serverURL)")
            } else if error.localizedDescription.contains("timeout") {
                connectionStatus = .failure("Connection timeout")
            } else {
                connectionStatus = .failure("Connection failed: \(error.localizedDescription)")
            }
        }
        
        isLoadingModels = false
    }
    
    private func formatModelName(_ modelId: String) -> String {
        // Clean up model names for display
        var displayName = modelId
        
        // Remove common prefixes
        displayName = displayName.replacingOccurrences(of: "lmstudio-community/", with: "")
        displayName = displayName.replacingOccurrences(of: "microsoft/", with: "")
        displayName = displayName.replacingOccurrences(of: "meta-llama/", with: "")
        
        // Replace hyphens and underscores with spaces
        displayName = displayName.replacingOccurrences(of: "-", with: " ")
        displayName = displayName.replacingOccurrences(of: "_", with: " ")
        
        // Capitalize words
        displayName = displayName.capitalized
        
        // Handle common abbreviations
        displayName = displayName.replacingOccurrences(of: "Gguf", with: "")
        displayName = displayName.replacingOccurrences(of: "Instruct", with: "(Instruct)")
        displayName = displayName.replacingOccurrences(of: "Chat", with: "(Chat)")
        
        // Clean up extra spaces
        displayName = displayName.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return displayName.isEmpty ? modelId : displayName
    }
    
    private func streamLMStudio(messages: [ChatMessage], onChunk: @escaping (String) -> Void) async throws {
        guard !selectedModel.isEmpty else {
            throw ChatError.noModelSelected
        }
        
        guard let url = URL(string: "\(serverURL)/chat/completions") else {
            throw ChatError.invalidURL
        }
        
        // Convert messages to API format
        let apiMessages = messages.map { message in
            APIMessage(
                role: message.isUser ? "user" : "assistant",
                content: message.content
            )
        }
        
        let requestBody = StreamingChatCompletionRequest(
            model: selectedModel,
            messages: apiMessages,
            temperature: 0.7,
            max_tokens: 1000,
            stream: true
        )
        
        print("Streaming request body: \(requestBody)")
        print("Stream parameter: \(requestBody.stream)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        // Set timeout for streaming requests too
        request.timeoutInterval = 30.0 // 30 second timeout for streaming
        
        print("Sending streaming request to: \(url)")
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            throw ChatError.serverError(httpResponse.statusCode)
        }
        
        // Process streaming response
        print("Starting to process streaming response...")
        for try await line in asyncBytes.lines {
            if Task.isCancelled {
                print("Task was cancelled, stopping streaming")
                break
            }
            
            print("Received line: \(line)")
            
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                print("Processing JSON string: \(jsonString)")
                
                if jsonString == "[DONE]" {
                    print("Streaming completed with [DONE]")
                    break
                }
                
                if !jsonString.isEmpty, let data = jsonString.data(using: .utf8) {
                    do {
                        let streamResponse = try JSONDecoder().decode(StreamingChatCompletionResponse.self, from: data)
                        print("Decoded streaming response: \(streamResponse)")
                        if let content = streamResponse.choices.first?.delta.actualContent {
                            print("Content in chunk: '\(content)' (length: \(content.count))")
                            // Call onChunk even if content is empty, as empty chunks are normal in streaming
                            onChunk(content)
                        } else {
                            print("No content field in chunk")
                        }
                        
                        // Debug: Check if this is a finish reason chunk
                        if let finishReason = streamResponse.choices.first?.finish_reason {
                            print("🛑 Stream finished with reason: \(finishReason)")
                        }
                    } catch {
                        // Skip malformed JSON chunks
                        print("Failed to decode streaming chunk: \(error)")
                        continue
                    }
                } else {
                    print("Empty JSON string or failed to convert to data")
                }
            } else {
                print("Line doesn't start with 'data: ': \(line)")
            }
        }
        print("Finished processing streaming response")
    }
}

// MARK: - Data Models

struct ChatMessage: Identifiable {
    let id: UUID
    var content: String
    let isUser: Bool
    let timestamp: Date
    var versions: [String] // For AI responses, store multiple versions
    var currentVersionIndex: Int // Which version is currently displayed
    
    init(content: String, isUser: Bool) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
        self.versions = [content]
        self.currentVersionIndex = 0
    }
    
    init(id: UUID, content: String, isUser: Bool) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
        self.versions = [content]
        self.currentVersionIndex = 0
    }
    
    // Get the currently displayed content
    var displayContent: String {
        guard currentVersionIndex < versions.count else { return content }
        return versions[currentVersionIndex]
    }
    
    // Get total number of versions
    var versionCount: Int {
        return versions.count
    }
    
    // Add a new version (for regenerations)
    mutating func addVersion(_ newContent: String) {
        versions.append(newContent)
        currentVersionIndex = versions.count - 1 // Switch to newest version
    }
    
    // Navigate to a specific version
    mutating func setVersion(index: Int) {
        if index >= 0 && index < versions.count {
            currentVersionIndex = index
        }
    }
}

struct ModelInfo: Identifiable {
    let id: String
    let displayName: String
}

struct ModelsResponse: Codable {
    let data: [Model]
}

struct Model: Codable {
    let id: String
}

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [APIMessage]
    let temperature: Double
    let max_tokens: Int
}

struct StreamingChatCompletionRequest: Codable {
    let model: String
    let messages: [APIMessage]
    let temperature: Double
    let max_tokens: Int
    let stream: Bool
}

struct APIMessage: Codable {
    let role: String
    let content: String
}

struct ChatCompletionResponse: Codable {
    let choices: [Choice]
}

struct Choice: Codable {
    let message: APIMessage
}

struct StreamingChatCompletionResponse: Codable {
    let choices: [StreamingChoice]
}

struct StreamingChoice: Codable {
    let delta: Delta
    let finish_reason: String?
}

struct Delta: Codable {
    let content: String?
    let reasoning_content: String?
    
    var actualContent: String? {
        return content ?? reasoning_content
    }
}

enum ChatError: LocalizedError {
    case noModelSelected
    case noModelAvailable
    case invalidURL
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .noModelSelected:
            return "No model selected. Please select a model from the dropdown."
        case .noModelAvailable:
            return "No model available. Make sure LM Studio is running."
        case .invalidURL:
            return "Invalid API URL"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}
