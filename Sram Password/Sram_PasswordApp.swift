//  Sram_PasswordApp.swift

import SwiftUI

@main
struct Sram_PasswordApp: App {
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
            .preferredColorScheme(.dark)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        #endif
    }
}
