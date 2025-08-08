import SwiftUI

struct HandshakeView: View {
    let step: HandshakeStep
    let offerState: HandshakeOfferState?
    let answerState: HandshakeAnswerState?
    let sdpText: String
    @Binding var remoteSDP: String
    let onCopy: () -> Void
    let onPaste: () -> Void
    let onGenerateAnswer: (() -> Void)?
    let onContinue: () -> Void
    let onBack: () -> Void
    let isLoading: Bool
    
    @State private var showShareSheet = false
    @State private var showShareOptions = false
    @State private var shareItems: [Any] = []

    var body: some View {
        VStack {
            // Apple-style кнопка назад
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.backward")
                        .font(.title2)
                        .foregroundColor(Color.accentColor)
                }
                .padding(.leading, 4)
                Spacer()
            }
            .padding(.bottom, 8)
            
            StepHeader(
                title: step == .offer ? "Обмен оффером" : "Обмен ответом",
                subtitle: getStepSubtitle(),
                icon: step == .offer ? "arrowshape.turn.up.right.circle.fill" : "arrowshape.turn.up.left.circle.fill"
            )

            // Показываем поле для копирования только когда есть что копировать
            if shouldShowCopyField() {
                CopyField(
                    label: step == .offer ? "Твой Offer" : "Твой Answer",
                    value: sdpText,
                    onCopy: onCopy
                )
                .padding(.bottom, 14)
                
                // Кнопки действий для скопированного SDP
                HStack(spacing: 12) {
                    SecondaryButton(
                        title: "Копировать",
                        icon: "document.on.document",
                        action: onCopy
                    )
                    
                    SecondaryButton(
                        title: "Поделиться",
                        icon: "square.and.arrow.up",
                        action: { showShareOptions = true }
                    )
                }
                .padding(.bottom, 14)
            }
            
            // Показываем поле для вставки только когда нужно
            if shouldShowPasteField() {
                InputMethodView(
                    label: getPasteFieldLabel(),
                    inputText: $remoteSDP,
                    onPaste: onPaste
                )
                .padding(.bottom, 14)
            }
            
            // Убираем локальный лоадер, чтобы не дублировать глобальный оверлей
            
            // Кнопки действий в зависимости от состояния
            if let buttonConfig = getButtonConfig() {
                PrimaryButton(
                    title: buttonConfig.title,
                    arrow: false,
                    action: buttonConfig.action
                )
                .disabled(buttonConfig.isDisabled)
                .padding(.top, 8)
            }
            
            // Раздел: быстрый обмен (QR, AirDrop, Галерея)
            if shouldShowCopyField() || shouldShowPasteField() {
                QuickShareSection(step: step, sdpText: sdpText, remoteSDP: $remoteSDP, onPaste: onPaste)
                    .padding(.top, 20)
            }

            Spacer()
        }
        .padding(.horizontal)
        .animation(.easeInOut, value: isLoading)
        .background(Color.background)
        .navigationBarHidden(true)
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: shareItems)
        }
        .confirmationDialog("Поделиться", isPresented: $showShareOptions, titleVisibility: .visible) {
            Button("Текст") {
                // Отправляем только текст оффера/ансвера
                shareItems = [sdpText]
                showShareSheet = true
            }
            Button("QR-картинка") {
                // Генерируем QR и делимся картинкой
                if let img = QRUtils.generateQR(from: sdpText) {
                    shareItems = [img]
                    showShareSheet = true
                } else {
                    shareItems = [sdpText]
                    showShareSheet = true
                }
            }
            Button("Отмена", role: .cancel) {}
        }
    }
    
    // MARK: - Helper Methods
    
    private func getStepSubtitle() -> String {
        switch step {
        case .offer:
            if let offerState = offerState {
                switch offerState {
                case .offerGenerated:
                    return "Скопируй и отправь peer-у свой Offer.\nЖди Answer и вставь его ниже."
                case .waitingForAnswer:
                    return "Answer вставлен. Нажми 'Подтвердить' для продолжения."
                }
            }
            return "Скопируй и отправь peer-у свой Offer.\nЖди Answer и вставь его ниже."
            
        case .answer:
            if let answerState = answerState {
                switch answerState {
                case .waitingOffer:
                    return "Вставь Offer от peer-а и сгенерируй Answer."
                case .answerGenerated:
                    return "Answer сгенерирован. Скопируй и отправь peer-у.\nЗатем нажми 'Продолжить'."
                }
            }
            return "Вставь Offer от peer-а и сгенерируй Answer."
        }
    }
    
    private func shouldShowCopyField() -> Bool {
        switch step {
        case .offer:
            if let offerState = offerState {
                switch offerState {
                case .offerGenerated:
                    return true
                case .waitingForAnswer:
                    // Не скрываем поле оффера после вставки ответа — убираем дергание UI
                    return true
                }
            }
            return false
            
        case .answer:
            if let answerState = answerState {
                switch answerState {
                case .waitingOffer:
                    return false
                case .answerGenerated:
                    return true
                }
            }
            return false
        }
    }
    
    private func shouldShowPasteField() -> Bool {
        switch step {
        case .offer:
            if let offerState = offerState {
                switch offerState {
                case .offerGenerated:
                    return true
                case .waitingForAnswer:
                    return true
                }
            }
            return true
            
        case .answer:
            if let answerState = answerState {
                switch answerState {
                case .waitingOffer:
                    return true
                case .answerGenerated:
                    return false
                }
            }
            return true
        }
    }
    
    private func getPasteFieldLabel() -> String {
        switch step {
        case .offer:
            return "Вставь Answer от peer-а:"
        case .answer:
            return "Вставь Offer от peer-а:"
        }
    }
    
    private func getButtonConfig() -> (title: String, action: () -> Void, isDisabled: Bool)? {
        switch step {
        case .offer:
            if let offerState = offerState {
                switch offerState {
                case .offerGenerated:
                    return nil // Нет кнопки, только копирование
                case .waitingForAnswer:
                    return ("Подтвердить Answer", onContinue, isLoading)
                }
            }
            return nil
            
        case .answer:
            if let answerState = answerState {
                switch answerState {
                case .waitingOffer:
                    return ("Сгенерировать Answer", onGenerateAnswer ?? {}, isLoading || remoteSDP.isEmpty)
                case .answerGenerated:
                    return ("Продолжить", onContinue, isLoading)
                }
            }
            return ("Сгенерировать Answer", onGenerateAnswer ?? {}, isLoading || remoteSDP.isEmpty)
        }
    }
}

enum HandshakeStep {
    case offer
    case answer
}

#Preview {
    HandshakeView(
        step: .offer,
        offerState: .offerGenerated("test"),
        answerState: nil,
        sdpText: "sdpText",
        remoteSDP: .constant("remoteSDP"),
        onCopy: {},
        onPaste: {},
        onGenerateAnswer: nil,
        onContinue: {},
        onBack: {},
        isLoading: false
    )
}
