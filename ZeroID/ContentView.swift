//
//  ContentView.swift
//  ZeroID
//
//  Created by Владимир Кирдан on 19.07.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject var vm = ChatViewModel()

    var body: some View {
        VStack {
            List(vm.messages) { msg in
                HStack {
                    if msg.isMine { Spacer() }
                    Text(msg.text)
                        .padding(8)
                        .background(msg.isMine ? Color.blue : Color.gray.opacity(0.3))
                        .cornerRadius(8)
                    if !msg.isMine { Spacer() }
                }
            }
            HStack {
                TextField("Сообщение", text: $vm.inputText)
                Button("Отправить") { vm.sendMessage() }
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
