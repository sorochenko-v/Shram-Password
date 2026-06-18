// LoginView.swift

import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @Environment(VaultViewModel.self) private var viewModel

    @State private var masterPassword = ""
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var biometricAvailable = false
    @State private var showWipeAlert = false

    var body: some View {
        ZStack {
            Color(white: 0.08).ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()

                if viewModel.hasVault {
                    Text("Sram")
                        .font(.system(size: 42, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .tracking(2)
                    Text("Password Manager")
                        .font(.headline)
                        .foregroundColor(.gray)
                } else {
                    Text("Create Initial Profile")
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("MASTER PASSWORD")
                        .font(.caption).fontWeight(.semibold).foregroundColor(.gray)
                    SecureField("", text: $masterPassword)
                        .padding(10)
                        .background(Color(white: 0.2))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(white: 0.3), lineWidth: 1))
                        .foregroundColor(.white)
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
                        .foregroundColor(Color.sramRed)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color(white: 0.15))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.sramRed, lineWidth: 1))
                    }
                }

                if viewModel.hasVault {
                    Rectangle()
                        .fill(Color(white: 0.3))
                        .frame(height: 1)

                    Button("Wipe Data & Create New Profile") {
                        showWipeAlert = true
                    }
                    .fontWeight(.medium)
                    .foregroundColor(.sramRed)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color(white: 0.15))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.sramRed, lineWidth: 1))
                }

                Text("Your data never leaves this device.")
                    .font(.footnote)
                    .foregroundColor(.gray)

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
            Button("Wipe", role: .destructive) {
                Task { await viewModel.wipeAllDataAndReset() }
            }
        } message: {
            Text("This will permanently delete all your stored passwords. This action cannot be undone.")
        }
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
