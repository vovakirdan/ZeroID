import SwiftUI

struct LoaderView: View {
    let text: String
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
            
            Text(text)
                .font(.body)
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.surfaceSecondary)
                .shadow(color: Color.foreground.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

struct LoadingOverlay: View {
    let text: String
    let isLoading: Bool
    
    var body: some View {
        if isLoading {
            ZStack {
                Color.foreground.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { } // Блокируем взаимодействие
                
                LoaderView(text: text)
            }
            .transition(.opacity.combined(with: .scale))
        }
    }
}

#Preview {
    ZStack {
        Color.background.ignoresSafeArea()
        
        VStack {
            LoaderView(text: "Подключение...")
            Spacer()
        }
    }
}

