import SwiftUI

struct ChatView: View {
    @ObservedObject var vm: ChatViewModel
    let connectionState: ConnectionState
    let onBack: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    // Адаптивный градиентный фон чата
    private var chatBackground: some View {
        if colorScheme == .dark {
            // Темная тема - градиент темно-синих оттенков
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.0, green: 0.05, blue: 0.1),
                    Color(red: 0.05, green: 0.1, blue: 0.15),
                    Color(red: 0.02, green: 0.08, blue: 0.12)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(.all)
        } else {
            // Светлая тема - светлый градиент
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                    Color(red: 0.92, green: 0.95, blue: 0.98),
                    Color(red: 0.90, green: 0.93, blue: 0.96)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(.all)
        }
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
    
    // Цвет фона инпут поля в зависимости от темы
    private var inputFieldBackground: Color {
        if colorScheme == .dark {
            return Color(red: 0.12, green: 0.12, blue: 0.12, opacity: 0.7)
        } else {
            return Color(red: 0.95, green: 0.95, blue: 0.95, opacity: 0.8)
        }
    }
    
    // Цвет рамки инпут поля
    private var inputFieldBorder: Color {
        if vm.inputText.isEmpty {
            return colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.5)
        } else {
            return Color.accentColor
        }
    }
    
    // Текстовое поле ввода
    private var textInputField: some View {
        HStack {
            TextField("Введите сообщение...", text: $vm.inputText, axis: .vertical)
                .font(.body)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .lineLimit(1...5)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(inputFieldBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(inputFieldBorder, lineWidth: 1)
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
    
    // Область ввода сообщений с адаптивным фоном
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
                    .fill(
                        colorScheme == .dark 
                        ? Color.black.opacity(0.8) 
                        : Color.white.opacity(0.9)
                    )
                    .blur(radius: 10)
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
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    colorScheme == .dark 
                    ? Color.surfaceMuted 
                    : Color.gray.opacity(0.1)
                )
        )
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
    let mockVM = ChatViewModel()
    
    // Создаем разнообразные сообщения для полного тестирования интерфейса
    let now = Date()
    mockVM.messages = [
        // Сообщения собеседника
        Message(text: "Привет! 👋 Как дела?", isMine: false, date: now.addingTimeInterval(-600)),
        Message(text: "Ты уже протестировал новый интерфейс чата?", isMine: false, date: now.addingTimeInterval(-500)),
        Message(text: "Это очень длинное сообщение для проверки корректного переноса текста на несколько строк в пузырьке чата. Должно выглядеть красиво и читаемо.", isMine: false, date: now.addingTimeInterval(-400)),
        
        // Мои сообщения
        Message(text: "Привет! Все отлично, спасибо! 😊", isMine: true, date: now.addingTimeInterval(-350)),
        Message(text: "Да, интерфейс получился классный!", isMine: true, date: now.addingTimeInterval(-300)),
        Message(text: "Короткое", isMine: true, date: now.addingTimeInterval(-250)),
        
        // Еще сообщения собеседника
        Message(text: "Отлично! 🎉", isMine: false, date: now.addingTimeInterval(-200)),
        Message(text: "Когда планируешь релиз?", isMine: false, date: now.addingTimeInterval(-150)),
        
        // Еще мои сообщения
        Message(text: "На следующей неделе, если все пройдет тестирование", isMine: true, date: now.addingTimeInterval(-100)),
        Message(text: "🤞", isMine: true, date: now.addingTimeInterval(-50))
    ]
    
    // Устанавливаем состояние соединения для отображения чата
    mockVM.webrtc.isConnected = true

    return ChatView(
        vm: mockVM,
        connectionState: .connected,
        onBack: {}
    )
}
