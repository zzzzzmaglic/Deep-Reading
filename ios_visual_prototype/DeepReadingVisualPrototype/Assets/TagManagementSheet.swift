import SwiftUI

struct TagManagementSheet: View {
    @ObservedObject var controller: AssetDraftController
    let isEditing: Bool
    let dismiss: () -> Void

    @State private var selectedTagIDs: Set<UUID>
    @State private var isCreatingTag = false
    @State private var newTagName = ""
    @State private var errorMessage: String?
    @FocusState private var newTagFocused: Bool
    @State private var keyboardHeight: CGFloat = 0

    init(controller: AssetDraftController, isEditing: Bool, dismiss: @escaping () -> Void) {
        self.controller = controller
        self.isEditing = isEditing
        self.dismiss = dismiss
        _selectedTagIDs = State(initialValue: controller.draft.selectedTagIDs)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture {
                    guard !controller.isMutationInFlight else { return }
                    dismiss()
                }

            if keyboardHeight > 0 {
                Color(uiColor: .secondarySystemBackground)
                    .frame(height: keyboardHeight)
                    .ignoresSafeArea(edges: .bottom)
            }

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.secondary.opacity(0.45))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)
                HStack {
                    Text("标签")
                        .font(.headline)
                    Spacer()
                    Button("确定") { confirm() }
                        .fontWeight(.semibold)
                        .disabled(controller.isMutationInFlight)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(controller.availableTags) { tag in
                            tagRow(tag)
                        }
                        if isCreatingTag {
                            HStack(spacing: 10) {
                                TextField("新建标签", text: $newTagName)
                                    .focused($newTagFocused)
                                    .submitLabel(.done)
                                    .onSubmit { createTag() }
                                Button("完成", action: createTag)
                                    .fontWeight(.semibold)
                            }
                            .padding(.vertical, 12)
                            .disabled(controller.isMutationInFlight)
                        } else {
                            Button("＋ 新建标签") {
                                isCreatingTag = true
                                newTagFocused = true
                            }
                            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                            .foregroundStyle(.blue)
                            .disabled(controller.isMutationInFlight)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                if let displayedErrorMessage {
                    Text(displayedErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .frame(height: 426)
            .background(Color(uiColor: .secondarySystemBackground), in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
            .disabled(controller.isMutationInFlight)
            .offset(y: keyboardHeight > 0 ? -keyboardHeight : 0)
            .animation(.easeOut(duration: 0.22), value: keyboardHeight)
        }
        .task { await controller.loadAvailableTags() }
        .task(id: isCreatingTag) {
            guard isCreatingTag else { return }
            try? await Task.sleep(for: .milliseconds(120))
            newTagFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            keyboardHeight = max(0, UIScreen.main.bounds.height - frame.minY)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }

    private func tagRow(_ tag: Tag) -> some View {
        Button {
            guard !tag.isSystem else { return }
            if selectedTagIDs.contains(tag.id) {
                selectedTagIDs.remove(tag.id)
            } else {
                selectedTagIDs.insert(tag.id)
            }
        } label: {
            HStack {
                Text(tag.name)
                    .foregroundStyle(.primary)
                Spacer()
                if tag.isSystem {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                } else if selectedTagIDs.contains(tag.id) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
            .frame(height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(controller.isMutationInFlight)
        .accessibilityLabel(tag.isSystem ? "\(tag.name)，已锁定" : tag.name)
    }

    private func createTag() {
        guard !controller.isMutationInFlight else { return }
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        Task {
            do {
                let tag = try await controller.addNewTag(name: name)
                selectedTagIDs.insert(tag.id)
                newTagName = ""
                isCreatingTag = false
                errorMessage = nil
            } catch {
                errorMessage = "新建标签失败，请稍后重试"
            }
        }
    }

    private func confirm() {
        guard !controller.isMutationInFlight else { return }
        controller.replaceSelectedTags(selectedTagIDs)
        Task {
            do {
                try await controller.confirmTags()
                dismiss()
            } catch {
                errorMessage = "标签更新失败，请稍后重试"
            }
        }
    }

    private var displayedErrorMessage: String? {
        if let errorMessage { return errorMessage }
        if controller.operationError != nil { return "标签加载失败，请稍后重试" }
        return nil
    }
}
