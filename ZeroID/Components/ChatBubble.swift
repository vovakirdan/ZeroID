import SwiftUI

struct ChatBubble: View {
    let text: String
    let isMine: Bool
    let timestamp: Date
    
    // Цвет фона для моих сообщений с улучшенной читаемостью
    private var myMessageBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.2, green: 0.9, blue: 0.6), // Синий
                        Color(red: 0.3, green: 0.7, blue: 1.0)  // Светло-синий
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
    
    // Цвет фона для чужих сообщений
    private var otherMessageBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(red: 0.15, green: 0.15, blue: 0.15, opacity: 0.85))
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isMine { 
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                HStack {
                    if isMine {
                        Spacer()
                    }
                    
                    Text(text)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            isMine ? AnyView(myMessageBackground) : AnyView(otherMessageBackground)
                        )
                        .foregroundColor(.white)
                    
                    if !isMine {
                        Spacer()
                    }
                }
                
                // Время сообщения
                Text(timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                    .padding(.horizontal, isMine ? 20 : 16)
            }
            
            if !isMine { 
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: text)
    }
}

#Preview {
    VStack(spacing: 20) {
        ChatBubble(
            text: "Привет! Как дела?",
            isMine: false,
            timestamp: Date()
        )
        
        ChatBubble(
            text: "Привет! Все отлично, спасибо!",
            isMine: true,
            timestamp: Date()
        )
        
        ChatBubble(
            text: "Это очень длинное сообщение, которое должно переноситься на несколько строк для проверки корректного отображения текста в пузырьке чата.",
            isMine: false,
            timestamp: Date()
        )
    }
    .listRowInsets(EdgeInsets())
    .padding()
    .background(Color.background.ignoresSafeArea())
}

