import Foundation
import UIKit

class ClaudeService {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    
    init(apiKey: String = Config.claudeApiKey) {
        self.apiKey = apiKey
    }
    
    func generateResponse(to userMessage: String, withContext context: String = "") async throws -> String {
        // Validate API key before making the request
        guard !apiKey.isEmpty && apiKey.hasPrefix("sk-ant-") else {
            throw NSError(domain: "ClaudeService", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "Invalid API Key. Please check your Anthropic API configuration."
            ])
        }
        
        // Construct messages array with context and user message
        var messages: [[String: Any]] = []
        
        // Combine context and user message if context exists
        let fullMessage = context.isEmpty ? userMessage : context + "\n\nUser: " + userMessage
        
        messages.append(["role": "user", "content": fullMessage])
        
        let requestBody: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 1000,
            "messages": messages,
            "system": Config.systemPrompt,
            "temperature": 0.7
        ]
        
        guard let url = URL(string: baseURL) else {
            throw NSError(domain: "ClaudeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = urlResponse as? HTTPURLResponse {
                if !(200...299).contains(httpResponse.statusCode) {
                    if let errorText = String(data: data, encoding: .utf8) {
                        print("❌ Detailed API Error: \(errorText)")
                        let errorMessage: String
                        switch httpResponse.statusCode {
                        case 401:
                            errorMessage = "Authentication failed. Please check your API key."
                        case 429:
                            errorMessage = "Too many requests. Please try again later."
                        case 500...599:
                            errorMessage = "Server error. Please try again later."
                        default:
                            errorMessage = "API request failed with status code \(httpResponse.statusCode)"
                        }
                        throw NSError(domain: "ClaudeService", code: httpResponse.statusCode, userInfo: [
                            NSLocalizedDescriptionKey: errorMessage
                        ])
                    }
                }
                
                let decoder = JSONDecoder()
                let claudeResponse = try decoder.decode(ClaudeResponse.self, from: data)
                
                if let responseText = claudeResponse.content.first?.text {
                    return responseText
                } else {
                    print("❓ No response text found in API response")
                    return "I'm afraid I couldn't understand that..."
                }
            }
            
            throw NSError(domain: "ClaudeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
            
        } catch {
            print("❌ Comprehensive Error in Claude API call: \(error)")
            throw error
        }
    }
    
    private func convertImageToBase64(_ image: UIImage) -> String? {
        guard let data = image.pngData() else {
            print("Failed to convert image to PNG data")
            return nil
        }
        return data.base64EncodedString()
    }
}

struct ClaudeResponse: Codable {
    let id: String
    let content: [MessageContent]
    let model: String
    let role: String
}

struct MessageContent: Codable {
    let text: String
    let type: String
}