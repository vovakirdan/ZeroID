import SwiftUI
import UIKit

struct SettingsView: View {
    let onBack: () -> Void
    // Списки серверов
    @State private var stunServers: [String] = []
    struct TurnServerItem: Identifiable, Hashable {
        let id = UUID()
        var url: String
        var username: String
        var credential: String
    }
    @State private var turnServers: [TurnServerItem] = []

    // UI состояния
    @State private var isLoaded = false
    @State private var isValidating = false
    @State private var validationResults: [WebRTCManager.IceServerValidationResult] = []
    @State private var showToast = false
    @State private var toastMessage = ""
    // Лимит медиа (в МБ)
    @State private var maxMediaMB: Int = 16

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
                
                Section("Сервера STUN") {
                    if stunServers.isEmpty {
                        Text("Добавь хотя бы один STUN сервер для NAT-traversal")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                    }
                    ForEach(stunServers.indices, id: \.self) { idx in
                        HStack(spacing: 8) {
                            Image(systemName: "network")
                                .foregroundColor(.orange)
                            TextField("stun:host:port", text: Binding(
                                get: { stunServers[idx] },
                                set: { stunServers[idx] = $0 }
                            ))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            Button(role: .destructive) {
                                stunServers.remove(at: idx)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    Button {
                        stunServers.append("")
                    } label: {
                        Label("Добавить STUN", systemImage: "plus.circle")
                    }
                }

                Section("Сервера TURN") {
                    if turnServers.isEmpty {
                        Text("Добавь TURN для relay в сложных сетях")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                    }
                    ForEach(turnServers) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "shield")
                                    .foregroundColor(.purple)
                                TextField("turn:host:port", text: Binding(
                                    get: { item.url },
                                    set: { newValue in
                                        if let idx = turnServers.firstIndex(of: item) {
                                            turnServers[idx].url = newValue
                                        }
                                    }
                                ))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                Button(role: .destructive) {
                                    if let idx = turnServers.firstIndex(of: item) {
                                        turnServers.remove(at: idx)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                            TextField("TURN username", text: Binding(
                                get: { item.username },
                                set: { newValue in
                                    if let idx = turnServers.firstIndex(of: item) {
                                        turnServers[idx].username = newValue
                                    }
                                }
                            ))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            SecureField("TURN credential", text: Binding(
                                get: { item.credential },
                                set: { newValue in
                                    if let idx = turnServers.firstIndex(of: item) {
                                        turnServers[idx].credential = newValue
                                    }
                                }
                            ))
                        }
                    }
                    Button {
                        turnServers.append(TurnServerItem(url: "", username: "", credential: ""))
                    } label: {
                        Label("Добавить TURN", systemImage: "plus.circle")
                    }
                }

                Section("Медиа") {
                    HStack {
                        Image(systemName: "paperclip")
                            .foregroundColor(.cyan)
                        Stepper(value: $maxMediaMB, in: 1...1024) {
                            Text("Макс. размер отправляемых файлов: \(maxMediaMB) МБ")
                        }
                    }
                    Text("Файлы шифруются end‑to‑end. Метаданные (например, EXIF) могут быть открытыми.")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }

                Section {
                    if isValidating {
                        HStack {
                            ProgressView()
                            Text("Проверяем сервера...")
                                .foregroundColor(Color.textSecondary)
                        }
                    } else if !validationResults.isEmpty {
                        ForEach(validationResults, id: \.url) { r in
                            HStack {
                                Image(systemName: r.reachable ? "checkmark.circle" : "xmark.octagon")
                                    .foregroundColor(r.reachable ? .green : .red)
                                Text("\(r.isTurn ? "TURN" : "STUN"): \(r.url)")
                                Spacer()
                                if let reason = r.reason, !r.reachable {
                                    Text(reason).foregroundColor(.red)
                                }
                            }
                        }
                    }

                    Button {
                        validateServers()
                    } label: {
                        Label("Проверить сервера", systemImage: "checkmark.shield")
                    }

                    Button("Сохранить и применить") {
                        saveAndApply()
                    }
                    .disabled(isValidating)
                } header: {
                    Text("Валидация и применение")
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
        .toast(isVisible: $showToast, message: toastMessage)
        .onAppear(perform: lazyLoad)
    }

    // MARK: - Private
    private func lazyLoad() {
        guard !isLoaded else { return }
        isLoaded = true
        // Загружаем из новых настроек, иначе бэкап — из старых полей
        let mgr = WebRTCManager()
        let servers = mgr.loadUserIceServers()
        if servers.isEmpty {
            // Легаси поля
            let stun = UserDefaults.standard.string(forKey: "stun_url") ?? "stun:stun.l.google.com:19302"
            let turn = UserDefaults.standard.string(forKey: "turn_url") ?? ""
            let turnUser = UserDefaults.standard.string(forKey: "turn_user") ?? ""
            let turnCred = UserDefaults.standard.string(forKey: "turn_cred") ?? ""
            if !stun.isEmpty { stunServers = [stun] }
            if !turn.isEmpty { turnServers = [TurnServerItem(url: turn, username: turnUser, credential: turnCred)] }
        } else {
            var stuns: [String] = []
            var turns: [TurnServerItem] = []
            for s in servers {
                for u in s.urls {
                    if u.lowercased().hasPrefix("stun:") || u.lowercased().hasPrefix("stuns:") {
                        stuns.append(u)
                    } else if u.lowercased().hasPrefix("turn:") || u.lowercased().hasPrefix("turns:") {
                        turns.append(TurnServerItem(url: u, username: s.username ?? "", credential: s.credential ?? ""))
                    }
                }
            }
            stunServers = stuns
            turnServers = turns
        }
        // Лимит медиа
        let mb = UserDefaults.standard.integer(forKey: "max_media_mb")
        if mb > 0 { maxMediaMB = min(max(1, mb), 1024) }
    }

    private func validateServers() {
        // Скрываем клавиатуру
        dismissKeyboard()

        validationResults = []
        isValidating = true
        let mgr = WebRTCManager()
        var list: [WebRTCManager.UserIceServer] = []
        for s in stunServers.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ !$0.isEmpty }) {
            list.append(.init(urls: [s], username: nil, credential: nil))
        }
        for t in turnServers {
            let url = t.url.trimmingCharacters(in: .whitespacesAndNewlines)
            if !url.isEmpty {
                list.append(.init(urls: [url], username: t.username.isEmpty ? nil : t.username, credential: t.credential.isEmpty ? nil : t.credential))
            }
        }
        mgr.validateIceServers(list) { results in
            self.validationResults = results
            self.isValidating = false
            if results.isEmpty {
                self.toast("Нет серверов для проверки")
            } else if results.allSatisfy({ $0.reachable }) {
                self.toast("Все сервера доступны")
            } else {
                self.toast("Некоторые сервера недоступны")
            }
        }
    }

    private func saveAndApply() {
        // Скрываем клавиатуру
        dismissKeyboard()

        // Если есть результаты валидации и среди них есть недоступные — блокируем
        if !validationResults.isEmpty && validationResults.contains(where: { !$0.reachable }) {
            toast("Есть недоступные сервера — исправь и повтори")
            return
        }

        // Если валидации ещё не было — запустим её синхронно и по результату либо сохраним, либо откажем
        if validationResults.isEmpty {
            isValidating = true
            let mgr = WebRTCManager()
            var listForCheck: [WebRTCManager.UserIceServer] = []
            for s in stunServers.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ !$0.isEmpty }) {
                listForCheck.append(.init(urls: [s], username: nil, credential: nil))
            }
            for t in turnServers {
                let url = t.url.trimmingCharacters(in: .whitespacesAndNewlines)
                if !url.isEmpty {
                    listForCheck.append(.init(urls: [url], username: t.username.isEmpty ? nil : t.username, credential: t.credential.isEmpty ? nil : t.credential))
                }
            }
            mgr.validateIceServers(listForCheck) { results in
                self.isValidating = false
                self.validationResults = results
                guard !results.isEmpty, results.allSatisfy({ $0.reachable }) else {
                    self.toast("Есть недоступные сервера — исправь и повтори")
                    return
                }
                self.persistServers()
            }
            return
        }

        // Иначе валидируемые успешно — сохраняем
        guard validationResults.allSatisfy({ $0.reachable }) else {
            toast("Есть недоступные сервера — исправь и повтори")
            return
        }
        persistServers()
    }

    private func persistServers() {
        let mgr = WebRTCManager()
        var list: [WebRTCManager.UserIceServer] = []
        for s in stunServers.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ !$0.isEmpty }) {
            list.append(.init(urls: [s], username: nil, credential: nil))
        }
        for t in turnServers {
            let url = t.url.trimmingCharacters(in: .whitespacesAndNewlines)
            if !url.isEmpty {
                list.append(.init(urls: [url], username: t.username.isEmpty ? nil : t.username, credential: t.credential.isEmpty ? nil : t.credential))
            }
        }
        if list.isEmpty {
            // Если пользователь всё очистил — вернёмся к дефолтам, удалив ключ
            UserDefaults.standard.removeObject(forKey: "user_ice_servers")
            toast("Применены значения по умолчанию")
        } else {
            mgr.saveIceServers(list)
            toast("Сохранено и применено")
        }
        // Сохраняем лимит медиа (в МБ)
        UserDefaults.standard.set(maxMediaMB, forKey: "max_media_mb")
    }

    private func toast(_ message: String) {
        toastMessage = message
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.2)) {
                showToast = false
            }
        }
    }

    private func dismissKeyboard() {
        // Принудительно скрываем клавиатуру
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    SettingsView(onBack: {})
} 