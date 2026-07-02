import SwiftUI
import LocalAuthentication

// MARK: - Seeded Random (для стабільних символів дощу)
private struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: Int) { state = UInt64(seed) }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - Matrix Digital Rain (тільки для темного режиму)
struct MatrixRainBackground: View {
    private let fontSize: CGFloat = 14
    private let columnSpacing: CGFloat = 18
    private let chars = "SHRAM0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^&*()_+-="

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let columnsCount = max(1, Int(size.width / columnSpacing))

                    for i in 0..<columnsCount {
                        let x = CGFloat(i) * columnSpacing + columnSpacing / 2
                        let columnChars = generateColumnChars(seed: i)
                        let speed = 25.0 + Double(i % 7) * 3.0
                        let headY = CGFloat(time * speed).truncatingRemainder(
                            dividingBy: size.height + CGFloat(columnChars.count) * (fontSize + 2)
                        )

                        for (index, char) in columnChars.enumerated() {
                            let y = headY - CGFloat(index) * (fontSize + 2)
                            if y > -fontSize && y < size.height + fontSize {
                                let opacity = max(0.15, 1.0 - Double(index) / Double(columnChars.count) * 1.2)
                                context.draw(
                                    Text(String(char))
                                        .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                                        .foregroundColor(.sramRed.opacity(opacity)),
                                    at: CGPoint(x: x, y: y)
                                )
                            }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    private func generateColumnChars(seed: Int) -> [Character] {
        var rng = SeededRandom(seed: seed)
        let length = 8 + Int(rng.next() % 18)
        return (0..<length).map { _ in chars.randomElement(using: &rng)! }
    }
}

// MARK: - Logo
private struct SramLogo: View {
    var body: some View {
        Text("SHRAM")
            .font(.system(size: 68, weight: .black, design: .default))
            .foregroundColor(.sramLogoColor)
    }
}

// MARK: - Login View
struct LoginView: View {
    @Environment(VaultViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var masterPassword = ""
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var biometricAvailable = false
    @State private var showWipeAlert = false

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                MatrixRainBackground()
            } else {
                Color.sramBackground.ignoresSafeArea()
            }

            VStack(spacing: 24) {
                Spacer()

                if viewModel.hasVault {
                    SramLogo()
                    Text("Password Manager")
                        .font(.headline)
                        .foregroundColor(.sramTextSecondary)
                } else {
                    Text("Create Initial Profile")
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundColor(.sramLogoColor)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("MASTER PASSWORD")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(.sramTextSecondary)
                    SecureField("", text: $masterPassword)
                        .padding(10)
                        .background(Color.sramFieldBackground)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.sramBorder, lineWidth: 1))
                        .foregroundColor(.primary)
                        .textContentType(.none)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.go)
                        .onSubmit { unlockAction() }
                }

                Button(viewModel.hasVault ? "Unlock" : "Create Master Password") {
                    unlockAction()
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.sramRed)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .disabled(masterPassword.isEmpty)
                .opacity(masterPassword.isEmpty ? 0.6 : 1)

                if biometricAvailable {
                    Button { unlockWithBiometrics() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: biometricIcon)
                            Text(biometricTitle)
                        }
                        .fontWeight(.medium)
                        .foregroundColor(.sramRed)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.sramSurface)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.sramRed, lineWidth: 1))
                    }
                }

                if viewModel.hasVault {
                    Rectangle()
                        .fill(Color.sramBorder)
                        .frame(height: 1)

                    Button("Wipe Data & Create New Profile") {
                        showWipeAlert = true
                    }
                    .fontWeight(.medium)
                    .foregroundColor(.sramRed)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.sramSurface)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.sramRed, lineWidth: 1))
                }

                Text("Your data never leaves this device.")
                    .font(.footnote)
                    .foregroundColor(.sramTextSecondary)
                Spacer()
            }
            .padding(32)
        }
        .onAppear { checkBiometrics() }
        .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { Text($0) }
        .alert("Wipe All Data?", isPresented: $showWipeAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Wipe", role: .destructive) { Task { await viewModel.wipeAllDataAndReset() } }
        } message: {
            Text("This will permanently delete all your stored passwords. This action cannot be undone.")
        }
    }

    private var biometricIcon: String {
        let ctx = LAContext(); var err: NSError?
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
        return ctx.biometryType == .faceID ? "faceid" : "touchid"
    }
    private var biometricTitle: String {
        let ctx = LAContext(); var err: NSError?
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
        return ctx.biometryType == .faceID ? "Use Face ID" : "Use Touch ID"
    }
    private func checkBiometrics() {
        let ctx = LAContext(); var err: NSError?
        biometricAvailable = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
    }
    private func unlockAction() {
        Task {
            do {
                try await viewModel.unlockVault(masterPassword: masterPassword)
                masterPassword = ""
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    private func unlockWithBiometrics() {
        Task {
            do {
                try await viewModel.unlockWithBiometrics()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
