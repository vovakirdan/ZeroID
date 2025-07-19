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
                TextEditor(text: .constant(offerSDP))
                    .frame(height: 150)
                    .border(Color.gray)
                    .padding()
                TextField("Вставь сюда Answer, полученный от peer", text: $remoteSDP)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
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
                TextEditor(text: .constant(answerSDP))
                    .frame(height: 150)
                    .border(Color.gray)
                    .padding()
                Button("Перейти в чат") {
                    connectionState = .connected
                }
                .padding()
            }
            if connectionState == .connected {
                chatView
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
        .padding()
    }

    var chatView: some View {
        VStack {
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
                Button("Отправить") { vm.sendMessage() }
            }
            .padding()
        }
    }
}


#Preview {
    ContentView()
}
