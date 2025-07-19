import SwiftUI

struct ChatView: View {
    @ObservedObject var vm: ChatViewModel
    let connectionState: ConnectionState
    let onBack: () -> Void
    
    var body: some View {
        VStack {
            // Заголовок с кнопкой назад
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                Spacer()
                Text("P2P Чат")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            // Статус соединения для дебага
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
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            
            // Чат
            if !vm.webrtc.isConnected {
                VStack(spacing: 16) {
                    LoaderView(text: "Ждём соединения...")
                    Text("⚠️ Ожидание установки соединения...")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                .padding()
            } else {
                List(vm.messages) { msg in
                    ChatBubble(
                    text: msg.text,
                    isMine: msg.isMine,
                    timestamp: msg.date
                )
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
            
            HStack {
                TextField("Сообщение", text: $vm.inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Отправить") { 
                    if vm.webrtc.isConnected {
                        vm.sendMessage() 
                    } else {
                        print("[ChatView] Cannot send message - not connected")
                    }
                }
                .disabled(!vm.webrtc.isConnected)
            }
            .padding()
        }
        .background(Color.background.ignoresSafeArea())
    }
}

#Preview {
    ChatView(
        vm: ChatViewModel(),
        connectionState: .connected,
        onBack: {}
    )
}
