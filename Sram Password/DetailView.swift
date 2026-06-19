//  DetailView.swift

import SwiftUI
import Security

// MARK: - Custom Masked TextField (avoids SecureField to bypass iOS password heuristics)

private struct MaskedTextField: UIViewRepresentable {
    @Binding var text: String
    var isMasked: Bool
    var placeholder: String
    var onCommit: (() -> Void)?

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.textContentType = .none
        field.isSecureTextEntry = false
        field.returnKeyType = .next
        field.keyboardType = .asciiCapable
        field.placeholder = placeholder
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if !context.coordinator.isEditing {
            uiView.text = isMasked ? String(repeating: "●", count: text.count) : text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isMasked: isMasked, onCommit: onCommit)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        var isMasked: Bool
        var onCommit: (() -> Void)?
        var isEditing = false

        init(text: Binding<String>, isMasked: Bool, onCommit: (() -> Void)?) {
            _text = text
            self.isMasked = isMasked
            self.onCommit = onCommit
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isEditing = true
            // When editing, show real text if password visible, else still masked
            textField.text = isMasked ? String(repeating: "●", count: text.count) : text
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isEditing = false
            textField.text = isMasked ? String(repeating: "●", count: text.count) : text
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onCommit?()
            textField.resignFirstResponder()
            return true
        }

        func textField(_ textField: UITextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
            // Calculate new real password
            let current = text as NSString
            let new = current.replacingCharacters(in: range, with: string)
            text = new

            // Update displayed text accordingly
            textField.text = isMasked ? String(repeating: "●", count: new.count) : new

            // Move cursor to end (since we manually set text, cursor resets)
            if let newPosition = textField.position(from: textField.beginningOfDocument,
                                                    offset: new.count) {
                textField.selectedTextRange = textField.textRange(from: newPosition, to: newPosition)
            }

            return false
        }
    }
}

// MARK: - DetailView

struct DetailView: View {
    @Environment(VaultViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let entry: PasswordEntry?
    private var isNew: Bool { entry == nil }

    @State private var title: String
    @State private var username: String
    @State private var password: String
    @State private var notes: String
    @State private var website: String
    @State private var type: EntryType
    @State private var selectedCategoryId: UUID?
    @State private var showPassword = false
    @State private var showDeleteAlert = false
    @State private var passwordLength: Double = 16
    @State private var showCreateCategory = false
    @State private var newCategoryName = ""
    @State private var newCategoryColorHex = "#FF9500"
    @State private var customColor = Color.orange
    @State private var showValidationErrors = false

    private let presetColors: [(String, Color)] = [
        ("#FF9500", .orange),
        ("#FF3B30", .red),
        ("#34C759", .green),
        ("#0A84FF", .blue),
        ("#AF52DE", .purple)
    ]

    init(entry: PasswordEntry?) {
        self.entry = entry
        _title = State(initialValue: entry?.title ?? "")
        _username = State(initialValue: entry?.username ?? "")
        _password = State(initialValue: entry?.password ?? "")
        _notes = State(initialValue: entry?.notes ?? "")
        _website = State(initialValue: entry?.website ?? "")
        _type = State(initialValue: entry?.type ?? .website)
        _selectedCategoryId = State(initialValue: entry?.categoryId)
    }

    var body: some View {
        ZStack {
            Color(white: 0.08).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Type", selection: $type) {
                        Text("Website").tag(EntryType.website)
                        Text("App").tag(EntryType.app)
                    }
                    .pickerStyle(.segmented)

                    requiredField("TITLE", text: $title)
                    requiredField("USERNAME OR EMAIL", text: $username)

                    requiredPasswordField("PASSWORD", text: $password)

                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(strengthColor)
                                .frame(width: geo.size.width * CGFloat(passwordStrength), height: 6)
                        }
                        .frame(height: 6)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 2))

                        Text("Strength: \(strengthLabel)")
                            .font(.caption)
                            .foregroundColor(strengthColor)
                    }

                    HStack {
                        Text("Length: \(Int(passwordLength))")
                            .font(.caption).fontWeight(.medium)
                            .foregroundColor(.gray)
                        Spacer()
                        Stepper("", value: $passwordLength, in: 8...32, step: 1)
                            .labelsHidden()
                    }

                    Button {
                        password = generatePassword(Int(passwordLength))
                        showPassword = true
                    } label: {
                        HStack {
                            Image(systemName: "key")
                            Text("Generate Random Password")
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.sramRed)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color(white: 0.15))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.sramRed, lineWidth: 1))
                    }

                    labeledField(type == .website ? "WEBSITE URL" : "APP NAME") {
                        TextField("", text: $website)
                            .textContentType(.none)
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("CATEGORY")
                            .font(.caption).fontWeight(.semibold).foregroundColor(.gray)
                        Menu {
                            Button("None") {
                                selectedCategoryId = nil
                            }
                            Divider()
                            ForEach(viewModel.categories) { category in
                                Button {
                                    selectedCategoryId = category.id
                                } label: {
                                    HStack {
                                        Circle()
                                            .fill(Color(hex: category.colorHex) ?? .gray)
                                            .frame(width: 12, height: 12)
                                        Text(category.name)
                                    }
                                }
                            }
                            Divider()
                            Button {
                                showCreateCategory = true
                            } label: {
                                Label("Create New Category", systemImage: "plus")
                            }
                        } label: {
                            HStack {
                                if let id = selectedCategoryId,
                                   let cat = viewModel.categories.first(where: { $0.id == id }) {
                                    Circle()
                                        .fill(Color(hex: cat.colorHex) ?? .gray)
                                        .frame(width: 12, height: 12)
                                    Text(cat.name)
                                        .foregroundColor(.white)
                                } else {
                                    Text("None")
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                            .padding(10)
                            .background(Color(white: 0.2))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(white: 0.3), lineWidth: 1))
                        }
                    }

                    if showCreateCategory {
                        VStack(spacing: 12) {
                            Text("NEW CATEGORY")
                                .font(.caption).fontWeight(.semibold).foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            TextField("", text: $newCategoryName)
                                .textContentType(.none)
                                .padding(10)
                                .background(Color(white: 0.2))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(white: 0.3), lineWidth: 1))
                                .foregroundColor(.white)

                            HStack {
                                ForEach(presetColors, id: \.0) { hex, color in
                                    Button {
                                        newCategoryColorHex = hex
                                        customColor = color
                                    } label: {
                                        Circle()
                                            .fill(color)
                                            .frame(width: 28, height: 28)
                                            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: newCategoryColorHex == hex ? 3 : 0))
                                    }
                                }
                                ColorPicker("", selection: $customColor, supportsOpacity: false)
                                    .labelsHidden()
                                    .frame(width: 28, height: 28)
                                    .onChange(of: customColor) { _, newColor in
                                        newCategoryColorHex = newColor.toHex()
                                    }
                            }

                            HStack {
                                Button("Cancel") {
                                    showCreateCategory = false
                                    newCategoryName = ""
                                }
                                .foregroundColor(.gray)
                                Spacer()
                                Button("Add") {
                                    let name = newCategoryName.trimmingCharacters(in: .whitespaces)
                                    guard !name.isEmpty else { return }
                                    let hex = newCategoryColorHex
                                    Task {
                                        try? await viewModel.addCategory(name: name, colorHex: hex)
                                        if let newCat = viewModel.categories.first(where: { $0.name == name && $0.colorHex == hex }) {
                                            selectedCategoryId = newCat.id
                                        }
                                        showCreateCategory = false
                                        newCategoryName = ""
                                    }
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(.sramRed)
                            }
                        }
                        .padding()
                        .background(Color(white: 0.12))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(white: 0.3), lineWidth: 1))
                    }

                    labeledField("NOTES") {
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .background(Color(white: 0.2))
                            .foregroundColor(.white)
                    }

                    VStack(spacing: 12) {
                        Button("Save") { handleSave() }
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isSaveDisabled ? Color(white: 0.3) : Color.sramRed)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        if !isNew {
                            Button("Delete Entry") { showDeleteAlert = true }
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(white: 0.15))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.red, lineWidth: 1))
                        }
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle(isNew ? "New Password" : "Edit Password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .alert("Delete this password?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { delete() }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespaces).isEmpty ||
        username.trimmingCharacters(in: .whitespaces).isEmpty ||
        password.isEmpty
    }

    private func handleSave() {
        if isSaveDisabled {
            showValidationErrors = true
        } else {
            save()
        }
    }

    // MARK: - Custom Fields

    private func requiredField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption).fontWeight(.semibold).foregroundColor(.gray)

            TextField("", text: text)
                .textContentType(.none)
                .foregroundColor(.white)
                .padding(10)
                .background(Color(white: 0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(showValidationErrors && text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.sramRed : Color(white: 0.3), lineWidth: 1)
                )

            if showValidationErrors && text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("Required field")
                    .font(.caption2)
                    .foregroundColor(.sramRed)
            }
        }
    }

    private func requiredPasswordField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption).fontWeight(.semibold).foregroundColor(.gray)

            HStack(spacing: 8) {
                MaskedTextField(text: text, isMasked: !showPassword, placeholder: "")
                    .frame(height: 20)
                    .padding(.vertical, 10)
                    .foregroundColor(.white)

                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)

                Button { copy(text.wrappedValue) } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.sramRed)
                }
                .buttonStyle(.plain)
                .disabled(text.wrappedValue.isEmpty)
            }
            .padding(.horizontal, 10)
            .background(Color(white: 0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(showValidationErrors && text.wrappedValue.isEmpty
                            ? Color.sramRed : Color(white: 0.3), lineWidth: 1)
            )

            if showValidationErrors && text.wrappedValue.isEmpty {
                Text("Required field")
                    .font(.caption2)
                    .foregroundColor(.sramRed)
            }
        }
    }

    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption).fontWeight(.semibold).foregroundColor(.gray)
            content()
                .padding(10)
                .background(Color(white: 0.2))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(white: 0.3), lineWidth: 1))
        }
    }

    private func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    private var passwordStrength: Double {
        let len = password.count
        guard len > 0 else { return 0 }
        var score = 0
        let sets: [(CharacterSet, Int)] = [
            (.uppercaseLetters, 1),
            (.lowercaseLetters, 1),
            (.decimalDigits, 1),
            (.punctuationCharacters.union(.symbols), 1)
        ]
        for (set, pts) in sets {
            if password.unicodeScalars.contains(where: set.contains) { score += pts }
        }
        if len >= 12 { score += 1 }
        if len >= 16 { score += 1 }
        if len >= 20 { score += 1 }
        return min(Double(score) / 7.0, 1.0)
    }

    private var strengthColor: Color {
        switch passwordStrength {
        case 0..<0.4: return .red
        case 0.4..<0.7: return .yellow
        default: return .green
        }
    }

    private var strengthLabel: String {
        switch passwordStrength {
        case 0..<0.4: return "Weak"
        case 0.4..<0.7: return "Medium"
        default: return "Strong"
        }
    }

    private func generatePassword(_ length: Int) -> String {
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
            notes: notes,
            website: website,
            type: type,
            categoryId: selectedCategoryId,
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
