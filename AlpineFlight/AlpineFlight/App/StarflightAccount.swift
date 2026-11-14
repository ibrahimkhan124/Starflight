import Foundation
import Security
import SwiftUI

struct AccountConfiguration {
    let url: URL
    let publicKey: String
    static func load(bundle: Bundle = .main) -> Self? {
        guard let address = bundle.object(forInfoDictionaryKey:"StarflightAccountURL") as? String,
              let url = URL(string:address), url.scheme == "https", let host = url.host, !host.isEmpty,
              let key = bundle.object(forInfoDictionaryKey:"StarflightAccountPublicKey") as? String,
              isPublicKey(key) else { return nil }
        return Self(url:url,publicKey:key)
    }
    static func isPublicKey(_ key: String) -> Bool {
        if key.hasPrefix("sb_publishable_"), key.count > 24 { return true }
        let parts = key.split(separator:".")
        guard parts.count == 3 else { return false }
        var encoded = String(parts[1]).replacingOccurrences(of:"-",with:"+").replacingOccurrences(of:"_",with:"/")
        while encoded.count % 4 != 0 { encoded += "=" }
        guard let data = Data(base64Encoded:encoded), let json = try? JSONSerialization.jsonObject(with:data) as? [String:Any] else { return false }
        return json["role"] as? String == "anon"
    }
}
struct AccountSession: Codable {
    struct User: Codable { let id: UUID; let email: String? }
    let accessToken: String
    let refreshToken: String
    let expiresIn: Double?
    let expiresAt: Double?
    let user: User
    var expiry: Date { Date(timeIntervalSince1970:expiresAt ?? 0) }
}
struct OnlineSaveHead: Codable {
    let revision: UUID
    let objectPath: String
    let updatedAt: String
}

/// A separate service per endpoint prevents credentials from crossing server changes.
protocol AccountSessionStore {
    func load() -> Data?
    func store(_ data:Data?) throws
}
struct AccountKeychain:AccountSessionStore {
    let service: String
    func load() -> Data? {
        let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"session",kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var value: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary,&value) == errSecSuccess else { return nil }
        return value as? Data
    }
    func store(_ data:Data?) throws {
        let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"session"]
        guard let data else { SecItemDelete(query as CFDictionary); return }
        let status = SecItemUpdate(query as CFDictionary,[kSecValueData as String:data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = query; add[kSecValueData as String] = data; add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(add as CFDictionary,nil) == errSecSuccess else { throw AccountError.message("Could not securely save the sign-in session.") }; return
        }
        guard status == errSecSuccess else { throw AccountError.message("Could not securely update the sign-in session.") }
    }
}

@MainActor
final class StarflightAccount: ObservableObject {
    @Published private(set) var email: String?
    @Published private(set) var awaitingEmailConfirmation = false
    @Published private(set) var busy = false
    @Published private(set) var message = "Play offline, or sign in to take your progress to another device."
    @Published private(set) var onlineSave: OnlineSaveHead?
    @Published private(set) var hasCheckedSave = false
    @Published private(set) var needsSaveChoice = false
    private var session: AccountSession?
    private let configuration: AccountConfiguration?
    private let transport: URLSession
    private let keychain: (any AccountSessionStore)?
    private let defaults: UserDefaults
    private var boundUser: String?
    var configured: Bool { configuration != nil }
    var signedIn: Bool { session != nil }
    var userID: UUID? { session?.user.id }
    static let decoder: JSONDecoder = { let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d }()

    init(defaults:UserDefaults = .standard,configuration:AccountConfiguration? = AccountConfiguration.load(),transport:URLSession = URLSession(configuration:.ephemeral,delegate:AccountRedirectBlocker(),delegateQueue:nil),restoreSession:Bool = true,credentialStore:(any AccountSessionStore)? = nil) {
        self.defaults = defaults; self.configuration = configuration; self.transport = transport
        keychain = credentialStore ?? configuration.map { AccountKeychain(service:"starflight.account."+$0.url.absoluteString) }
        if restoreSession, let data = keychain?.load(), let stored = try? Self.decoder.decode(AccountSession.self,from:data) {
            session = stored; email = stored.user.email
        }
        if !configured { message = "Online accounts aren’t available in this build yet. Your progress is safely stored on this device." }
    }
    private func auth(_ path:String,body:[String:String]) async throws -> Data {
        try await request(path:path,method:"POST",body:JSONSerialization.data(withJSONObject:body),authenticated:false)
    }
    static func validEmail(_ value: String) -> Bool {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".") && !parts[1].hasPrefix(".") && !parts[1].hasSuffix(".") && !value.contains(where: { $0.isWhitespace })
    }
    func signIn(email:String,password:String) async {
        await perform {
            guard Self.validEmail(email) else { throw AccountError.message("Enter a complete email address, such as pilot@example.com.") }
            let data = try await self.auth("auth/v1/token?grant_type=password",body:["email":email.trimmingCharacters(in:.whitespacesAndNewlines),"password":password])
            try self.accept(data)
            self.message = "Signed in. Check the online save before choosing which progress to use."
        }
    }
    func signUp(email:String,password:String) async {
        await perform {
            guard Self.validEmail(email) else { throw AccountError.message("Enter a complete email address, such as pilot@example.com.") }
            guard password.count >= 12 else { throw AccountError.message("Use a password with at least 12 characters.") }
            let data = try await self.auth("auth/v1/signup",body:["email":email.trimmingCharacters(in:.whitespacesAndNewlines),"password":password])
            if (try? Self.decoder.decode(AccountSession.self,from:data)) != nil { try self.accept(data) }
            self.awaitingEmailConfirmation = !self.signedIn
            self.message = self.signedIn ? "Account created. Check your online save." : "Open the confirmation email and tap Confirm your email. The link opens Starflight; then sign in here. If you confirm on another device, return to Starflight there and sign in."
        }
    }
    func resendConfirmation(email: String) async {
        await perform {
            guard Self.validEmail(email) else { throw AccountError.message("Enter your email address first.") }
            _ = try await self.auth("auth/v1/resend", body: ["email": email.trimmingCharacters(in: .whitespacesAndNewlines), "type": "signup"])
            self.awaitingEmailConfirmation = true
            self.message = "Confirmation email requested. Check your inbox and junk folder, tap its confirmation link, then return to sign in."
        }
    }
    func confirmEmail(email:String,code:String) async {
        await perform {
            guard let config = self.configuration else { return }
            let body = try Self.verificationBody(email: email, input: code, type: "email", serviceURL: config.url)
            let data = try await self.auth("auth/v1/verify", body: body)
            try self.accept(data); self.message = "Email confirmed. Choose which save to use."
        }
    }
    func requestReset(email:String) async {
        await perform {
            guard Self.validEmail(email) else { throw AccountError.message("Enter a complete recovery email address first.") }
            _ = try await self.auth("auth/v1/recover",body:["email":email.trimmingCharacters(in:.whitespacesAndNewlines)])
            self.message = "If an account exists, a password reset email has been requested. Copy its Reset password link without opening it, paste it below, and choose a new password. A code also works if the email includes one."
        }
    }
    func resetPassword(email:String,code:String,password:String) async {
        await perform {
            guard password.count >= 12 else { throw AccountError.message("Use a password with at least 12 characters.") }
            guard let config = self.configuration else { return }
            let body = try Self.verificationBody(email: email, input: code, type: "recovery", serviceURL: config.url)
            let data = try await self.auth("auth/v1/verify", body: body)
            let recoverySession = try Self.decoder.decode(AccountSession.self, from: data)
            do {
                _ = try await self.request(path:"auth/v1/user",method:"PUT",body:JSONSerialization.data(withJSONObject:["password":password]),authenticated:false,bearer:recoverySession.accessToken)
            } catch {
                throw AccountError.message(error.localizedDescription + " The reset link was used: request a fresh reset email before trying again.")
            }
            // A verified reset link alone does not mean the new password was accepted.
            try self.accept(data)
            self.message = "Password updated. You’re signed in."
        }
    }
    /// Only parse the configured project's verification links. Never follow pasted URLs.
    static func verificationBody(email: String, input: String, type: String, serviceURL: URL) throws -> [String:String] {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if (6...10).contains(text.count), text.allSatisfy({ $0.isNumber }) {
            return ["email": email.trimmingCharacters(in: .whitespacesAndNewlines), "token": text, "type": type]
        }
        guard let parts = URLComponents(string: text), parts.scheme == "https", parts.host == serviceURL.host,
              parts.user == nil, parts.password == nil, parts.port == nil || parts.port == 443,
              parts.path == "/auth/v1/verify" else {
            throw AccountError.message("Paste the full link from the latest Starflight email, or its 6–10 digit code.")
        }
        let query = parts.queryItems ?? []
        let linkType = query.first(where: { $0.name == "type" })?.value
        guard linkType == type || (type == "email" && linkType == "signup"),
              let token = query.first(where: { $0.name == "token_hash" || $0.name == "token" })?.value,
              (20...512).contains(token.count), token.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }) else {
            throw AccountError.message("This link is for a different account action. Request a fresh Starflight email and use its full link.")
        }
        return ["token_hash": token, "type": type]
    }

    private func accept(_ data:Data) throws {
        let decoded = try Self.decoder.decode(AccountSession.self,from:data)
        let incoming = AccountSession(accessToken:decoded.accessToken,refreshToken:decoded.refreshToken,
            expiresIn:decoded.expiresIn,expiresAt:decoded.expiresAt ?? Date().timeIntervalSince1970+(decoded.expiresIn ?? 3600),user:decoded.user)
        // Store with the matching encoder; never write passwords to preferences or logs.
        let encoder = JSONEncoder(); encoder.keyEncodingStrategy = .convertToSnakeCase
        try keychain?.store(encoder.encode(incoming))
        session = incoming; email = incoming.user.email; awaitingEmailConfirmation = false
        onlineSave = nil; hasCheckedSave = false; needsSaveChoice = true
    }
    func signOut() {
        guard !busy else { return }
        try? keychain?.store(nil)
        session = nil; email = nil; onlineSave = nil; hasCheckedSave = false; needsSaveChoice = false
        message = "Signed out. Your device’s progress is unchanged."
    }
    func deleteAccount() async {
        await perform {
            _ = try await self.request(path:"functions/v1/delete-account",method:"POST",body:Data("{}".utf8))
            try self.keychain?.store(nil)
            self.session = nil; self.email = nil; self.onlineSave = nil
            self.hasCheckedSave = false; self.needsSaveChoice = false
            self.message = "Account and online saves deleted. This device’s progress is unchanged."
        }
    }
    func checkOnlineSave() async {
        await perform {
            self.onlineSave = try await self.fetchHead()
            self.hasCheckedSave = true
            self.needsSaveChoice = true
            self.message = self.onlineSave == nil ? "No online save yet. Save this device’s progress to start." : "Online save found. Choose which progress to use. A device backup is kept before loading."
        }
    }
    func upload(_ archive:PlayerSaveArchive) async {
        await perform {
            guard self.hasCheckedSave, let user = self.userID else { throw AccountError.message("Check the online save first.") }
            let revision = UUID(), path = user.uuidString.lowercased()+"/"+UUID().uuidString.lowercased()+".json"
            let data = try archive.encoded()
            _ = try await self.request(path:"storage/v1/object/starflight-saves/"+path,method:"POST",body:data)
            struct Commit: Encodable { let pExpected:UUID?; let pRevision:UUID; let pPath:String
                enum CodingKeys:String,CodingKey { case pExpected = "p_expected", pRevision = "p_revision", pPath = "p_path" }
                func encode(to encoder:Encoder) throws { var c = encoder.container(keyedBy:CodingKeys.self); try c.encode(pExpected,forKey:.pExpected); try c.encode(pRevision,forKey:.pRevision); try c.encode(pPath,forKey:.pPath) }
            }
            let response = try await self.request(path:"rest/v1/rpc/commit_player_save",method:"POST",body:JSONEncoder().encode(Commit(pExpected:self.onlineSave?.revision,pRevision:revision,pPath:path)))
            let heads = try Self.decoder.decode([OnlineSaveHead].self,from:response)
            guard let committed = heads.first else {
                self.hasCheckedSave = false; self.needsSaveChoice = true
                throw AccountError.message("Another device updated your online save. Check it again before choosing which progress to keep.")
            }
            self.onlineSave = committed
            self.bind(archive)
            self.message = "Progress saved online. Sign in on your other device and load this save."
        }
    }
    func download() async throws -> PlayerSaveArchive {
        guard !busy else { throw AccountError.message("Please wait for the current account action.") }
        busy = true; defer { busy = false }
        guard hasCheckedSave, let head = onlineSave, let user = userID,
              head.objectPath.hasPrefix(user.uuidString.lowercased()+"/"), head.objectPath.split(separator:"/").count == 2,
              head.objectPath.hasSuffix(".json"), UUID(uuidString:String(head.objectPath.split(separator:"/").last!.dropLast(5))) != nil else { throw AccountError.message("Check and select an online save first.") }
        let data = try await request(path:"storage/v1/object/authenticated/starflight-saves/"+head.objectPath,method:"GET")
        guard data.count <= PlayerSaveArchive.maximumBytes else { throw AccountError.message("Online save is too large for this version.") }
        return try JSONDecoder().decode(PlayerSaveArchive.self,from:data).validated()
    }
    func didRestore(_ archive:PlayerSaveArchive) { bind(archive); message = "Online progress loaded. Your previous device save was backed up." }
    func report(_ error:Error) { message = error.localizedDescription }
    private func bind(_ archive:PlayerSaveArchive) {
        guard let id = userID else { return }
        boundUser = id.uuidString
        defaults.set(boundUser,forKey:"starflight.account.bound-user")
        defaults.set(try? archive.fingerprint(),forKey:"starflight.account.last-save")
        needsSaveChoice = false
    }
    /// Auto-save only after an explicit device/cloud choice for this account.
    func autoSave(_ archive:PlayerSaveArchive) async {
        guard signedIn, !busy, !needsSaveChoice,
              defaults.string(forKey:"starflight.account.bound-user") == userID?.uuidString else { return }
        guard let hash = try? archive.fingerprint(), hash != defaults.string(forKey:"starflight.account.last-save") else { return }
        // The stored revision is used for compare-and-swap; stale devices cannot overwrite.
        await upload(archive)
    }
    private func fetchHead() async throws -> OnlineSaveHead? {
        guard let id = userID else { throw AccountError.message("Sign in first.") }
        let data = try await request(path:"rest/v1/player_saves?select=revision,object_path,updated_at&user_id=eq."+id.uuidString+"&limit=1",method:"GET")
        return try Self.decoder.decode([OnlineSaveHead].self,from:data).first
    }
    private func perform(_ action:() async throws -> Void) async {
        guard configured, !busy else { return }
        busy = true; defer { busy = false }
        do { try await action() } catch { message = error.localizedDescription }
    }
    private func request(path:String,method:String,body:Data? = nil,authenticated:Bool = true,bearer:String? = nil) async throws -> Data {
        guard let config = configuration else { throw AccountError.message("Online accounts are not configured in this build.") }
        if authenticated {
            guard let current = session else { throw AccountError.message("Sign in first.") }
            if current.expiry < Date().addingTimeInterval(60) {
                let data = try await auth("auth/v1/token?grant_type=refresh_token",body:["refresh_token":current.refreshToken])
                let previous = onlineSave, checked = hasCheckedSave, choice = needsSaveChoice
                try accept(data)
                onlineSave = previous; hasCheckedSave = checked; needsSaveChoice = choice
            }
        }
        guard let url = URL(string:path,relativeTo:config.url.appendingPathComponent("/"))?.absoluteURL,
              url.host == config.url.host, url.scheme == "https" else { throw AccountError.message("Invalid account service address.") }
        var request = URLRequest(url:url); request.httpMethod = method; request.httpBody = body; request.timeoutInterval = 45
        request.setValue(config.publicKey,forHTTPHeaderField:"apikey")
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        if let token = bearer ?? (authenticated ? session?.accessToken : nil) { request.setValue("Bearer "+token,forHTTPHeaderField:"Authorization") }
        let (data,response) = try await transport.data(for:request)
        guard let http = response as? HTTPURLResponse else { throw AccountError.message("The account service didn’t respond.") }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 {
                if authenticated || path.contains("grant_type=refresh_token") {
                    try? keychain?.store(nil); session = nil; email = nil; hasCheckedSave = false; needsSaveChoice = false; onlineSave = nil
                }
                throw AccountError.message("Sign-in expired or the email/password was not accepted. Please sign in again.") }
            if http.statusCode == 429 { throw AccountError.message("Too many attempts. Please wait a little before trying again.") }
            // GoTrue uses a numeric `code` alongside string `error_code` and `msg`.
            // A String-only Decodable discarded the entire error, leaving players with just “400”.
            let info = (try? JSONSerialization.jsonObject(with: data)) as? [String:Any] ?? [:]
            let code = info["error_code"] as? String ?? info["code"] as? String ?? ""
            let detail = info["msg"] as? String ?? info["message"] as? String ?? info["error_description"] as? String ?? info["error"] as? String
            if code == "invalid_credentials" || code == "invalid_login_credentials" {
                throw AccountError.message("The email and password don’t match an account. If you registered before, use Forgot password; creating an account again does not change its password.")
            }
            if code == "otp_expired" {
                throw AccountError.message("That email link or code is expired or was already used. Request a fresh email and use only its newest link or code.")
            }
            if code == "weak_password" {
                throw AccountError.message("Choose a new password with at least 12 characters. Avoid common or previously exposed passwords.")
            }
            if code == "email_address_not_authorized" || (detail ?? "").localizedCaseInsensitiveContains("email address not authorized") {
                throw AccountError.message("Starflight’s email sender is not set up for this address yet. The game owner needs to connect an email provider before new players can register. Your offline progress is safe.")
            }
            if code == "email_not_confirmed" {
                awaitingEmailConfirmation = true
                throw AccountError.message("Confirm your email first: open the email link, then return and sign in. You can request another email below.")
            }
            if code == "over_email_send_rate_limit" {
                throw AccountError.message("The confirmation email limit has been reached. Wait before requesting another email; Starflight’s email sender may need configuring.")
            }
            throw AccountError.message(detail ?? "The account action failed (\(http.statusCode)). Try again later.")
        }
        return data
    }
}


final class AccountRedirectBlocker:NSObject,URLSessionTaskDelegate {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping (URLRequest?)->Void) {
        completionHandler(nil)
    }
}
