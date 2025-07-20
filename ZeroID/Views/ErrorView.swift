import SwiftUI

struct ErrorView: View {
    let error: String
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Ошибка")
                .font(.title)
                .fontWeight(.bold)
            
            Text(error)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(Color.textSecondary)
            
            PrimaryButton(title: "Назад", arrow: false, action: onBack)
            
            Spacer()
        }
        .padding(.horizontal)
        .background(Color.background)
        .navigationBarHidden(true)
    }
}

#Preview {
    ErrorView(
        error: "Не удалось установить соединение",
        onBack: {}
    )
}
