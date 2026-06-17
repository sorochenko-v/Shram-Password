//  MainListView.swift

import SwiftUI

struct MainListView: View {
    @Environment(VaultViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()
                if viewModel.entries.isEmpty {
                    ContentUnavailableView("No Passwords", systemImage: "lock.shield",
                                           description: Text("Tap + to add your first password."))
                } else {
                    List {
                        ForEach(filteredEntries) { entry in
                            NavigationLink(destination: DetailView(entry: entry)) {
                                PasswordRowView(entry: entry) {
                                    copyToClipboard(entry.password)
                                }
                            }
                            .listRowBackground(rowBackground)
                            .listRowSeparatorTint(borderColor)
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(backgroundColor)
                    .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                                prompt: "Search by title or username")
                }
            }
            .navigationTitle("Sram")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { viewModel.lock() } label: {
                        Image(systemName: "lock").fontWeight(.semibold)
                    }
                    NavigationLink(destination: DetailView(entry: nil)) {
                        Image(systemName: "plus").fontWeight(.semibold)
                    }
                }
            }
            .toolbarBackground(Color.accentColor.opacity(0.05), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var filteredEntries: [PasswordEntry] {
        guard !searchText.isEmpty else { return viewModel.entries }
        let q = searchText.localizedLowercase
        return viewModel.entries.filter {
            $0.title.localizedLowercase.contains(q) ||
            $0.username.localizedLowercase.contains(q)
        }
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

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.08) : Color(white: 0.95)
    }
    private var rowBackground: Color {
        colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.98)
    }
    private var borderColor: Color {
        colorScheme == .dark ? Color(white: 0.3) : Color(white: 0.85)
    }
}

private struct PasswordRowView: View {
    let entry: PasswordEntry
    let onCopy: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title).font(.headline).fontWeight(.semibold).foregroundColor(.primary)
                Text(entry.username).font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            Button { onCopy() } label: {
                Image(systemName: "doc.on.doc")
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
                    .padding(8)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
