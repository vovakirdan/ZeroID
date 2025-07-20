import SwiftUI

struct SettingsView: View {
    let onBack: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section("Общие") {
                    HStack {
                        Image(systemName: "paintbrush")
                            .foregroundColor(.blue)
                        Text("Тема")
                        Spacer()
                        Text("Системная")
                            .foregroundColor(Color.textSecondary)
                    }
                    
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.green)
                        Text("Язык")
                        Spacer()
                        Text("Русский")
                            .foregroundColor(Color.textSecondary)
                    }
                }
                
                Section("Соединение") {
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(.orange)
                        Text("STUN сервер")
                        Spacer()
                        Text("stun:stun.l.google.com:19302")
                            .foregroundColor(Color.textSecondary)
                            .font(.caption)
                    }
                    
                    HStack {
                        Image(systemName: "shield")
                            .foregroundColor(.purple)
                        Text("TURN сервер")
                        Spacer()
                        Text("Не настроен")
                            .foregroundColor(Color.textSecondary)
                    }
                }
                
                Section("О приложении") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.gray)
                        Text("Версия")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(Color.textSecondary)
                    }
                    
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.gray)
                        Text("Лицензия")
                        Spacer()
                        Text("MIT")
                            .foregroundColor(Color.textSecondary)
                    }
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Назад", action: onBack)
                }
            }
        }
    }
}

#Preview {
    SettingsView(onBack: {})
} 