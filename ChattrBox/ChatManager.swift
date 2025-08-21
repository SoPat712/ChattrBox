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
        print("Added AI message, total messages: \(messages.count)")
        
        currentTask = Task {
            var streamingContent = ""
            
            do {
                try await streamLMStudio(messages: Array(messages.dropLast())) { chunk in
                    Task { @MainActor in
                        streamingContent += chunk
                        print("Received chunk: \(chunk), total: \(streamingContent)")
                        
                        // Update the message with streaming content
                        if let lastIndex = self.messages.firstIndex(where: { $0.id == aiMessageId }) {
                            self.messages[lastIndex] = ChatMessage(
                                id: aiMessageId,
                                content: streamingContent,
                                isUser: false
                            )
                            print("Updated AI message, content length: \(streamingContent.count)")
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
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        // Set timeout for streaming requests too
        request.timeoutInterval = 30.0 // 30 second timeout for streaming
        
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            throw ChatError.serverError(httpResponse.statusCode)
        }
        
        // Process streaming response
        for try await line in asyncBytes.lines {
            if Task.isCancelled {
                break
            }
            
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if jsonString == "[DONE]" {
                    break
                }
                
                if !jsonString.isEmpty, let data = jsonString.data(using: .utf8) {
                    do {
                        let streamResponse = try JSONDecoder().decode(StreamingChatCompletionResponse.self, from: data)
                        if let content = streamResponse.choices.first?.delta.content, !content.isEmpty {
                            onChunk(content)
                        }
                    } catch {
                        // Skip malformed JSON chunks
                        print("Failed to decode streaming chunk: \(error)")
                        continue
                    }
                }
            }
        }
    }
}

// MARK: - Data Models

struct ChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    
    init(content: String, isUser: Bool) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
    }
    
    init(id: UUID, content: String, isUser: Bool) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
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
}

struct Delta: Codable {
    let content: String?
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
