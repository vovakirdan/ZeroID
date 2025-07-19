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

enum Screen {
    case welcome
    case handshakeOffer
    case handshakeAnswer
    case chat
    case settings
    case error(String)
}

struct ContentView: View {
    @StateObject var vm = ChatViewModel()
    @State private var screen: Screen = .welcome
    @State private var remoteSDP: String = ""
    @State private var mySDP: String = ""
    @State private var isLoading = false
    @State private var connectionState: ConnectionState = .idle
    @State private var showToast = false
    @State private var toastMessage = ""

    var body: some View {
        ZStack {
            Group {
                switch screen {
                case .welcome:
                    WelcomeView(
                        onCreate: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                screen = .handshakeOffer
                            }
                            createOffer()
                        },
                        onJoin: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                screen = .handshakeAnswer
                            }
                        },
                        onSettings: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                screen = .settings
                            }
                        }
                    )
                    
                case .settings:
                    SettingsView(
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                screen = .welcome
                            }
                        }
                    )
                    
                case .handshakeOffer:
                    HandshakeView(
                        step: .offer,
                        sdpText: mySDP,
                        remoteSDP: $remoteSDP,
                        onCopy: { 
                            UIPasteboard.general.string = mySDP
                            showToast(message: "SDP скопирован в буфер")
                        },
                        onPaste: { 
                            if let pastedText = UIPasteboard.general.string {
                                remoteSDP = pastedText
                                showToast(message: "SDP вставлен из буфера")
                            }
                        },
                        onContinue: {
                            isLoading = true
                            vm.webrtc.receiveAnswer(remoteSDP)
                            connectionState = .connected
                            isLoading = false
                            withAnimation(.easeInOut(duration: 0.3)) {
                                screen = .chat
                            }
                        },
                        onBack: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                screen = .welcome
                            }
                            resetState()
                        },
                        isLoading: isLoading
                    )
                    
                case .handshakeAnswer:
                    HandshakeView(
                        step: .answer,
                        sdpText: mySDP,
                        remoteSDP: $remoteSDP,
                        onCopy: { 
                            UIPasteboard.general.string = mySDP
                            showToast(message: "SDP скопирован в буфер")
                        },
                        onPaste: { 
                            if let pastedText = UIPasteboard.general.string {
                                remoteSDP = pastedText
                                showToast(message: "SDP вставлен из буфера")
                            }
                        },
                        onContinue: {
                            isLoading = true
                            vm.webrtc.receiveOffer(remoteSDP) { answerSDP in
                                if let answerSDP = answerSDP {
                                    mySDP = answerSDP
                                    connectionState = .answerGenerated(answerSDP)
                                    isLoading = false
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        screen = .chat
                                    }
                                } else {
                                    isLoading = false
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        screen = .error("Не удалось принять оффер")
                                    }
                                }
                            }
                        },
                        onBack: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                screen = .welcome
                            }
                            resetState()
                        },
                        isLoading: isLoading
                    )
                    
                case .chat:
                    ChatView(
                        vm: vm,
                        connectionState: connectionState,
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                screen = .welcome
                            }
                            resetState()
                        }
                    )
                    
                case .error(let error):
                    ErrorView(
                        error: error,
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                screen = .welcome
                            }
                            resetState()
                        }
                    )
                }
            }
            
            // Loading overlay
            LoadingOverlay(text: "Обработка...", isLoading: isLoading)
        }
        .toast(isVisible: $showToast, message: toastMessage)
        .onReceive(vm.webrtc.$isConnected) { connected in
            print("[ContentView] isConnected changed to:", connected)
            if connected && connectionState != .connected {
                print("[ContentView] Transitioning to connected state")
                connectionState = .connected
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func createOffer() {
        vm.webrtc.createOffer { sdp in
            if let sdp = sdp {
                mySDP = sdp
                connectionState = .offerGenerated(sdp)
            } else {
                screen = .error("Не удалось создать оффер")
            }
        }
    }
    
    private func resetState() {
        remoteSDP = ""
        mySDP = ""
        isLoading = false
        connectionState = .idle
    }
    
    private func showToast(message: String) {
        toastMessage = message
        showToast = true
        
        // Автоматически скрыть toast через 2 секунды
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.3)) {
                showToast = false
            }
        }
    }
}

#Preview {
    ContentView()
}
