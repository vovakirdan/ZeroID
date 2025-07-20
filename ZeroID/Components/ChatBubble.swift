import SwiftUI

struct ChatBubble: View {
    let text: String
    let isMine: Bool
    let timestamp: Date
    
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
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(isMine ? 
                                    AnyShapeStyle(Color.primaryGradient) : 
                                    AnyShapeStyle(Color(red: 0.15, green: 0.15, blue: 0.15, opacity: 0.85))
                                )
                        )
                        .foregroundColor(isMine ? .white : Color(red: 0.9, green: 0.9, blue: 0.9))
                        .overlay(alignment: isMine ? .bottomTrailing : .bottomLeading) {
                            // Apple-style хвостик пузырька
                            if isMine {
                                // Хвостик справа для моих сообщений
                                Image(systemName: "arrowtriangle.down.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.primaryGradient)
                                    .rotationEffect(.degrees(45))
                                    .offset(x: 8, y: 8)
                            } else {
                                // Хвостик слева для чужих сообщений
                                Image(systemName: "arrowtriangle.down.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15, opacity: 0.85))
                                    .rotationEffect(.degrees(-45))
                                    .offset(x: -8, y: 8)
                            }
                        }
                    
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

