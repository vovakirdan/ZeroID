//
//  ContentView.swift
//  ZeroID
//
//  Created by Владимир Кирдан on 19.07.2025.
//

import SwiftUI

enum ConnectionState: Equatable {
    case idle
    case offerGenerated(String)
    case waitingForAnswer
    case answerGenerated(String)
    case connected
    case error(String)
}

struct ContentView: View {
    @StateObject var vm = ChatViewModel()
    @State private var mode: String? = nil
    @State private var remoteSDP: String = ""
    @State private var connectionState: ConnectionState = .idle

    var body: some View {
        VStack {
            if connectionState == .idle {
                Text("ZeroID P2P Demo")
                    .font(.largeTitle).padding(.bottom)
                HStack {
                    Button("Создать соединение") {
                        mode = "offer"
                        vm.webrtc.createOffer { sdp in
                            if let sdp = sdp {
                                connectionState = .offerGenerated(sdp)
                            } else {
                                connectionState = .error("Не удалось создать оффер")
                            }
                        }
                    }
                    .padding()
                    Button("Принять соединение") {
                        mode = "answer"
                    }
                    .padding()
                }
            }
            // Режим: Создаём оффер, ждём чтобы его скопировали
            if case .offerGenerated(let offerSDP) = connectionState {
                Text("Скопируй этот Offer и отправь другому клиенту:")
                    .padding(.top)
                VStack {
                    TextEditor(text: .constant(offerSDP))
                        .frame(height: 150)
                        .border(Color.gray)
                    Button("Копировать Offer") {
                        UIPasteboard.general.string = offerSDP
                    }
                    .padding(.horizontal)
                }
                .padding()
                Text("Вставь сюда Answer, полученный от peer:")
                    .padding(.top)
                TextEditor(text: $remoteSDP)
                    .frame(height: 150)
                    .border(Color.gray)
                    .padding()
                Button("Подтвердить Answer") {
                    vm.webrtc.receiveAnswer(remoteSDP)
                    connectionState = .connected
                }
                .padding()
            }
            // Режим: Вводим оффер, генерируем и копируем answer
            if mode == "answer", connectionState == .idle {
                Text("Вставь Offer, полученный от peer:")
                TextEditor(text: $remoteSDP)
                    .frame(height: 150)
                    .border(Color.gray)
                    .padding()
                Button("Сгенерировать Answer") {
                    vm.webrtc.receiveOffer(remoteSDP) { answerSDP in
                        if let answerSDP = answerSDP {
                            connectionState = .answerGenerated(answerSDP)
                        } else {
                            connectionState = .error("Не удалось принять оффер")
                        }
                    }
                }
                .padding()
            }
            if case .answerGenerated(let answerSDP) = connectionState {
                Text("Скопируй этот Answer и отправь peer'у:")
                VStack {
                    TextEditor(text: .constant(answerSDP))
                        .frame(height: 150)
                        .border(Color.gray)
                    Button("Копировать Answer") {
                        UIPasteboard.general.string = answerSDP
                    }
                    .padding(.horizontal)
                }
                .padding()
                Text("Ожидание соединения...")
                    .foregroundColor(.gray)
                    .padding()
            }
            if connectionState == .connected {
                VStack {
                    // Статус соединения для дебага
                    VStack(spacing: 4) {
                        Text("DataChannel: \(vm.webrtc.dataChannelState)")
                            .font(.caption)
                            .foregroundColor(vm.webrtc.isConnected ? .green : .orange)
                        Text("ICE: \(vm.webrtc.iceConnectionState)")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("Соединение: \(vm.webrtc.isConnected ? "активно" : "не готово")")
                            .font(.caption)
                            .foregroundColor(vm.webrtc.isConnected ? .green : .red)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    chatView
                }
            }
            if case .error(let err) = connectionState {
                Text("Ошибка: \(err)").foregroundColor(.red)
                Button("Назад") {
                    connectionState = .idle
                    mode = nil
                    remoteSDP = ""
                }
            }
        }
        .onReceive(vm.webrtc.$isConnected) { connected in
            print("[ContentView] isConnected changed to:", connected)
            if connected && connectionState != .connected {
                print("[ContentView] Transitioning to connected state")
                connectionState = .connected
            }
        }
        .padding()
    }

    var chatView: some View {
        VStack {
            if !vm.webrtc.isConnected {
                Text("⚠️ Ожидание установки соединения...")
                    .foregroundColor(.orange)
                    .padding()
            }
            
            List(vm.messages) { msg in
                HStack {
                    if msg.isMine { Spacer() }
                    Text(msg.text)
                        .padding(8)
                        .background(msg.isMine ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundColor(msg.isMine ? .white : .black)
                        .cornerRadius(8)
                    if !msg.isMine { Spacer() }
                }
            }
            HStack {
                TextField("Сообщение", text: $vm.inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Отправить") { 
                    if vm.webrtc.isConnected {
                        vm.sendMessage() 
                    } else {
                        print("[ContentView] Cannot send message - not connected")
                    }
                }
                .disabled(!vm.webrtc.isConnected)
            }
            .padding()
        }
    }
}


#Preview {
    ContentView()
}
