import SwiftUI

struct ChoiceView: View {
    let onCreateOffer: () -> Void
    let onAcceptOffer: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
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
            
            Spacer()
            
            // Заголовок
            VStack(spacing: 12) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.primaryGradient)
                
                Text("Выбери действие")
                    .font(.largeTitle.bold())
                    .foregroundColor(Color.textPrimary)
                
                Text("Создай новый чат или присоединись к существующему")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.textSecondary)
            }
            
            Spacer()
            
            // Карточки выбора
            VStack(spacing: 20) {
                // Создать оффер
                ChoiceCard(
                    icon: "plus.circle.fill",
                    title: "Создать чат",
                    description: "Создай новый зашифрованный чат и поделись с другим пользователем",
                    gradientColors: [Color.gradientStart, Color.gradientEnd],
                    action: onCreateOffer
                )
                
                // Принять оффер
                ChoiceCard(
                    icon: "qrcode.viewfinder",
                    title: "Присоединиться к чату",
                    description: "Присоединись к существующему чату по QR-коду или ключу",
                    gradientColors: [Color.accentColor, Color.secondaryColor],
                    action: onAcceptOffer
                )
            }
            
            Spacer()
            
            // Информация
            Text("Оба способа обеспечивают end-to-end шифрование")
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

struct ChoiceCard: View {
    let icon: String
    let title: String
    let description: String
    let gradientColors: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(Color.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(Color.textSecondary)
            }
            .padding(20)
            .background(Color.surfaceSecondary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.borderPrimary, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ChoiceView(
        onCreateOffer: {},
        onAcceptOffer: {},
        onBack: {}
    )
} 