
import Foundation
import Observation
import FoundationModels

// MARK: - ViewModel

@Observable
@MainActor
final class CoachViewModel {

    // MARK: - Published State
    var messages: [ChatMessage] = []
    var isThinking: Bool = false
    var errorMessage: String? = nil

    // MARK: - Private
    private var session: LanguageModelSession

    private static let systemInstructions = """
    You are a Hair Health Coach specializing in natural hair restoration.
    Your expertise covers:
    - Nutrition and diet for healthy hair growth
    - Scalp care, oil massage techniques, and home remedies
    - Stress management and sleep hygiene for hair health
    - Hydration and its effect on hair
    - Hair care routines and product advice

    STRICT RULES:
    1. Never suggest, recommend, or discuss any medicines, pharmaceutical drugs, or medical treatments.
    2. If asked about medication, redirect to a dermatologist.
    3. Keep responses concise, friendly, and actionable.
    4. Always encourage consistency — hair improvement takes time.
    """

    // MARK: - Init
    init() {
        self.session = LanguageModelSession(instructions: Self.systemInstructions)
    }

    // MARK: - Send Message

    func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(role: .user, content: trimmed))
        isThinking = true
        errorMessage = nil

        do {
            let prompt = Prompt(trimmed)
            let response = try await session.respond(to: prompt)
            messages.append(ChatMessage(role: .assistant, content: response.content))
        } catch {
            errorMessage = "Connection issue. Please try again."
            messages.append(ChatMessage(role: .assistant, content: "I'm sorry, I encountered a connection issue. Please try again."))
        }

        isThinking = false
    }

    func clearChat() {
        messages.removeAll()
        session = LanguageModelSession(instructions: Self.systemInstructions)
    }
}
