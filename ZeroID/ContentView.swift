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
    case choice
    case handshakeOffer
    case handshakeAnswer
    case fingerprintVerification
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
    @State private var offerState: HandshakeOfferState = .offerGenerated("")
    @State private var answerState: HandshakeAnswerState = .waitingOffer
    @State private var navDirection: NavigationDirection = .forward

    var body: some View {
        ZStack {
            switch screen {
                case .welcome:
                    WelcomeView(
                        onCreate: { 
                            navDirection = .forward
                            withAnimation(.easeInOut(duration: 0.3)) {
                                screen = .choice
                            }
                        },
                        onSettings: {
                            navDirection = .forward
                            withAnimation(.easeInOut(duration: 0.3)) {
                                screen = .settings
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: navDirection == .forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: navDirection == .forward ? .leading : .trailing).combined(with: .opacity)
                    ))
                    
                case .settings:
                    SettingsView(
                        onBack: {
                            navDirection = .backward
                            withAnimation(.easeInOut(duration: 0.3)) {
                                screen = .welcome
                            }
                        }
                    )
                    .gesture(
                        DragGesture()
                            .onEnded { gesture in
                                if gesture.translation.width > 100 && abs(gesture.translation.height) < 50 {
                                    navDirection = .backward
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        screen = .welcome
                                    }
                                }
                            }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: navDirection == .forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: navDirection == .forward ? .leading : .trailing).combined(with: .opacity)
                    ))
                    
                case .choice:
                    ChoiceView(
                        onCreateOffer: { 
                            navDirection = .forward
                            withAnimation(.easeInOut(duration: 0.3)) {
                                screen = .handshakeOffer
                            }
                            createOffer()
                        },
                        onAcceptOffer: { 
                            navDirection = .forward
                            withAnimation(.easeInOut(duration: 0.3)) {
                                screen = .handshakeAnswer
                                answerState = .waitingOffer
                            }
                        },
                        onBack: {
                            navDirection = .backward
                            withAnimation(.easeInOut(duration: 0.3)) {
                                screen = .welcome
                            }
                            resetState()
                        }
                    )
                    .gesture(
                        DragGesture()
                            .onEnded { gesture in
                                if gesture.translation.width > 100 && abs(gesture.translation.height) < 50 {
                                    navDirection = .backward
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        screen = .welcome
                                    }
                                    resetState()
                                }
                            }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: navDirection == .forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: navDirection == .forward ? .leading : .trailing).combined(with: .opacity)
                    ))
                    
                case .handshakeOffer:
                    HandshakeView(
                        step: .offer,
                        offerState: offerState,
                        answerState: nil,
                        sdpText: mySDP,
                        remoteSDP: $remoteSDP,
                        onCopy: { 
                            UIPasteboard.general.string = mySDP
                            showToast(message: "SDP скопирован в буфер")
                        },
                        onPaste: { 
                            if let pastedText = UIPasteboard.general.string {
                                remoteSDP = pastedText
                                offerState = .waitingForAnswer
                                showToast(message: "SDP вставлен из буфера")
                            }
                        },
                        onGenerateAnswer: nil,
                        onContinue: {
                            // Принимаем answer и ЖДЁМ события .verificationRequired для перехода
                            vm.webrtc.receiveAnswer(remoteSDP)
                        },
                        onBack: { 
                            navDirection = .backward
                            withAnimation(.easeInOut(duration: 0.3)) {
                                screen = .welcome
                            }
                            resetState()
                        },
                        isLoading: isLoading
                    )
                    .gesture(
                        DragGesture()
                            .onEnded { gesture in
                                if gesture.translation.width > 100 && abs(gesture.translation.height) < 50 {
                                    navDirection = .backward
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        screen = .welcome
                                    }
                                    resetState()
                                }
                            }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: navDirection == .forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: navDirection == .forward ? .leading : .trailing).combined(with: .opacity)
                    ))
                    
                case .handshakeAnswer:
                    HandshakeView(
                        step: .answer,
                        offerState: nil,
                        answerState: answerState,
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
                        onGenerateAnswer: {
                            isLoading = true
                            vm.webrtc.receiveOffer(remoteSDP) { answerSDP in
                                if let answerSDP = answerSDP {
                                    mySDP = answerSDP
                                    answerState = .answerGenerated(answerSDP)
                                    connectionState = .answerGenerated(answerSDP)
                                    isLoading = false
                                } else {
                                    isLoading = false
                                    navDirection = .forward
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        screen = .error("Не удалось принять оффер")
                                    }
                                }
                            }
                        },
                        onContinue: {
                            // ЖДЁМ события .verificationRequired от WebRTCManager
                        },
                        onBack: { 
                            navDirection = .backward
                            withAnimation(.easeInOut(duration: 0.3)) {
                                screen = .welcome
                            }
                            resetState()
                        },
                        isLoading: isLoading
                    )
                    .gesture(
                        DragGesture()
                            .onEnded { gesture in
                                if gesture.translation.width > 100 && abs(gesture.translation.height) < 50 {
                                    navDirection = .backward
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        screen = .welcome
                                    }
                                    resetState()
                                }
                            }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: navDirection == .forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: navDirection == .forward ? .leading : .trailing).combined(with: .opacity)
                    ))
                    
                case .chat:
                    ChatView(
                        vm: vm,
                        connectionState: connectionState,
                        onBack: {
                            navDirection = .backward
                            withAnimation(.easeInOut(duration: 0.3)) {
                                screen = .welcome
                            }
                            resetState()
                        }
                    )
                    .gesture(
                        DragGesture()
                            .onEnded { gesture in
                                if gesture.translation.width > 100 && abs(gesture.translation.height) < 50 {
                                    navDirection = .backward
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        screen = .welcome
                                    }
                                    resetState()
                                }
                            }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: navDirection == .forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: navDirection == .forward ? .leading : .trailing).combined(with: .opacity)
                    ))
                    
                case .fingerprintVerification:
                    FingerprintVerificationView(
                        webRTCManager: vm.webrtc,
                        onBack: {
                            navDirection = .backward
                            withAnimation(.easeInOut(duration: 0.3)) {
                                screen = .welcome
                            }
                            resetState()
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: navDirection == .forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: navDirection == .forward ? .leading : .trailing).combined(with: .opacity)
                    ))
                    
                case .error(let error):
                    ErrorView(
                        error: error,
                        onBack: {
                            navDirection = .backward
                            withAnimation(.easeInOut(duration: 0.3)) {
                                screen = .welcome
                            }
                            resetState()
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: navDirection == .forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: navDirection == .forward ? .leading : .trailing).combined(with: .opacity)
                    ))
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
        .onReceive(vm.webrtc.$fingerprintVerificationState) { state in
            print("[ContentView] Fingerprint verification state changed to:", state)
            switch state {
            case .verificationRequired:
                withAnimation(.easeInOut(duration: 0.3)) {
                    screen = .fingerprintVerification
                }
            case .verified:
                withAnimation(.easeInOut(duration: 0.3)) {
                    screen = .chat
                }
            case .failed:
                showToast(message: "Сверка отпечатков не удалась")
            default:
                break
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func createOffer() {
        vm.webrtc.createOffer { sdp in
            if let sdp = sdp {
                mySDP = sdp
                offerState = .offerGenerated(sdp)
                connectionState = .offerGenerated(sdp)
            } else {
                screen = .error("Не удалось создать оффер")
            }
        }
    }
    
    private func resetState() {
        // Очищаем историю сообщений и сбрасываем WebRTC соединение
        vm.clearMessages()
        vm.webrtc.resetConnection()

        remoteSDP = ""
        mySDP = ""
        isLoading = false
        connectionState = .idle
        offerState = .offerGenerated("")
        answerState = .waitingOffer
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

enum NavigationDirection {
    case forward
    case backward
}

#Preview {
    ContentView()
}
