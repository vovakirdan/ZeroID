// Views/ChatScreen.swift

import SwiftUI
import ExyteChat
import UniformTypeIdentifiers

struct ChatScreen: View {
    @ObservedObject var vm: ChatViewModel
    let onBack: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    // Modal
    @State private var showConnectionInfo: Bool = false
    // Document picker
    @State private var showFileImporter: Bool = false

    // MARK: - Header (kept outside the ChatView so it won't jump with keyboard)
    private var headerView: some View {
        VStack(spacing: 6) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.backward")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                Spacer()
                Text("Секретный чат")
                    .font(.headline)
                    .foregroundColor(Color.primary)
                Spacer()
                Button(action: { showConnectionInfo.toggle() }) {
                    Image(systemName: "info.circle")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)

            HStack(spacing: 8) {
                Circle()
                    .fill(vm.webrtc.isConnected && vm.webrtc.isChatEnabled ? Color.green : .orange)
                    .frame(width: 8, height: 8)
                Text(vm.webrtc.isConnected ? (vm.webrtc.isChatEnabled ? "Соединение активно" : "Ждём подтверждения отпечатков") : "Нет соединения")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: - Overlays for connection states
    @ViewBuilder
    private var connectionOverlay: some View {
        if !vm.webrtc.isConnected {
            VStack(spacing: 12) {
                ProgressView()
                Text("⚠️ Ожидание установки соединения...")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
        } else if !vm.webrtc.isChatEnabled {
            VStack(spacing: 12) {
                ProgressView()
                Text("🔐 Сверка отпечатков...")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Theme to mimic your gradients/colors
    private var theme: ChatTheme { ChatTheme(colors: .init(), images: .init()) }

    var body: some View {
        ZStack {
            // Your gradient background from assets if you had it; otherwise plain bg
            Color.chatBackgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView

                // Main Chat View from Exyte
                ChatView<AnyView, AnyView, ExyteChat.DefaultMessageMenuAction>(
                    messages: vm.chatMessages,
                    chatType: .conversation,
                    replyMode: .quote,
                    didSendMessage: { draft in
                        // didSendMessage closure
                        vm.send(draft: draft)
                        vm.sendMediasFromDraft(draft) // hook for medias if you wire URLs later
                    },
                    reactionDelegate: nil,
                    messageBuilder: { (message: ExyteChat.Message,
                                         _ positionInGroup: ExyteChat.PositionInUserGroup,
                                         _ positionInMessagesSection: ExyteChat.PositionInMessagesSection,
                                         _ positionInCommentsGroup: ExyteChat.CommentsPosition?,
                                         _ showContextMenu: @escaping () -> Void,
                                         _ messageAction: @escaping (ExyteChat.Message, ExyteChat.DefaultMessageMenuAction) -> Void,
                                         _ showAttachment: @escaping (ExyteChat.Attachment) -> Void) -> AnyView in
                    // Custom message bubble replicating your style
                    let bubble = VStack(alignment: message.user.isCurrentUser ? .trailing : .leading, spacing: 4) {
                        HStack {
                            if message.user.isCurrentUser { Spacer(minLength: 60) }
                            Text(message.text)
                                .font(.body)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(
                                            message.user.isCurrentUser
                                            ? AnyShapeStyle(LinearGradient(
                                                colors: [
                                                    Color(red: 0.2, green: 0.9, blue: 0.6),
                                                    Color(red: 0.3, green: 0.7, blue: 1.0)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ))
                                            : AnyShapeStyle(Color(red: 0.15, green: 0.15, blue: 0.15, opacity: 0.85))
                                        )
                                )
                                .contextMenu { Button("Reply") { messageAction(message, .reply) } }
                            if !message.user.isCurrentUser { Spacer(minLength: 60) }
                        }
                        Text(message.createdAt, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, message.user.isCurrentUser ? 20 : 16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 3)
                    return AnyView(bubble)
                },
                    inputViewBuilder: { (textBinding: Binding<String>,
                                         _ attachments: ExyteChat.InputViewAttachments,
                                         _ inputViewState: ExyteChat.InputViewState,
                                         _ inputViewStyle: ExyteChat.InputViewStyle,
                                         _ inputAction: @escaping (ExyteChat.InputViewAction) -> Void,
                                         _ dismissKeyboard: () -> Void) -> AnyView in
                    // Input mimicking your previous layout, plus a paperclip to send documents via vm.sendFile
                    let input = VStack(spacing: 0) {
                        Divider().background(Color.gray.opacity(0.3))
                        HStack(spacing: 12) {
                            Button {
                                showFileImporter = true
                            } label: {
                                Image(systemName: "paperclip")
                                    .font(.title2)
                            }

                            TextField("Введите сообщение...", text: textBinding, axis: .vertical)
                                .font(.body)
                                .lineLimit(1...5)

                            Button {
                                inputAction(.send) // Exyte will clear the text and call didSendMessage
                            } label: {
                                Image(systemName: "arrow.up.circle.fill").font(.largeTitle)
                            }
                            .disabled(textBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.thinMaterial)
                    }
                    return AnyView(input)
                },
                    messageMenuAction: nil,
                    localization: ChatLocalization(
                        inputPlaceholder: "Введите сообщение...",
                        signatureText: "Добавить подпись...",
                        cancelButtonText: "Отмена",
                        recentToggleText: "Недавние",
                        waitingForNetwork: "Ожидание сети",
                        recordingText: "Запись...",
                        replyToText: "Ответить"
                    )
                )
                // Make list stay above input, show date headers if you want
                .isListAboveInputView(true)
                .showDateHeaders(false)
                .chatTheme(theme)
                .background(Color.clear)
                .overlay(connectionOverlay)
            }
        }
        .navigationBarHidden(true)
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    vm.sendFile(url: url)
                }
            case .failure(let err):
                print("[ChatScreen] File import error:", err.localizedDescription)
            }
        }
        .overlay(
            Group {
                if showConnectionInfo {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { showConnectionInfo = false }
                    VStack {
                        Spacer()
                        connectionInfoModal
                    }
                    .transition(.move(edge: .bottom))
                }
            }
        )
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showConnectionInfo)
    }

    // MARK: - Info modal (same as before but simplified)
    private var connectionInfoModal: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Информация о соединении")
                    .font(.headline)
                Spacer()
                Button(action: { showConnectionInfo = false }) {
                    Image(systemName: "xmark.circle.fill").font(.title2)
                }
            }
            .padding(.horizontal)
            .padding(.top)

            VStack(spacing: 12) {
                infoRow("DataChannel", vm.webrtc.dataChannelState)
                infoRow("ICE Connection", vm.webrtc.iceConnectionState)
                infoRow("ICE Gathering", vm.webrtc.iceGatheringState)
                infoRow("Candidates", vm.webrtc.candidateCount)
                infoRow("Status", vm.webrtc.isConnected ? "active" : "not ready")
            }
            .padding(.horizontal)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 10)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.body).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.body).fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview("ChatScreen - Connected") {
    ChatScreen(
        vm: ChatViewModel.previewConnected,
        onBack: {}
    )
}

#Preview("ChatScreen - Waiting Connection") {
    ChatScreen(
        vm: ChatViewModel.previewWaitingConnection,
        onBack: {}
    )
}

#Preview("ChatScreen - Waiting Fingerprint") {
    ChatScreen(
        vm: ChatViewModel.previewWaitingFingerprint,
        onBack: {}
    )
}

#Preview("ChatScreen - Dark Mode") {
    ChatScreen(
        vm: ChatViewModel.previewConnected,
        onBack: {}
    )
    .preferredColorScheme(.dark)
}
