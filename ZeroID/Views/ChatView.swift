import SwiftUI

struct ChatView: View {
    @ObservedObject var vm: ChatViewModel
    let connectionState: ConnectionState
    let onBack: () -> Void
    
    // Градиентные цвета для фона чата
    private var chatGradientColors: [Color] {
        [
            Color(red: 0.0, green: 0.15, blue: 0.2, opacity: 1.0),
            Color(red: 0.0, green: 0.1, blue: 0.15, opacity: 1.0),
            Color(red: 0.02, green: 0.08, blue: 0.12, opacity: 1.0)
        ]
    }
    
    // Градиентный фон чата
    private var chatBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: chatGradientColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea(.all)
    }
    
    // Состояние ожидания соединения
    private var waitingConnectionView: some View {
        VStack(spacing: 16) {
            LoaderView(text: "Ждём соединения...")
            Text("⚠️ Ожидание установки соединения...")
                .foregroundColor(.orange)
                .font(.caption)
        }
        .padding()
    }
    
    // Список сообщений
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(vm.messages) { msg in
                        ChatBubble(
                            text: msg.text,
                            isMine: msg.isMine,
                            timestamp: msg.date
                        )
                        .id(msg.id)
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: vm.messages.count) { oldCount, newCount in
                if let lastMessage = vm.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // Область чата
    private var chatArea: some View {
        ZStack {
            chatBackground
            
            if !vm.webrtc.isConnected {
                waitingConnectionView
            } else {
                messagesList
            }
        }
    }
    
    // Проверка возможности отправки сообщения
    private var canSendMessage: Bool {
        vm.webrtc.isConnected && !vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // Текстовое поле ввода
    private var textInputField: some View {
        HStack {
            TextField("Введите сообщение...", text: $vm.inputText, axis: .vertical)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .lineLimit(1...5)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.12, opacity: 0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(vm.inputText.isEmpty ? Color.gray.opacity(0.3) : Color.accentColor, lineWidth: 1)
        )
    }
    
    // Кнопка отправки
    private var sendButton: some View {
        Button(action: {
            if canSendMessage {
                vm.sendMessage() 
            } else {
                print("[ChatView] Cannot send message - not connected or empty")
            }
        }) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title2)
                .foregroundStyle(
                    canSendMessage ? 
                    AnyShapeStyle(Color.primaryGradient) : 
                    AnyShapeStyle(Color.gray.opacity(0.5))
                )
        }
        .disabled(!canSendMessage)
        .scaleEffect(canSendMessage ? 1.0 : 0.8)
        .animation(.spring(response: 0.3), value: vm.inputText)
    }
    
    // Область ввода сообщений
    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack(spacing: 12) {
                textInputField
                sendButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(Color.black.opacity(0.8))
                    .blur(radius: 20)
            )
        }
    }
    
    // Заголовок с кнопкой назад
    private var headerView: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.backward")
                    .font(.title2)
                    .foregroundColor(Color.accentColor)
            }
            .padding(.leading, 4)
            
            Spacer()
            
            Text("Секретный чат")
                .font(.headline)
                .foregroundColor(Color.textPrimary)
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    // Статус соединения для дебага
    private var connectionStatusView: some View {
        VStack(spacing: 4) {
            Text("DataChannel: \(vm.webrtc.dataChannelState)")
                .font(.caption)
                .foregroundColor(vm.webrtc.isConnected ? .green : .orange)
            Text("ICE: \(vm.webrtc.iceConnectionState)")
                .font(.caption)
                .foregroundColor(.blue)
            Text("\(vm.webrtc.iceGatheringState)")
                .font(.caption)
                .foregroundColor(.purple)
            Text("Кандидаты: \(vm.webrtc.candidateCount)")
                .font(.caption)
                .foregroundColor(.brown)
            Text("Соединение: \(vm.webrtc.isConnected ? "активно" : "не готово")")
                .font(.caption)
                .foregroundColor(vm.webrtc.isConnected ? .green : .red)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.surfaceMuted)
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    var body: some View {
        VStack {
            headerView
            connectionStatusView
            chatArea
            inputArea
        }
        .background(Color.background)
        .navigationBarHidden(true)
    }
}

#Preview {
    ChatView(
        vm: ChatViewModel(),
        connectionState: .connected,
        onBack: {}
    )
}
