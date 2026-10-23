import SwiftUI

@MainActor
final class AICompanionController: ObservableObject {
    @Published private(set) var messages: [AICompanionMessage] = []
    @Published var draft = ""
    @Published private(set) var pendingReference: AICompanionReference?
    @Published private(set) var isGenerating = false

    private let repository: any AICompanionStreaming
    private var articleID: UUID?
    private var generationTask: Task<Void, Never>?
    private var lastFailedRequest: AICompanionRequest?

    init(repository: any AICompanionStreaming) {
        self.repository = repository
    }

    deinit {
        generationTask?.cancel()
    }

    func beginSession(articleID: UUID) {
        guard self.articleID != articleID else { return }
        stop()
        self.articleID = articleID
        messages = []
        draft = ""
        pendingReference = nil
        lastFailedRequest = nil
    }

    func prepare(reference: AICompanionReference?) {
        pendingReference = reference
    }

    func clearReference() {
        pendingReference = nil
    }

    var canSend: Bool {
        !isGenerating && (
            !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            pendingReference != nil
        )
    }

    func send() {
        guard let articleID else { return }
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend else { return }

        let reference = pendingReference
        let history = historyMessages()
        let request = AICompanionRequest(
            articleId: articleID,
            requestType: reference?.requestType ?? .question,
            question: question,
            anchor: reference?.anchor,
            quotedText: reference?.text,
            history: history
        )
        draft = ""
        pendingReference = nil
        start(request: request, visibleQuestion: question, referenceText: reference?.text)
    }

    func retryLastFailed() {
        guard let request = lastFailedRequest, !isGenerating else { return }
        if messages.last?.role == .assistant, messages.last?.state == .failed {
            messages.removeLast()
        }
        start(
            request: request,
            visibleQuestion: nil,
            referenceText: nil,
            appendingUserMessage: false
        )
    }

    func stop() {
        guard isGenerating else { return }
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        if let index = messages.lastIndex(where: { $0.role == .assistant && $0.state == .generating }) {
            messages[index].state = .stopped
        }
    }

    func disposeSession() {
        stop()
        articleID = nil
        messages = []
        draft = ""
        pendingReference = nil
        lastFailedRequest = nil
    }

    private func start(
        request: AICompanionRequest,
        visibleQuestion: String?,
        referenceText: String?,
        appendingUserMessage: Bool = true
    ) {
        if appendingUserMessage, let visibleQuestion {
            messages.append(AICompanionMessage(
                role: .user,
                text: visibleQuestion,
                referenceText: referenceText
            ))
        }

        let assistantID = UUID()
        messages.append(AICompanionMessage(
            id: assistantID,
            role: .assistant,
            text: "",
            state: .generating
        ))
        isGenerating = true
        lastFailedRequest = nil

        generationTask = Task { [weak self, repository] in
            do {
                for try await event in repository.stream(request) {
                    try Task.checkCancellation()
                    guard let self else { return }
                    switch event {
                    case .started:
                        break
                    case let .delta(content):
                        self.updateAssistant(id: assistantID) { message in
                            message.text += content
                        }
                    case .completed:
                        self.updateAssistant(id: assistantID) { $0.state = .complete }
                        self.isGenerating = false
                        self.generationTask = nil
                    case .failed:
                        self.markFailed(id: assistantID, request: request)
                    }
                }
                guard !Task.isCancelled, let self, self.isGenerating else { return }
                self.markFailed(id: assistantID, request: request)
            } catch is CancellationError {
                // stop() owns the visible stopped state.
            } catch {
                guard let self else { return }
                self.markFailed(id: assistantID, request: request)
            }
        }
    }

    private func markFailed(id: UUID, request: AICompanionRequest) {
        updateAssistant(id: id) { message in
            message.state = .failed
            if message.text.isEmpty {
                message.text = "回复生成失败，请重试。"
            }
        }
        isGenerating = false
        generationTask = nil
        lastFailedRequest = request
    }

    private func updateAssistant(id: UUID, update: (inout AICompanionMessage) -> Void) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        update(&messages[index])
    }

    private func historyMessages() -> [AICompanionHistoryMessage] {
        messages.compactMap { message in
            let content = message.historyContent
            guard message.state == .complete || message.state == .stopped,
                  !content.isEmpty else { return nil }
            return AICompanionHistoryMessage(
                role: message.role == .user ? .user : .assistant,
                content: content
            )
        }.suffix(20).map { $0 }
    }
}

struct AICompanionSheet: View {
    @ObservedObject var controller: AICompanionController
    let focusesComposerOnAppear: Bool

    @FocusState private var composerIsFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text("AI 伴读")
                .font(.system(size: 17, weight: .semibold))
                .padding(.top, 4)
                .padding(.bottom, 12)
                .offset(y: 10)
                .accessibilityIdentifier("ai-companion-sheet-title")

            messages
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            composer
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
                .offset(y: 15)
        }
        .background(Color(red: 0.976, green: 0.976, blue: 0.984))
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(red: 0.976, green: 0.976, blue: 0.984))
        .onAppear {
            guard focusesComposerOnAppear else { return }
            DispatchQueue.main.async { composerIsFocused = true }
        }
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 18) {
                    if controller.messages.isEmpty {
                        Spacer(minLength: 8)
                    }
                    ForEach(controller.messages) { message in
                        messageView(message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: controller.messages) { _, messages in
                guard let last = messages.last else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private func messageView(_ message: AICompanionMessage) -> some View {
        if message.role == .user {
            HStack {
                Spacer(minLength: 52)
                VStack(alignment: .trailing, spacing: 0) {
                    if let reference = message.referenceText {
                        referenceChip(reference)
                            .padding(.bottom, 8)
                    }
                    Text(message.text)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(Color(uiColor: .systemBlue).opacity(0.72), in: RoundedRectangle(cornerRadius: 15))
                }
            }
        } else {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    if message.state == .generating, message.text.isEmpty {
                        TypingDots()
                    } else {
                        Text(message.text.isEmpty ? "已停止生成" : message.text)
                            .font(.system(size: 15))
                            .lineSpacing(4)
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    }
                    if message.state == .failed {
                        Button("重新生成") { controller.retryLastFailed() }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(uiColor: .systemBlue))
                    }
                }
                Spacer(minLength: 34)
            }
        }
    }

    private func referenceChip(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: "quote.opening")
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .frame(height: 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBlue).opacity(0.08), in: Capsule())
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if let reference = controller.pendingReference {
                HStack(spacing: 8) {
                    referenceChip(reference.text)
                    Button {
                        controller.clearReference()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("移除引用")
                }
                .padding(.horizontal, 12)
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField("继续提问…", text: $controller.draft, axis: .vertical)
                    .font(.system(size: 16))
                    .lineLimit(1...4)
                    .focused($composerIsFocused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .accessibilityIdentifier("ai-companion-input")
                    .padding(.leading, 16)
                    .padding(.vertical, 12)

                actionButton
                    .padding(.trailing, 6)
                    .padding(.bottom, 5)
            }
            .frame(minHeight: 56)
            .background(.white.opacity(0.92), in: Capsule())
            .glassEffect(.regular, in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 14, y: 7)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if controller.isGenerating {
            Button { controller.stop() } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(Color(uiColor: .systemBlue))
                    .glassEffect(.regular.tint(.blue.opacity(0.12)).interactive(), in: Circle())
            }
            .accessibilityLabel("停止生成")
            .accessibilityIdentifier("ai-companion-stop")
        } else if !controller.canSend {
            Image(systemName: "mic.fill")
                .font(.system(size: 17, weight: .medium))
                .frame(width: 36, height: 36)
                .foregroundStyle(.white)
                .glassEffect(.regular.tint(.blue), in: Circle())
                .accessibilityLabel("语音输入暂未开放")
        } else {
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.white)
                    .glassEffect(.regular.tint(.blue).interactive(), in: Circle())
            }
            .accessibilityLabel("发送")
            .accessibilityIdentifier("ai-companion-send")
        }
    }

    private func send() {
        controller.send()
        composerIsFocused = false
    }
}

private struct TypingDots: View {
    @State private var isExpanded = false

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 6, height: 6)
                    .scaleEffect(isExpanded ? 1 : 0.72)
                    .animation(
                        .easeInOut(duration: 0.55).repeatForever().delay(Double(index) * 0.14),
                        value: isExpanded
                    )
            }
        }
        .frame(height: 22)
        .onAppear { isExpanded = true }
        .accessibilityLabel("AI 正在生成")
    }
}
