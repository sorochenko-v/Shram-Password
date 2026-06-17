//  LoginView.swift

import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @Environment(VaultViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var masterPassword = ""
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var biometricAvailable = false

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Text("Sram")
                    .font(.system(size: 42, weight: .bold, design: .default))
                    .foregroundColor(.primary)
                    .tracking(2)
                Text("Password Manager")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 6) {
                    Text("MASTER PASSWORD")
                        .font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                    SecureField("Enter master password", text: $masterPassword)
                        .padding(10)
                        .background(inputBackground)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(borderColor, lineWidth: 1))
                        .submitLabel(.go)
                        .onSubmit { unlockWithPassword() }
                }

                Button("Unlock") { unlockWithPassword() }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .disabled(masterPassword.isEmpty)
                    .opacity(masterPassword.isEmpty ? 0.6 : 1)

                if biometricAvailable {
                    Button { unlockWithBiometrics() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: biometricIcon)
                            Text(biometricTitle)
                        }
                        .fontWeight(.medium)
                        .foregroundColor(Color.accentColor)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(surfaceColor)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 1))
                    }
                }
                Spacer()
                Text("Your data never leaves this device.")
                    .font(.footnote).foregroundColor(.secondary)
            }
            .padding(32)
        }
        .onAppear { checkBiometrics() }
        .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { Text($0) }
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
    private var biometricIcon: String {
        let ctx = LAContext()
        var err: NSError?
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
        return ctx.biometryType == .faceID ? "faceid" : "touchid"
    }
    private var biometricTitle: String {
        let ctx = LAContext()
        var err: NSError?
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
        return ctx.biometryType == .faceID ? "Use Face ID" : "Use Touch ID"
    }

    private func checkBiometrics() {
        let ctx = LAContext()
        var err: NSError?
        biometricAvailable = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err)
    }

    private func unlockWithPassword() {
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
