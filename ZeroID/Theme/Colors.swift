import SwiftUI

// Расширение для удобного использования цветов
extension Color {
    // Цвета для текста
    static let textPrimary = Color.foreground
    static let textSecondary = Color.mutedForeground
    static let textMuted = Color.mutedForeground
    
    // Цвета для фонов
    static let surfacePrimary = Color.background
    static let surfaceSecondary = Color.card
    static let surfaceMuted = Color.muted
    
    // Переименованные цвета для избежания конфликтов
    static let primaryColor = Color("AppPrimaryColor")
    static let secondaryColor = Color("AppSecondaryColor")
    
    // Цвета для границ
    static let borderPrimary = Color.border
    static let borderSecondary = Color.muted
    
    // Цвета для состояний
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.destructive
    static let info = Color.accentColor
    
    // Градиент для кнопок и акцентов
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [Color.gradientStart, Color.gradientEnd],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // Градиент для фонового слоя чата (по умолчанию одинаковые цвета)
    static var chatBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color.chatBackgroundStart, Color.chatBackgroundEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

