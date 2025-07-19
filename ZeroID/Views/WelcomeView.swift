import SwiftUI

struct WelcomeView: View {
    var onCreate: () -> Void
    var onJoin: () -> Void
    var onSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Логотип
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
                .padding(.bottom, 8)
            
            Text("ZeroID")
                .font(.largeTitle.bold())
                .foregroundColor(.primary)
            
            Text("P2P чат без серверов\nБыстро. Безопасно. Приватно.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Spacer()
            
            VStack(spacing: 16) {
                PrimaryButton(title: "Создать соединение", action: onCreate)
                SecondaryButton(title: "Принять соединение", action: onJoin)
            }
            .padding(.bottom, 16)
            
            // Кнопка настроек
            Button(action: onSettings) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                        .font(.body)
                    Text("Настройки")
                        .font(.body)
                }
                .foregroundColor(.secondary)
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal)
        .background(Color("Background"))
    }
}

#Preview {
    WelcomeView(
        onCreate: {},
        onJoin: {},
        onSettings: {}
    )
}

