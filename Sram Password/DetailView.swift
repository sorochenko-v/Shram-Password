//  DetailView.swift

import SwiftUI
import Security

struct DetailView: View {
    @Environment(VaultViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let entry: PasswordEntry?
    private var isNew: Bool { entry == nil }

    @State private var title: String
    @State private var username: String
    @State private var password: String
    @State private var website: String
    @State private var notes: String
    @State private var showPassword = false
    @State private var showDeleteAlert = false

    init(entry: PasswordEntry?) {
        self.entry = entry
        _title = State(initialValue: entry?.title ?? "")
        _username = State(initialValue: entry?.username ?? "")
        _password = State(initialValue: entry?.password ?? "")
        _website = State(initialValue: entry?.website ?? "")
        _notes = State(initialValue: entry?.notes ?? "")
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    field("TITLE") { TextField("e.g. Personal Email", text: $title) }
                    field("USERNAME") { TextField("e.g. user@example.com", text: $username) }
                    field("PASSWORD") {
                        HStack(spacing: 8) {
                            Group {
                                if showPassword {
                                    TextField("••••••••", text: $password)
                                } else {
                                    SecureField("••••••••", text: $password)
                                }
                            }
                            Button { showPassword.toggle() } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            Button { copy(password) } label: {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .disabled(password.isEmpty)
                        }
                    }
                    field("WEBSITE") { TextField("e.g. example.com", text: $website) }
                    field("NOTES") {
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .background(inputBackground)
                    }
                    Button {
                        password = generateRandomPassword()
                        showPassword = true
                    } label: {
                        HStack {
                            Image(systemName: "key")
                            Text("Generate Random Password")
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(surfaceColor)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor, lineWidth: 1))
                    }
                    VStack(spacing: 12) {
                        Button("Save") { save() }
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty)

                        if !isNew {
                            Button("Delete Entry") { showDeleteAlert = true }
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(surfaceColor)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.red, lineWidth: 1))
                        }
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle(isNew ? "New Password" : "Edit Password")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete this password?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { delete() }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
            content()
                .padding(10)
                .background(inputBackground)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(borderColor, lineWidth: 1))
        }
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.08) : Color(white: 0.95)
    }
    private var surfaceColor: Color {
        colorScheme == .dark ? Color(white: 0.15) : .white
    }
    private var inputBackground: Color {
        colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.93)
    }
    private var borderColor: Color {
        colorScheme == .dark ? Color(white: 0.3) : Color(white: 0.85)
    }

    private func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    private func generateRandomPassword(length: Int = 16) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-=[]{}|;:,.<>?"
        var bytes = [UInt8](repeating: 0, count: length)
        if SecRandomCopyBytes(kSecRandomDefault, length, &bytes) == errSecSuccess {
            return String(bytes.map { chars[chars.index(chars.startIndex, offsetBy: Int($0) % chars.count)] })
        } else {
            var rng = SystemRandomNumberGenerator()
            return String((0..<length).map { _ in chars.randomElement(using: &rng)! })
        }
    }

    private func save() {
        let newEntry = PasswordEntry(
            id: entry?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespaces),
            username: username,
            password: password,
            website: website,
            notes: notes,
            createdAt: entry?.createdAt ?? Date()
        )
        Task {
            if isNew {
                try? await viewModel.addEntry(newEntry)
            } else {
                try? await viewModel.updateEntry(newEntry)
            }
            dismiss()
        }
    }

    private func delete() {
        guard let entry else { return }
        Task {
            try? await viewModel.deleteEntry(entry)
            dismiss()
        }
    }
}
