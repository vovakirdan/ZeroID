//
//  ContentView.swift
//  ZeroID
//
//  Created by Владимир Кирдан on 19.07.2025.
//

import SwiftUI
import UIKit

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
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            if isInteractiveBackEnabled {
                // Предыдущий экран под текущим (эффект наслоенности)
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
                .allowsHitTesting(false)
                .offset(x: min(0, -dragOffset * 0.1))
            }

            Group {
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
                            // Ничего не читаем автоматически — текст вводится пользователем или через кнопку Paste
                            offerState = .waitingForAnswer
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
                            // Пользователь вставляет вручную через UI — не подменяем из буфера автоматически
                        },
                        onGenerateAnswer: {
                            isLoading = true
                            vm.webrtc.receiveOffer(remoteSDP) { answerSDP in
                                if let answerSDP = answerSDP {
                                    mySDP = answerSDP
                                    answerState = .answerGenerated(answerSDP)
                                    connectionState = .answerGenerated(answerSDP)
                                    UIPasteboard.general.string = answerSDP
                                    showToast(message: "Answer скопирован в буфер")
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
                    ChatScreen(
                        vm: vm,
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
            }
            .offset(x: dragOffset)
            .shadow(color: Color.black.opacity(dragOffset > 0 ? 0.15 : 0), radius: 12, x: 0, y: 4)

            // Loading overlay
            LoadingOverlay(text: "Обработка...", isLoading: isLoading)
        }
        .toast(isVisible: $showToast, message: toastMessage)
        .highPriorityGesture(
            DragGesture()
                .onChanged { value in
                    guard isInteractiveBackEnabled else { return }
                    if value.translation.width > 0 && abs(value.translation.height) < 60 {
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    guard isInteractiveBackEnabled else { return }
                    let shouldPop = dragOffset > 100
                    if shouldPop {
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = UIScreen.main.bounds.width
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            navDirection = .backward
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                screen = .welcome
                            }
                            dragOffset = 0
                            resetState()
                        }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            dragOffset = 0
                        }
                    }
                }
        )
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
                UIPasteboard.general.string = sdp
                showToast(message: "Offer скопирован в буфер")
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

private extension ContentView {
    var isInteractiveBackEnabled: Bool {
        switch screen {
        case .welcome:
            return false
        default:
            return true
        }
    }
}

#Preview {
    ContentView()
}
