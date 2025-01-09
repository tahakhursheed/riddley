import SwiftUI
import PencilKit

struct ConversationEntry: Identifiable {
    let id = UUID()
    let userDrawing: PKDrawing?
    let userText: String
    let aiResponse: String?
    let position: CGPoint
}

enum DiaryMode {
    case magical
    case memory
}

class ConversationViewModel: ObservableObject {
    @Published var entries: [ConversationEntry] = []
    @Published var currentDrawing: PKDrawing?
    @Published var isProcessing = false
    @Published var mode: DiaryMode = .magical
    private let claudeService = ClaudeService()
    
    func addEntry(drawing: PKDrawing, text: String, position: CGPoint) {
        let entry = ConversationEntry(userDrawing: drawing, userText: text, aiResponse: nil, position: position)
        entries.append(entry)
    }
    
    func updateLastEntryWithResponse(_ response: String) {
        guard let lastEntry = entries.last else { return }
        entries.removeLast()
        entries.append(ConversationEntry(
            userDrawing: lastEntry.userDrawing,
            userText: lastEntry.userText,
            aiResponse: response,
            position: lastEntry.position
        ))
    }
    
    func clearAll() {
        entries.removeAll()
        currentDrawing = nil
    }
    
    func generateContextualPrompt() -> String {
        var context = ""
        for entry in entries {
            context += "User: \(entry.userText)\n"
            if let response = entry.aiResponse {
                context += "Assistant: \(response)\n"
            }
        }
        return context
    }
    
    func exportConversation() -> String {
        var export = "Magical Diary - Conversation Export\n\n"
        for entry in entries {
            export += "You: \(entry.userText)\n"
            if let response = entry.aiResponse {
                export += "Diary: \(response)\n"
            }
            export += "\n"
        }
        return export
    }
    
    @MainActor
    func processNewEntry(drawing: PKDrawing, text: String, position: CGPoint) async {
        isProcessing = true
        
        // Check if the text is an error message
        if text.contains("I don't understand what you wrote") {
            addEntry(drawing: drawing, text: text, position: position)
            updateLastEntryWithResponse("I'm having trouble reading your handwriting. Could you please write more clearly and a bit larger?")
            isProcessing = false
            return
        }
        
        addEntry(drawing: drawing, text: text, position: position)
        
        do {
            let contextualPrompt = generateContextualPrompt()
            let response = try await claudeService.generateResponse(to: text, withContext: contextualPrompt)
            updateLastEntryWithResponse(response)
        } catch {
            print("Error generating response: \(error)")
            updateLastEntryWithResponse("I'm having trouble responding right now. Could you try writing again?")
        }
        
        isProcessing = false
    }
}
