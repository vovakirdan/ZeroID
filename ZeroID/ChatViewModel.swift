// ViewModels/ChatViewModel.swift

import Foundation
import Combine
import ExyteChat

final class ChatViewModel: ObservableObject {

    // MARK: - Published state for ExyteChat
    @Published var chatMessages: [ExyteChat.Message] = []
    @Published var isSending: Bool = false

    // Text input is managed by ExyteChat, but keep this for potential external bindings
    @Published var inputText: String = ""

    // MARK: - Transport / Backend
    let webrtc = WebRTCManager()

    // MARK: - Users (map your identities here)
    // Replace with your real identities if you have them
    let me: ExyteChat.User = .init(
        id: "me",
        name: "Me",
        avatarURL: nil,
        isCurrentUser: true
    )

    let peer: ExyteChat.User = .init(
        id: "peer",
        name: "Peer",
        avatarURL: nil,
        isCurrentUser: false
    )

    // MARK: - Internals
    private var cancellables = Set<AnyCancellable>()
    private var disconnectCleanupWorkItem: DispatchWorkItem?
    private var finalDisconnect: Bool = false

    // MARK: - Init
    init() {
        // Text messages incoming from WebRTC -> append as "peer" message
        webrtc.$receivedMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self, !text.isEmpty else { return }
                let msg = ExyteChat.Message(
                    id: UUID().uuidString,
                    user: self.peer,
                    status: .read,
                    createdAt: Date(),
                    text: text,
                    attachments: [],
                    recording: nil,
                    replyMessage: nil
                )
                self.chatMessages.append(msg)
            }
            .store(in: &cancellables)

        // Media receiving from WebRTC -> you can convert to ExyteChat.Attachment here if needed
        webrtc.onMediaReceived = { [weak self] media in
            guard let self else { return }
            DispatchQueue.main.async {
                // Minimal placeholder: show as text with file name.
                // TODO: Map your MediaAttachment to ExyteChat.Attachment using real URLs (thumbnail/full).
                let display = media.name.isEmpty ? "Received file" : "Received: \(media.name)"
                let msg = ExyteChat.Message(
                    id: UUID().uuidString,
                    user: self.peer,
                    status: .read,
                    createdAt: Date(),
                    text: display,
                    attachments: [],
                    recording: nil,
                    replyMessage: nil
                )
                self.chatMessages.append(msg)
            }
        }

        // Connection state -> clear or keep messages on full disconnect (same logic as before)
        webrtc.$isConnected
            .removeDuplicates()
            .sink { [weak self] connected in
                guard let self else { return }
                if connected {
                    self.disconnectCleanupWorkItem?.cancel()
                    self.disconnectCleanupWorkItem = nil
                    self.finalDisconnect = false
                } else {
                    self.scheduleDisconnectCleanup()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Sending text from ExyteChat's didSendMessage
    func send(draft: ExyteChat.DraftMessage) {
        let text: String = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Optimistic local append
        let local = ExyteChat.Message(
            id: draft.id ?? UUID().uuidString,
            user: me,
            status: .sent,
            createdAt: draft.createdAt,
            text: text,
            attachments: [],
            recording: nil,
            replyMessage: nil
        )
        chatMessages.append(local)

        // Transport
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(ts)] [ChatViewModel] Sending message:", text)
        webrtc.sendMessage(text)

        // NOTE: if you need to react on delivery/ack - update status later
    }

    // MARK: - Sending media from ExyteChat (images/videos/audio)
    // Map DraftMessage.medias to your WebRTC file sender if you need it now.
    // This is a hook where you can request file URLs and call webrtc.sendMediaFile(...)
    func sendMediasFromDraft(_ draft: ExyteChat.DraftMessage) {
        // TODO: Convert draft.medias -> URLs and call webrtc.sendMediaFile(...)
        // For now we keep text-only minimal viable integration.
    }

    // MARK: - Manual file sharing (Documents picker or external URLs)
    func sendFile(url: URL) {
        var needsStop = false
        if url.startAccessingSecurityScopedResource() {
            needsStop = true
        }
        defer { if needsStop { url.stopAccessingSecurityScopedResource() } }

        let fileName = url.lastPathComponent
        let mime = ChatViewModel.mimeType(for: url)
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0

        // Local echo message (placeholder)
        let local = ExyteChat.Message(
            id: UUID().uuidString,
            user: me,
            status: .sent,
            createdAt: Date(),
            text: "Sending: \(fileName) (\(size) bytes)",
            attachments: [],
            recording: nil,
            replyMessage: nil
        )
        chatMessages.append(local)

        // Actual transport via your WebRTC pipe
        webrtc.sendMediaFile(id: local.id, url: url, name: fileName, mime: mime) { [weak self] progress in
            guard let self else { return }
            DispatchQueue.main.async {
                // You can update a progress UI by editing a custom attachment later
                print("[Upload] \(fileName) progress:", progress)
            }
        } completion: { [weak self] success in
            guard let self else { return }
            DispatchQueue.main.async {
                if !success {
                    self.chatMessages.removeAll { $0.id == local.id }
                } else {
                    // Optionally mark as read/delivered
                    if let idx = self.chatMessages.firstIndex(where: { $0.id == local.id }) {
                        self.chatMessages[idx].status = .read
                    }
                }
            }
        }
    }

    // MARK: - Utilities
    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "pdf": return "application/pdf"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        default: return "application/octet-stream"
        }
    }

    func clearMessages() {
        chatMessages.removeAll()
    }

    private func scheduleDisconnectCleanup() {
        let graceSeconds: Double = 10
        if disconnectCleanupWorkItem != nil { return }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            print("[ChatViewModel] Disconnect grace fired, isConnected=\(self.webrtc.isConnected), final=\(self.finalDisconnect)")
            if !self.webrtc.isConnected && !self.finalDisconnect {
                self.chatMessages.removeAll()
                self.finalDisconnect = true
            }
            self.disconnectCleanupWorkItem = nil
        }
        disconnectCleanupWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + graceSeconds, execute: work)
    }
}

// MARK: - Preview Extensions
extension ChatViewModel {
    /// Preview для подключенного состояния с сообщениями
    static var previewConnected: ChatViewModel {
        let vm = ChatViewModel()
        vm.webrtc.isConnected = true
        vm.webrtc.isChatEnabled = true
        vm.webrtc.dataChannelState = "открыт (1)"
        vm.webrtc.iceConnectionState = "1"
        vm.webrtc.iceGatheringState = "2"
        vm.webrtc.candidateCount = "5"
        
        // Добавляем тестовые сообщения
        vm.chatMessages = [
            ExyteChat.Message(
                id: "1",
                user: vm.me,
                status: .read,
                createdAt: Date().addingTimeInterval(-3600),
                text: "Привет! Как дела?",
                attachments: [],
                recording: nil,
                replyMessage: nil
            ),
            ExyteChat.Message(
                id: "2",
                user: vm.peer,
                status: .read,
                createdAt: Date().addingTimeInterval(-1800),
                text: "Привет! Все хорошо, спасибо. А у тебя?",
                attachments: [],
                recording: nil,
                replyMessage: nil
            ),
            ExyteChat.Message(
                id: "3",
                user: vm.me,
                status: .read,
                createdAt: Date().addingTimeInterval(-900),
                text: "Отлично! Готов к работе над проектом.",
                attachments: [],
                recording: nil,
                replyMessage: nil
            )
        ]
        
        return vm
    }
    
    /// Preview для ожидания соединения
    static var previewWaitingConnection: ChatViewModel {
        let vm = ChatViewModel()
        vm.webrtc.isConnected = false
        vm.webrtc.isChatEnabled = false
        vm.webrtc.dataChannelState = "не создан"
        vm.webrtc.iceConnectionState = "0"
        vm.webrtc.iceGatheringState = "0"
        vm.webrtc.candidateCount = "0"
        return vm
    }
    
    /// Preview для ожидания подтверждения отпечатков
    static var previewWaitingFingerprint: ChatViewModel {
        let vm = ChatViewModel()
        vm.webrtc.isConnected = true
        vm.webrtc.isChatEnabled = false
        vm.webrtc.dataChannelState = "создан (0)"
        vm.webrtc.iceConnectionState = "1"
        vm.webrtc.iceGatheringState = "2"
        vm.webrtc.candidateCount = "3"
        return vm
    }
}
