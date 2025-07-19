import SwiftUI

struct HandshakeView: View {
    let step: HandshakeStep
    let sdpText: String
    @Binding var remoteSDP: String
    let onCopy: () -> Void
    let onPaste: () -> Void
    let onContinue: () -> Void
    let onBack: () -> Void
    let isLoading: Bool

    var body: some View {
        VStack {
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
            }
            .padding(.bottom, 4)
            
            StepHeader(
                title: step == .offer ? "Обмен оффером" : "Обмен ответом",
                subtitle: step == .offer
                    ? "Скопируй и отправь peer-у свой Offer.\nЖди Answer и вставь его ниже."
                    : "Вставь Offer от peer-а, сгенерируй Answer и отправь обратно.",
                icon: step == .offer ? "arrowshape.turn.up.right.circle.fill" : "arrowshape.turn.up.left.circle.fill"
            )

            CopyField(
                label: step == .offer ? "Твой Offer" : "Твой Answer",
                value: sdpText,
                onCopy: onCopy
            )
            .padding(.bottom, 14)
            
            VStack(alignment: .leading, spacing: 10) {
                Text(step == .offer ? "Вставь Answer от peer-а:" : "Вставь Offer от peer-а:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    TextEditor(text: $remoteSDP)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 100)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray5), lineWidth: 1))
                    Button(action: {
                        if let clipboard = UIPasteboard.general.string {
                            remoteSDP = clipboard
                            onPaste()
                        }
                    }) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                    }
                    .padding(.trailing, 4)
                }
            }
            .padding(.bottom, 14)
            
            if isLoading {
                LoaderView()
            }
            
            PrimaryButton(title: step == .offer ? "Подтвердить Answer" : "Сгенерировать Answer", action: onContinue)
                .disabled(isLoading || remoteSDP.isEmpty)
                .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal)
        .animation(.easeInOut, value: isLoading)
        .background(Color.background.ignoresSafeArea())
    }
}

enum HandshakeStep {
    case offer
    case answer
}

