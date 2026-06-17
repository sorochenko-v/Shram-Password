//  MainListView.swift

import SwiftUI

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
                Color(white: 0.08).ignoresSafeArea()
                if viewModel.entries.isEmpty {
                    ContentUnavailableView("No Passwords", systemImage: "lock.shield",
                                           description: Text("Tap + to add your first password."))
                    .foregroundColor(.gray)
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
                                    PasswordRowView(entry: entry) {
                                        copyToClipboard(entry.password)
                                    }
                                }
                                .listRowBackground(Color(white: 0.12))
                                .listRowSeparatorTint(Color(white: 0.3))
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
            .navigationTitle("Sram")
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
            .toolbarBackground(Color(white: 0.05), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var filteredEntries: [PasswordEntry] {
        var result = viewModel.entries
        if let type = selectedType {
            result = result.filter { $0.type == type }
        }
        if !searchText.isEmpty {
            let q = searchText.localizedLowercase
            result = result.filter {
                $0.title.localizedLowercase.contains(q) ||
                $0.username.localizedLowercase.contains(q)
            }
        }
        return result
    }

    private func delete(at offsets: IndexSet) {
        let targets = offsets.map { filteredEntries[$0] }
        for entry in targets {
            Task { try? await viewModel.deleteEntry(entry) }
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

// MARK: - Categories Tab

private struct CategoriesTabView: View {
    @Environment(VaultViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.08).ignoresSafeArea()
                if viewModel.categories.isEmpty {
                    ContentUnavailableView("No Categories", systemImage: "folder",
                                           description: Text("Add categories in the Vault."))
                    .foregroundColor(.gray)
                } else {
                    List {
                        ForEach(viewModel.categories) { category in
                            NavigationLink(destination: CategoryEntriesView(category: category)) {
                                HStack {
                                    Image(systemName: "circle.fill")
                                        .foregroundColor(Color(hex: category.colorHex) ?? .gray)
                                        .font(.caption)
                                    Text(category.name)
                                        .foregroundColor(.white)
                                }
                            }
                            .listRowBackground(Color(white: 0.12))
                            .listRowSeparatorTint(Color(white: 0.3))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Categories")
        }
    }
}

private struct CategoryEntriesView: View {
    @Environment(VaultViewModel.self) private var viewModel
    let category: Category

    private var filteredEntries: [PasswordEntry] {
        viewModel.entries.filter { $0.categoryId == category.id }
    }

    var body: some View {
        ZStack {
            Color(white: 0.08).ignoresSafeArea()
            if filteredEntries.isEmpty {
                ContentUnavailableView("No passwords", systemImage: "lock.shield",
                                       description: Text("No entries in \(category.name)."))
                .foregroundColor(.gray)
            } else {
                List {
                    ForEach(filteredEntries) { entry in
                        NavigationLink(destination: DetailView(entry: entry)) {
                            PasswordRowView(entry: entry) {
                                #if os(iOS)
                                UIPasteboard.general.string = entry.password
                                #elseif os(macOS)
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(entry.password, forType: .string)
                                #endif
                            }
                        }
                        .listRowBackground(Color(white: 0.12))
                        .listRowSeparatorTint(Color(white: 0.3))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(category.name)
    }
}

// MARK: - Settings Tab

private struct SettingsTabView: View {
    @Environment(VaultViewModel.self) private var viewModel
    @State private var showDeleteAlert = false
    @State private var showSupportSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.08).ignoresSafeArea()
                List {
                    Button {
                        showSupportSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.sramRed)
                            Text("Support Authors")
                                .foregroundColor(.white)
                        }
                    }
                    .listRowBackground(Color(white: 0.12))

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.sramRed)
                            Text("Delete Profile")
                                .foregroundColor(.sramRed)
                        }
                    }
                    .listRowBackground(Color(white: 0.12))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showSupportSheet) {
                SupportAuthorsView()
            }
            .alert("Delete Profile?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await viewModel.wipeAllDataAndReset() }
                }
            } message: {
                Text("Are you sure you want to permanently delete this profile and wipe all credentials from this device?")
            }
        }
    }
}

private struct SupportAuthorsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(white: 0.08).ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.sramRed)
                Text("Thank You!")
                    .font(.title).fontWeight(.bold).foregroundColor(.white)
                Text("Your support keeps Sram independent and secure.")
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                Button("Close") { dismiss() }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.sramRed)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(32)
        }
    }
}

// MARK: - Shared Row

private struct PasswordRowView: View {
    let entry: PasswordEntry
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text(entry.username)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            Button { onCopy() } label: {
                Image(systemName: "doc.on.doc")
                    .fontWeight(.medium)
                    .foregroundColor(.sramRed)
                    .padding(8)
                    .background(Color.sramRed.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.sramRed, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Color hex helper

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
