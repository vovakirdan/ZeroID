import SwiftUI

struct FingerprintVerificationView: View {
    @ObservedObject var webRTCManager: WebRTCManager
    let onBack: () -> Void
    
    @State private var codesMatch: Bool = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Заголовок
            VStack(spacing: 10) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.primaryGradient)
                Text("Сверка отпечатков")
                    .font(.title.bold())
                    .foregroundColor(Color.textPrimary)
                Text("Убедитесь, что отпечатки совпадают на обоих устройствах")
                    .font(.subheadline)
                    .foregroundColor(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            // Центральный SAS-код крупным шрифтом
            VStack {
                Text(webRTCManager.sasCode.isEmpty ? "—" : webRTCManager.sasCode)
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.textPrimary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.card)
                    .cornerRadius(12)
            }
            .padding(.horizontal)

            Text("Оба устройства должны показывать одинаковый код. Только при совпадении кодов можно безопасно общаться.")
                .font(.footnote)
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Чекбокс подтверждения
            Toggle(isOn: $codesMatch) {
                Text("Я вижу одинаковый код на обоих устройствах")
                    .foregroundColor(Color.textPrimary)
            }
            .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
            .padding(.horizontal)

            Spacer()

            // Кнопки действий
            VStack(spacing: 12) {
                PrimaryButton(title: "Коды совпадают — продолжить", arrow: false) {
                    // Подтверждаем сверку только если пользователь отметил совпадение
                    guard codesMatch else { return }
                    webRTCManager.confirmFingerprintVerification()
                }
                .disabled(!codesMatch)
                
                SecondaryButton(title: "Коды не совпадают", icon: "xmark.circle") {
                    webRTCManager.rejectFingerprintVerification()
                }
                
                Button("Назад") { onBack() }
                    .font(.body)
                    .foregroundColor(Color.textSecondary)
            }
            .padding(.horizontal, 20)
        }
        .padding()
        .background(Color.surfacePrimary.ignoresSafeArea())
    }
}

#Preview {
    FingerprintVerificationView(
        webRTCManager: WebRTCManager(),
        onBack: {}
    )
} 