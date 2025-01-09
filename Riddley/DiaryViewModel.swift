import Foundation

@MainActor
class DiaryViewModel: ObservableObject {
    private let claudeService = ClaudeService()
    @Published var diaryResponse = ""
    
    func processUserInput(_ text: String) async {
        do {
            let response = try await claudeService.generateResponse(to: text)
            diaryResponse = response
        } catch {
            diaryResponse = "The diary seems to be having trouble understanding your message..."
        }
    }
}
