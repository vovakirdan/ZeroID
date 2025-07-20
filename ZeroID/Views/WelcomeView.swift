import SwiftUI

struct WelcomeView: View {
    var onCreate: () -> Void
    var onJoin: () -> Void
    var onSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Логотип с градиентом
            Image(systemName: "lock.shield")
                .resizable()
                .frame(width: 80, height: 90.0)
                .foregroundStyle(Color.primaryGradient)
                .padding(.bottom, 8)
            
            // Заголовок с акцентами
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("[")
                        .font(.largeTitle.bold())
                        .foregroundColor(Color.gradientStart)
                    Text("ZeroID")
                        .font(.largeTitle.bold())
                        .foregroundColor(Color.textPrimary)
                    Text("]")
                        .font(.largeTitle.bold())
                        .foregroundColor(Color.gradientEnd)
                }
                
                Text("Супер секретный чат с end-to-end шифрованием")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.textSecondary)
                    
            }
            
            Spacer()
            
            // Информационные карточки
            VStack(spacing: 16) {
                InfoCard(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "Приватные сообщения",
                    description: "Никто не может прочитать ваши сообщения"
                )
                
                InfoCard(
                    icon: "person.2.fill",
                    title: "P2P соединение",
                    description: "Прямое соединение без серверов"
                )
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                PrimaryButton(title: "Начать чат", arrow: true, action: onCreate)
                SecondaryButton(title: "Настройки", icon: "gear", action: onSettings)
            }
            .padding(.bottom, 16)
            
            Text("Для начала чата создайте QR-код или отсканируйте существующий")
                .font(.caption)
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)
        }
        .padding(.horizontal)
        .background(Color.background)
        .navigationBarHidden(true)
    }
}

struct InfoCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.primaryGradient)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color.textPrimary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.surfaceSecondary)
        .cornerRadius(12)
    }
}

#Preview {
    WelcomeView(
        onCreate: {},
        onJoin: {},
        onSettings: {}
    )
}

