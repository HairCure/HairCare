
import SwiftUI

struct CoachView: View {

    // MARK: - ViewModel
    @State var viewModel: CoachViewModel
    @State private var inputText: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                inputArea
            }
            .navigationTitle("Hair Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.clearChat()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .disabled(viewModel.messages.isEmpty)
                }
            }
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.messages.isEmpty {
                        emptyStateView
                    }
                    ForEach(viewModel.messages) { msg in
                        ChatBubble(message: msg)
                            .id(msg.id)
                    }
                    if viewModel.isThinking {
                        TypingIndicator().id("typing")
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) {
                withAnimation {
                    if viewModel.isThinking {
                        proxy.scrollTo("typing", anchor: .bottom)
                    } else {
                        proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor.opacity(0.7))
            Text("Ask me anything about hair health, nutrition, scalp care, or stress management.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                TextField("Ask a question...", text: $inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(22)

                Button {
                    let text = inputText
                    inputText = ""
                    Task { await viewModel.sendMessage(text) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(inputText.isEmpty ? Color.gray : Color.blue)
                }
                .disabled(inputText.isEmpty || viewModel.isThinking)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }
            Text(message.content)
                .padding(12)
                .background(
                    message.role == .user
                        ? Color.blue
                        : Color(.secondarySystemBackground)
                )
                .foregroundStyle(message.role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    var body: some View {
        HStack {
            ProgressView().scaleEffect(0.8)
            Text("Coach is thinking...")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.leading, 4)
    }
}

// MARK: - Preview

#Preview {
    CoachView(viewModel: CoachViewModel())
}
