import SwiftUI
import Foundation

@MainActor
class ChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var availableModels: [ModelInfo] = []
    @Published var selectedModel = ""
    @Published var isLoadingModels = false
    
    private let baseURL = "http://localhost:1234/v1"
    
    init() {
        Task {
            await loadAvailableModels()
        }
    }
    
    func sendMessage(_ content: String) async {
        // Add user message
        let userMessage = ChatMessage(content: content, isUser: true)
        messages.append(userMessage)
        
        isLoading = true
        
        do {
            let response = try await callLMStudio(messages: messages)
            if let aiContent = response {
                let aiMessage = ChatMessage(content: aiContent, isUser: false)
                messages.append(aiMessage)
            }
        } catch {
            let errorMessage = ChatMessage(
                content: "Error: \(error.localizedDescription)",
                isUser: false
            )
            messages.append(errorMessage)
        }
        
        isLoading = false
    }
    
    func clearMessages() {
        messages.removeAll()
    }
    
    func refreshModels() async {
        await loadAvailableModels()
    }
    
    private func loadAvailableModels() async {
        isLoadingModels = true
        
        do {
            guard let url = URL(string: "\(baseURL)/models") else {
                isLoadingModels = false
                return
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ModelsResponse.self, from: data)
            
            // Create ModelInfo objects with display names
            let modelInfos = response.data.map { model in
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
            
        } catch {
            print("Failed to load models: \(error)")
            // Create a fallback model if API fails
            availableModels = [ModelInfo(id: "default-model", displayName: "Default Model")]
            if selectedModel.isEmpty {
                selectedModel = "default-model"
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
    
    private func callLMStudio(messages: [ChatMessage]) async throws -> String? {
        guard !selectedModel.isEmpty else {
            throw ChatError.noModelSelected
        }
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw ChatError.invalidURL
        }
        
        // Convert messages to API format
        let apiMessages = messages.map { message in
            APIMessage(
                role: message.isUser ? "user" : "assistant",
                content: message.content
            )
        }
        
        let requestBody = ChatCompletionRequest(
            model: selectedModel,
            messages: apiMessages,
            temperature: 0.7,
            max_tokens: 1000
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("lm-studio", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            throw ChatError.serverError(httpResponse.statusCode)
        }
        
        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        return chatResponse.choices.first?.message.content
    }
}

// MARK: - Data Models

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp = Date()
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
