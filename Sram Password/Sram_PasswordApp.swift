import SwiftUI

@main
struct Sram_PasswordApp: App {
    @AppStorage("selectedTheme") private var selectedTheme: AppTheme = .system
    @State private var viewModel = VaultViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if viewModel.isUnlocked {
                    MainListView()
                } else {
                    LoginView()
                }
            }
            .environment(viewModel)
            .preferredColorScheme(colorScheme)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        #endif
    }

    private var colorScheme: ColorScheme? {
        switch selectedTheme {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
