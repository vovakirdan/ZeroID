import SwiftUI

struct ToastView: View {
    let message: String
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(Color.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.surfaceSecondary)
                    .shadow(color: Color.foreground.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct ToastManager: ViewModifier {
    @Binding var isVisible: Bool
    let message: String
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            VStack {
                ToastView(message: message, isVisible: isVisible)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isVisible)
                Spacer()
            }
            .padding(.top, 60)
        }
    }
}

extension View {
    func toast(isVisible: Binding<Bool>, message: String) -> some View {
        modifier(ToastManager(isVisible: isVisible, message: message))
    }
}

struct ToastView_Previews: PreviewProvider {
    static var previews: some View {
    ZStack {
        Color.background.ignoresSafeArea()
        
        VStack {
            Text("Основной контент")
            Spacer()
        }
    }
    .toast(isVisible: .constant(true), message: "Скопировано в буфер обмена")
    }
} 
