import SwiftUI
import UniformTypeIdentifiers

struct MainListView: View {
    @Environment(VaultViewModel.self) private var viewModel

    var body: some View {
        TabView {
            VaultTabView()
                .tabItem { Label("Vault", systemImage: "lock.square.stack.fill") }
            CategoriesTabView()
                .tabItem { Label("Categories", systemImage: "folder.fill") }
            SettingsTabView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.sramRed)
        .sheet(isPresented: Binding(get: { viewModel.showSupportPopup },
                                   set: { viewModel.showSupportPopup = $0 })) {
            SupportPopupView()
        }
    }
}

// MARK: - Vault Tab
private struct VaultTabView: View {
    @Environment(VaultViewModel.self) private var viewModel
    @State private var searchText = ""
    @State private var selectedType: EntryType? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sramBackground.ignoresSafeArea()
                if viewModel.entries.isEmpty {
                    ContentUnavailableView("No Passwords", systemImage: "lock.shield",
                                           description: Text("Tap + to add your first password."))
                    .foregroundColor(.sramTextSecondary)
                } else {
                    VStack(spacing: 0) {
                        Picker("Type", selection: $selectedType) {
                            Text("All").tag(EntryType?.none)
                            Text("Websites").tag(EntryType?.some(.website))
                            Text("Apps").tag(EntryType?.some(.app))
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.bottom, 8)

                        List {
                            ForEach(filteredEntries) { entry in
                                NavigationLink(destination: DetailView(entry: entry)) {
                                    PasswordRowView(entry: entry) { copyToClipboard(entry.password) }
                                }
                                .listRowBackground(Color.sramRowBackground)
                                .listRowSeparatorTint(Color.sramBorder)
                            }
                            .onDelete(perform: delete)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                                    prompt: "Search by title or username")
                    }
                }
            }
            .navigationTitle("Passwords")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { viewModel.lock() } label: {
                        Image(systemName: "lock").fontWeight(.semibold)
                    }
                    .foregroundColor(.sramRed)
                    NavigationLink(destination: DetailView(entry: nil)) {
                        Image(systemName: "plus").fontWeight(.semibold)
                    }
                    .foregroundColor(.sramRed)
                }
            }
            .toolbarBackground(Color.sramSurface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var filteredEntries: [PasswordEntry] {
        var result = viewModel.entries
        if let type = selectedType { result = result.filter { $0.type == type } }
        if !searchText.isEmpty {
            let q = searchText.localizedLowercase
            result = result.filter { $0.title.localizedLowercase.contains(q) || $0.username.localizedLowercase.contains(q) }
        }
        return result
    }

    private func delete(at offsets: IndexSet) {
        let targets = offsets.map { filteredEntries[$0] }
        for entry in targets { Task { try? await viewModel.deleteEntry(entry) } }
    }

    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

// MARK: - Categories Tab
private struct CategoriesTabView: View {
    @Environment(VaultViewModel.self) private var viewModel
    @State private var showAddCategory = false
    @State private var categoryToEdit: Category? = nil
    @State private var categoryToDelete: Category? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sramBackground.ignoresSafeArea()
                if viewModel.categories.isEmpty {
                    ContentUnavailableView("No Categories", systemImage: "folder",
                                           description: Text("Add categories to organize your passwords."))
                    .foregroundColor(.sramTextSecondary)
                } else {
                    List {
                        ForEach(viewModel.categories) { category in
                            NavigationLink(destination: CategoryDetailView(category: category)) {
                                HStack {
                                    Image(systemName: "circle.fill")
                                        .foregroundColor(Color(hex: category.colorHex) ?? .gray)
                                        .font(.caption)
                                    Text(category.name)
                                        .foregroundColor(.primary)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { categoryToDelete = category } label: { Label("Delete", systemImage: "trash") }
                                Button { categoryToEdit = category } label: { Label("Edit", systemImage: "pencil") }
                                    .tint(.sramRed)
                            }
                        }
                        .listRowBackground(Color.sramRowBackground)
                        .listRowSeparatorTint(Color.sramBorder)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddCategory = true } label: { Image(systemName: "plus").fontWeight(.semibold) }
                        .foregroundColor(.sramRed)
                }
            }
            .sheet(isPresented: $showAddCategory) {
                CategoryEditView(category: nil) { name, colorHex in try? await viewModel.addCategory(name: name, colorHex: colorHex) }
            }
            .sheet(item: $categoryToEdit) { cat in
                CategoryEditView(category: cat) { name, colorHex in try? await viewModel.updateCategory(cat, newName: name, newColorHex: colorHex) }
            }
            .alert("Delete Category?", isPresented: Binding(get: { categoryToDelete != nil }, set: { if !$0 { categoryToDelete = nil } })) {
                Button("Cancel", role: .cancel) { categoryToDelete = nil }
                Button("Delete", role: .destructive) {
                    guard let cat = categoryToDelete else { return }
                    Task { try? await viewModel.deleteCategory(cat) }; categoryToDelete = nil
                }
            } message: { Text("This will unlink all associated passwords but will not delete them.") }
        }
    }
}

// MARK: - Category Detail View
private struct CategoryDetailView: View {
    @Environment(VaultViewModel.self) private var viewModel
    let category: Category
    @State private var searchText = ""
    @State private var showEditSheet = false

    private var filteredEntries: [PasswordEntry] { viewModel.entries.filter { $0.categoryId == category.id } }

    var body: some View {
        ZStack {
            Color.sramBackground.ignoresSafeArea()
            if filteredEntries.isEmpty {
                ContentUnavailableView("No Passwords", systemImage: "lock.shield",
                                       description: Text("No passwords in \(category.name)."))
                .foregroundColor(.sramTextSecondary)
            } else {
                List {
                    ForEach(filteredEntries) { entry in
                        NavigationLink(destination: DetailView(entry: entry)) {
                            PasswordRowView(entry: entry) { copyToClipboard(entry.password) }
                        }
                        .listRowBackground(Color.sramRowBackground)
                        .listRowSeparatorTint(Color.sramBorder)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "Search in \(category.name)")
            }
        }
        .navigationTitle(category.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showEditSheet = true } label: { Image(systemName: "pencil").fontWeight(.semibold) }
                    .foregroundColor(.sramRed)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            CategoryEditView(category: category) { name, colorHex in try? await viewModel.updateCategory(category, newName: name, newColorHex: colorHex) }
        }
    }

    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

// MARK: - Category Edit View
private struct CategoryEditView: View {
    let category: Category?
    let onSave: (String, String) async throws -> Void
    @State private var name: String
    @State private var colorHex: String
    @State private var customColor = Color.orange
    @Environment(\.dismiss) private var dismiss

    private let presetColors: [(String, Color)] = [
        ("#FF9500", .orange), ("#FF3B30", .red), ("#34C759", .green),
        ("#0A84FF", .blue), ("#AF52DE", .purple)
    ]

    init(category: Category?, onSave: @escaping (String, String) async throws -> Void) {
        self.category = category
        self.onSave = onSave
        _name = State(initialValue: category?.name ?? "")
        _colorHex = State(initialValue: category?.colorHex ?? "#FF9500")
    }

    var body: some View {
        ZStack {
            Color.sramBackground.ignoresSafeArea()
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CATEGORY NAME").font(.caption).fontWeight(.semibold).foregroundColor(.sramTextSecondary)
                    TextField("", text: $name)
                        .padding(10)
                        .background(Color.sramFieldBackground)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.sramBorder, lineWidth: 1))
                        .foregroundColor(.primary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("COLOR").font(.caption).fontWeight(.semibold).foregroundColor(.sramTextSecondary)
                    HStack {
                        ForEach(presetColors, id: \.0) { hex, color in
                            Button {
                                colorHex = hex; customColor = color
                            } label: {
                                Circle().fill(color).frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: colorHex == hex ? 3 : 0))
                            }
                        }
                        ColorPicker("", selection: $customColor, supportsOpacity: false)
                            .labelsHidden().frame(width: 28, height: 28)
                            .onChange(of: customColor) { _, newColor in colorHex = newColor.toHex() }
                    }
                }
                Button("Save") {
                    Task { try await onSave(name.trimmingCharacters(in: .whitespaces), colorHex); dismiss() }
                }
                .fontWeight(.semibold).foregroundColor(.white).padding()
                .frame(maxWidth: .infinity).background(Color.sramRed)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel") { dismiss() }.foregroundColor(.sramTextSecondary)
            }
            .padding(32)
        }
    }
}

// MARK: - Settings Tab
private struct SettingsTabView: View {
    @Environment(VaultViewModel.self) private var viewModel
    @Environment(\.openURL) private var openURL
    @AppStorage("selectedTheme") private var selectedTheme: AppTheme = .system

    @State private var showDeleteAlert = false
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportDocument: SramEncryptedDocument? = nil
    @State private var importSuccessAlert = false
    @State private var importErrorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.sramBackground.ignoresSafeArea()
                List {
                    Section(header: Text("APPEARANCE").foregroundColor(.sramTextSecondary)) {
                        Picker("Theme", selection: $selectedTheme) {
                            ForEach(AppTheme.allCases) { theme in Text(theme.rawValue).tag(theme) }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.sramSurface)
                    }
                    Section(header: Text("SUPPORT").foregroundColor(.sramTextSecondary)) {
                        Button {} label: {
                            HStack { Image(systemName: "heart.fill").foregroundColor(.sramRed); Text("Support on Ghost").foregroundColor(.primary) }
                        }
                        .listRowBackground(Color.sramSurface)
                        Button { openURL(URL(string: "https://www.buymeacoffee.com/sram")!) } label: {
                            HStack { Image(systemName: "gift.fill").foregroundColor(.sramRed); Text("Support via Buy Me a Coffee").foregroundColor(.primary) }
                        }
                        .listRowBackground(Color.sramSurface)
                    }
                    Section(header: Text("BACKUP & RESTORE").foregroundColor(.sramTextSecondary)) {
                        Button {
                            if let data = viewModel.exportVaultData() { exportDocument = SramEncryptedDocument(data: data); showExporter = true }
                        } label: {
                            HStack { Image(systemName: "square.and.arrow.up").foregroundColor(.sramRed); Text("Export Encrypted Backup").foregroundColor(.primary) }
                        }
                        .listRowBackground(Color.sramSurface)
                        Button { showImporter = true } label: {
                            HStack { Image(systemName: "square.and.arrow.down").foregroundColor(.sramRed); Text("Import Encrypted Backup").foregroundColor(.primary) }
                        }
                        .listRowBackground(Color.sramSurface)
                    }
                    Section(header: Text("DATA MANAGEMENT").foregroundColor(.sramTextSecondary)) {
                        Button(role: .destructive) { showDeleteAlert = true } label: {
                            HStack { Image(systemName: "trash").foregroundColor(.sramRed); Text("Delete Profile").foregroundColor(.sramRed) }
                        }
                        .listRowBackground(Color.sramSurface)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
        }
        .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: .data, defaultFilename: "sram_backup.enc") { _ in }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.data, UTType(filenameExtension: "enc") ?? .data]) { result in
            switch result {
            case .success(let url):
                Task { do { try await viewModel.importVaultData(from: url); importSuccessAlert = true } catch { importErrorMessage = error.localizedDescription; importSuccessAlert = true } }
            case .failure(let error):
                importErrorMessage = error.localizedDescription; importSuccessAlert = true
            }
        }
        .alert("Import Status", isPresented: $importSuccessAlert) {
            Button("OK", role: .cancel) { importErrorMessage = nil }
        } message: {
            if let msg = importErrorMessage { Text("Import failed: \(msg)") }
            else { Text("Backup imported successfully.") }
        }
        .alert("Delete Profile?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await viewModel.wipeAllDataAndReset() } }
        } message: { Text("This will permanently delete all your stored passwords.") }
    }
}

// MARK: - FileDocument
struct SramEncryptedDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        if let d = configuration.file.regularFileContents { data = d } else { data = Data() }
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Support Popup
private struct SupportPopupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    var body: some View {
        ZStack {
            Color.sramBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "heart.circle.fill").font(.system(size: 60)).foregroundColor(.sramRed)
                Text("Sram Password is 100% free and local-only.\nIf you wish to support the development, consider supporting the authors on Ghost or Buy Me a Coffee.")
                    .foregroundColor(.primary).multilineTextAlignment(.center)
                Button { dismiss() } label: {
                    Label("Support on Ghost", systemImage: "heart").fontWeight(.semibold).foregroundColor(.white)
                        .padding().frame(maxWidth: .infinity).background(Color.sramRed).clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Button { openURL(URL(string: "https://www.buymeacoffee.com/sram")!) } label: {
                    Label("Buy Me a Coffee", systemImage: "gift").fontWeight(.semibold).foregroundColor(.white)
                        .padding().frame(maxWidth: .infinity).background(Color.sramRed).clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Button("Close") { dismiss() }.foregroundColor(.sramTextSecondary)
            }.padding(32)
        }
    }
}

// MARK: - Shared Row
private struct PasswordRowView: View {
    let entry: PasswordEntry; let onCopy: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title).font(.headline).fontWeight(.semibold).foregroundColor(.primary)
                Text(entry.username).font(.subheadline).foregroundColor(.sramTextSecondary)
            }
            Spacer()
            Button { onCopy() } label: {
                Image(systemName: "doc.on.doc").fontWeight(.medium).foregroundColor(.sramRed)
                    .padding(8).background(Color.sramRed.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.sramRed, lineWidth: 1))
            }.buttonStyle(.plain)
        }.padding(.vertical, 4)
    }
}

// MARK: - Color helpers (existing)
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0; Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: return nil
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
    func toHex() -> String {
        #if canImport(UIKit)
        let uic = UIColor(self)
        #elseif canImport(AppKit)
        let uic = NSColor(self)
        #endif
        guard let comps = uic.cgColor.components else { return "#FF0000" }
        return String(format: "#%02X%02X%02X", Int(comps[0]*255), Int(comps[1]*255), Int(comps[2]*255))
    }
}
