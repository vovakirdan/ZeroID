import SwiftUI

struct ChatBubble: View {
    let text: String
    let isMine: Bool
    let timestamp: Date
    
    var body: some View {
        HStack {
            if isMine { Spacer() }
            
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                Text(text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isMine ? Color.accentColor : Color(.systemGray5))
                    )
                    .foregroundColor(isMine ? .white : .primary)
                    .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 1)
                
                Text(timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if !isMine { Spacer() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
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

