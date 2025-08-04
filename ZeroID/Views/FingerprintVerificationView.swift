import SwiftUI

struct FingerprintVerificationView: View {
    @ObservedObject var webRTCManager: WebRTCManager
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Заголовок
            VStack(spacing: 12) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                Text("Сверка отпечатков")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color.textPrimary)
                Text("Сравните отпечатки для безопасного соединения")
                    .font(.body)
                    .foregroundColor(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Информация о соединении
            VStack(spacing: 16) {
                // Публичные ключи
                VStack(alignment: .leading, spacing: 8) {
                    Text("Публичные ключи")
                        .font(.headline)
                        .foregroundColor(Color.textPrimary)
                    
                    HStack {
                        Text("Ваш:")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                        Spacer()
                        Text(webRTCManager.myPubKey.prefix(16) + "...")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color.textPrimary)
                    }
                    
                    HStack {
                        Text("Собеседник:")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                        Spacer()
                        Text(webRTCManager.peerPubKey.prefix(16) + "...")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color.textPrimary)
                    }
                }
                .padding()
                .background(Color.card)
                .cornerRadius(12)
                
                // Отпечатки DTLS
                VStack(alignment: .leading, spacing: 8) {
                    Text("DTLS отпечатки")
                        .font(.headline)
                        .foregroundColor(Color.textPrimary)
                    
                    HStack {
                        Text("Ваш:")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                        Spacer()
                        Text(webRTCManager.myFingerprint.prefix(16) + "...")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color.textPrimary)
                    }
                    
                    HStack {
                        Text("Собеседник:")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                        Spacer()
                        Text(webRTCManager.peerFingerprint.prefix(16) + "...")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color.textPrimary)
                    }
                }
                .padding()
                .background(Color.card)
                .cornerRadius(12)
            }
            
            // Полные значения (скрытые по умолчанию)
            DisclosureGroup("Показать полные значения") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ваш публичный ключ:")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                        Text(webRTCManager.myPubKey)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color.textPrimary)
                            .textSelection(.enabled)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Публичный ключ собеседника:")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                        Text(webRTCManager.peerPubKey)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color.textPrimary)
                            .textSelection(.enabled)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ваш DTLS отпечаток:")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                        Text(webRTCManager.myFingerprint)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color.textPrimary)
                            .textSelection(.enabled)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DTLS отпечаток собеседника:")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                        Text(webRTCManager.peerFingerprint)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color.textPrimary)
                            .textSelection(.enabled)
                    }
                }
                .padding()
                .background(Color.muted)
                .cornerRadius(8)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Кнопки действий
            VStack(spacing: 12) {
                PrimaryButton(title: "Подтвердить соединение", arrow: false) {
                    webRTCManager.confirmFingerprintVerification()
                }
                
                SecondaryButton(title: "Отклонить соединение", icon: "xmark.circle") {
                    webRTCManager.rejectFingerprintVerification()
                }
                
                Button("Назад") {
                    onBack()
                }
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