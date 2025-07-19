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
    case error(String)
}

struct ContentView: View {
    @StateObject var vm = ChatViewModel()
    @State private var screen: Screen = .welcome
    @State private var remoteSDP: String = ""
    @State private var mySDP: String = ""
    @State private var isLoading = false
    @State private var connectionState: ConnectionState = .idle

    var body: some View {
        Group {
            switch screen {
            case .welcome:
                WelcomeView(
                    onCreate: { 
                        screen = .handshakeOffer
                        createOffer()
                    },
                    onJoin: { 
                        screen = .handshakeAnswer
                    }
                )
                
            case .handshakeOffer:
                HandshakeView(
                    step: .offer,
                    sdpText: mySDP,
                    remoteSDP: $remoteSDP,
                    onCopy: { 
                        UIPasteboard.general.string = mySDP
                        // TODO: показать toast
                    },
                    onPaste: { 
                        // TODO: показать toast
                    },
                    onContinue: {
                        isLoading = true
                        vm.webrtc.receiveAnswer(remoteSDP)
                        connectionState = .connected
                        isLoading = false
                        screen = .chat
                    },
                    onBack: { 
                        screen = .welcome
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
                        // TODO: показать toast
                    },
                    onPaste: { 
                        // TODO: показать toast
                    },
                    onContinue: {
                        isLoading = true
                        vm.webrtc.receiveOffer(remoteSDP) { answerSDP in
                            if let answerSDP = answerSDP {
                                mySDP = answerSDP
                                connectionState = .answerGenerated(answerSDP)
                                isLoading = false
                                screen = .chat
                            } else {
                                isLoading = false
                                screen = .error("Не удалось принять оффер")
                            }
                        }
                    },
                    onBack: { 
                        screen = .welcome
                        resetState()
                    },
                    isLoading: isLoading
                )
                
            case .chat:
                ChatView(
                    vm: vm,
                    connectionState: connectionState,
                    onBack: {
                        screen = .welcome
                        resetState()
                    }
                )
                
            case .error(let error):
                ErrorView(
                    error: error,
                    onBack: {
                        screen = .welcome
                        resetState()
                    }
                )
            }
        }
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
}



#Preview {
    ContentView()
}
