import SwiftUI

struct SettingsView: View {
    let onBack: () -> Void
    @State private var stunUrl: String = UserDefaults.standard.string(forKey: "stun_url") ?? "stun:stun.l.google.com:19302"
    @State private var turnUrl: String = UserDefaults.standard.string(forKey: "turn_url") ?? ""
    @State private var turnUsername: String = UserDefaults.standard.string(forKey: "turn_user") ?? ""
    @State private var turnCredential: String = UserDefaults.standard.string(forKey: "turn_cred") ?? ""

    var body: some View {
        VStack(spacing: 0) {
            // Apple-style заголовок с кнопкой назад
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.backward")
                        .font(.title2)
                        .foregroundColor(Color.accentColor)
                }
                .padding(.leading, 4)
                
                Spacer()
                
                Text("Настройки")
                    .font(.headline)
                    .foregroundColor(Color.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "network")
                                .foregroundColor(.orange)
                            Text("STUN URL")
                            Spacer()
                        }
                        TextField("stun:host:port", text: $stunUrl)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "shield")
                                .foregroundColor(.purple)
                            Text("TURN URL")
                            Spacer()
                        }
                        TextField("turn:host:port", text: $turnUrl)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)

                        TextField("TURN username", text: $turnUsername)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        SecureField("TURN credential", text: $turnCredential)
                    }

                    Button("Сохранить и применить") {
                        // Сохраняем значения в UserDefaults
                        UserDefaults.standard.set(stunUrl, forKey: "stun_url")
                        UserDefaults.standard.set(turnUrl, forKey: "turn_url")
                        UserDefaults.standard.set(turnUsername, forKey: "turn_user")
                        UserDefaults.standard.set(turnCredential, forKey: "turn_cred")

                        // Конвертируем в структуру WebRTCManager.UserIceServer и сохраняем
                        var servers: [WebRTCManager.UserIceServer] = []
                        if !stunUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            servers.append(.init(urls: [stunUrl], username: nil, credential: nil))
                        }
                        if !turnUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            servers.append(.init(urls: [turnUrl], username: turnUsername.isEmpty ? nil : turnUsername, credential: turnCredential.isEmpty ? nil : turnCredential))
                        }
                        let mgr = WebRTCManager()
                        mgr.saveIceServers(servers)
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
            .listStyle(.insetGrouped)
        }
        .background(Color.background)
        .navigationBarHidden(true)
    }
}

#Preview {
    SettingsView(onBack: {})
} 