import SwiftUI

struct AccountSettingsSection: View {
    @ObservedObject var engine:GameEngine
    @ObservedObject var account:StarflightAccount
    let openAccount: () -> Void
    init(engine:GameEngine,openAccount:@escaping ()->Void) { self.engine = engine; account = engine.account; self.openAccount = openAccount }
    var body: some View {
        Section("Account") {
            Button(action:openAccount) {
                Label(account.email ?? "Sign in / create account",systemImage:"person.crop.circle")
            }.buttonStyle(MenuActionButtonStyle()).accessibilityIdentifier("Starflight account")
            Text(account.configured ? "Take your ships, credits, homes, and flight history to another device." : "Online accounts are not available in this build yet. Offline play and your device save still work.")
                .font(.caption).foregroundStyle(FlightPalette.secondary)
        }
    }
}

struct AccountView:View {
    @ObservedObject var engine:GameEngine
    @ObservedObject var account:StarflightAccount
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var recovery = false
    @State private var creating = false
    @State private var showPassword = false
    @State private var codeEntry = false
    @State private var resendCoolingDown = false
    @State private var confirmation: Action?
    enum Action:String,Identifiable { case upload, download, delete; var id:String { rawValue } }
    var body:some View {
        NavigationStack {
            Form {
                if account.signedIn || account.busy || account.message != "Play offline, or sign in to take your progress to another device." {
                    Section {
                        Text(account.message).font(.subheadline).accessibilityIdentifier("Account status")
                        if account.busy { ProgressView("Connecting…") }
                    }
                }
                if account.configured {
                    if account.signedIn {
                        Section("Signed in") {
                            Text(account.email ?? "Starflight pilot")
                            Button("Sign out") { account.signOut() }.flightButtonGlass().accessibilityIdentifier("Sign out of Starflight")
                        }
                        Section("Your progress") {
                            Text("Device balance: "+engine.economy.creditsLabel+" credits")
                            if let save = account.onlineSave { Text("Online save: "+save.updatedAt).font(.caption) }
                            Button("Check online save") { Task { await account.checkOnlineSave() } }.flightButtonGlass()
                                .accessibilityIdentifier("Check online save")
                            Button("Save device progress online") { confirmation = .upload }.flightButtonGlass()
                                .disabled(!account.hasCheckedSave || engine.phase != .title)
                            Button("Load online progress") { confirmation = .download }.flightButtonGlass()
                                .disabled(account.onlineSave == nil || engine.phase != .title)
                            Text("Return to base before transferring a save. Ships, credits, blueprints, homes, furniture, checkpoints, flight history, and imported creations are included. Control settings stay on each device. A local backup is kept before loading an online save.")
                                .font(.caption).foregroundStyle(.white)
                            Text("Choose your device or online save once after signing in. Completed flights then save online when you return to base. Use Save device progress online before switching devices after shopping or editing creations. Internet access is needed to transfer saves; offline play remains available.")
                                .font(.caption).foregroundStyle(.white)
                        }
                        Section { Button("Delete Starflight account",role:.destructive) { confirmation = .delete }.flightButtonGlass() }
                    } else if !recovery {
                        Section {
                            Picker("Account action", selection: $creating) {
                                Text("Sign in").tag(false)
                                Text("Create account").tag(true)
                            }.pickerStyle(.segmented).accessibilityIdentifier("Account action")
                            TextField("Email address", text: $email).textContentType(.username).autocorrectionDisabled()
                                .textInputAutocapitalization(.never).keyboardType(.emailAddress)
                                .accessibilityIdentifier("Starflight email")
                            HStack {
                                Group {
                                    if showPassword { TextField("Password", text: $password) }
                                    else { SecureField("Password", text: $password) }
                                }.textContentType(creating ? .newPassword : .password)
                                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                                    .accessibilityIdentifier("Starflight password")
                                Button { showPassword.toggle() } label: { Image(systemName: showPassword ? "eye.slash" : "eye") }
                                    .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                            }
                            if creating {
                                Label(password.count >= 12 ? "Password length ready" : "Use at least 12 characters (\(password.count)/12)", systemImage: password.count >= 12 ? "checkmark.circle.fill" : "lock")
                                    .font(.caption).foregroundStyle(password.count >= 12 ? FlightPalette.teal : FlightPalette.secondary)
                            }
                            Button(creating ? "Create my account" : "Sign in") {
                                Task {
                                    if creating { await account.signUp(email: email, password: password) }
                                    else { await account.signIn(email: email, password: password) }
                                    if account.signedIn { password = ""; await account.checkOnlineSave() }
                                }
                            }.buttonStyle(MenuActionButtonStyle(accent: FlightPalette.cyan, prominent: true))
                                .disabled(!StarflightAccount.validEmail(email) || password.isEmpty || (creating && password.count < 12))
                                .accessibilityIdentifier("Submit Starflight account")
                            if !email.isEmpty && !StarflightAccount.validEmail(email) {
                                Text("Enter a complete email address, such as pilot@example.com.").font(.caption).foregroundStyle(FlightPalette.gold)
                            }
                            if creating {
                                Text("Already registered? Signing up again won’t change your password. Use Sign in or Forgot password.")
                                    .font(.caption).foregroundStyle(FlightPalette.secondary)
                            }
                            if !creating { Button("Forgot password?") { recovery = true }.flightButtonGlass() }
                        }
                        if account.awaitingEmailConfirmation {
                            Section("Confirm your email") {
                                Label("Check your inbox and junk folder", systemImage: "envelope.badge").foregroundStyle(FlightPalette.gold)
                                Text("Tap the confirmation link in the email, then return here. You don’t need a code unless your email actually includes one.").font(.subheadline)
                                Button("I’ve confirmed — sign in") {
                                    creating = false
                                    if !password.isEmpty { Task { await account.signIn(email: email, password: password); if account.signedIn { password = ""; await account.checkOnlineSave() } } }
                                }.buttonStyle(MenuActionButtonStyle()).accessibilityIdentifier("Sign in after email confirmation")
                                Button(resendCoolingDown ? "Wait before resending…" : "Resend confirmation email") {
                                    resendCoolingDown = true
                                    Task { await account.resendConfirmation(email: email); try? await Task.sleep(for: .seconds(60)); resendCoolingDown = false }
                                }.flightButtonGlass().disabled(resendCoolingDown || !StarflightAccount.validEmail(email))
                                DisclosureGroup("Use an email link or code", isExpanded: $codeEntry) {
                                    TextField("Email confirmation link or code", text: $code).autocorrectionDisabled().textInputAutocapitalization(.never).privacySensitive()
                                    Button("Confirm email") { Task { await account.confirmEmail(email: email, code: code); code = ""; if account.signedIn { password = ""; await account.checkOnlineSave() } } }
                                        .flightButtonGlass().disabled(code.isEmpty)
                                }
                            }
                        }
                    }
                    if recovery && !account.signedIn {
                        Section("Password recovery") {
                            Button("Back to sign in") { recovery = false; code = ""; newPassword = "" }.flightButtonGlass()
                            TextField("Recovery email",text:$email).autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(.emailAddress)
                            Button("Send password reset email") { Task { await account.requestReset(email:email) } }.flightButtonGlass().disabled(!StarflightAccount.validEmail(email))
                            Text("Copy the Reset password link from the email without opening it, then paste it below. If you already opened it or it expired, request a new email.")
                                .font(.subheadline).foregroundStyle(FlightPalette.cyan)
                            TextField("Reset link or email code",text:$code).autocorrectionDisabled().textInputAutocapitalization(.never)
                                .privacySensitive().accessibilityIdentifier("Starflight recovery link")
                            SecureField("New password (at least 12 characters)",text:$newPassword).textContentType(.newPassword)
                            Button("Set new password") {
                                Task {
                                    await account.resetPassword(email:email,code:code,password:newPassword)
                                    newPassword = ""; code = ""
                                    if account.message.hasPrefix("Password updated") { recovery = false; password = ""; await account.checkOnlineSave() }
                                }
                            }.flightButtonGlass().disabled(code.isEmpty || newPassword.count < 12)
                        }
                    }
                }
            }.disabled(account.busy)
                .navigationTitle("Starflight account")
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { password = ""; newPassword = ""; dismiss() }.flightButtonGlass().accessibilityIdentifier("Close Starflight account").disabled(account.busy) } }
                .confirmationDialog(confirmationTitle,isPresented:Binding(get:{confirmation != nil},set:{if !$0 { confirmation = nil }}),titleVisibility:.visible) {
                    if let action = confirmation {
                        Button(action == .delete ? "Delete account and online saves" : action == .upload ? "Use this device’s save" : "Use the online save",role:action == .delete ? .destructive:nil) {
                            Task {
                                switch action {
                                case .upload: await engine.uploadPlayerSave()
                                case .download: await engine.downloadPlayerSave()
                                case .delete: await account.deleteAccount()
                                }
                            }
                        }.flightButtonGlass()
                    }
                    Button("Cancel",role:.cancel) { confirmation = nil }.flightButtonGlass()
                } message: { Text(confirmation == .delete ? "This permanently deletes this Starflight account and its online saves. Progress stored on this device is kept." : confirmation == .upload ? "This replaces the online progress with this device’s current progress. Existing credits from two saves are not added together." : "This replaces device progress with the selected online save. A complete backup of this device’s previous save is kept first.") }
        }.preferredColorScheme(.dark).tint(FlightPalette.cyan)
            .onDisappear { password = ""; newPassword = ""; code = "" }
    }
    private var confirmationTitle:String { confirmation == .delete ? "Delete account?" : confirmation == .upload ? "Save this device online?" : "Load online progress?" }
}
