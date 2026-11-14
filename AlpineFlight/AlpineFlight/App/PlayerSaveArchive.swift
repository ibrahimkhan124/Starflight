import Foundation
import CryptoKit

/// Only game-owned progress is transferable. Control calibration, permissions and
/// auth credentials stay on each device. Model imports travel with their library.
struct PlayerSaveArchive: Codable {
    var version = 1
    var savedAt = Date()
    var customShipID:UUID?
    var customLevelID:UUID?
    var preferences: [String: Value] = [:]
    var creations: [String: Data] = [:]
    enum Value: Codable { case data(Data), text(String), integer(Int), flag(Bool) }
    static let dataKeys = [FlightEconomy.key, "starflight.pilot-logbook.v1"]
    static let textKeys = ["aircraft", "aircraftColor", "droid", "level"]
    static var scoreKeys: [String] { FlightLevel.allCases.map { "bestGates."+$0.rawValue }+["bestGates"] }
    static let maximumBytes = 48*1024*1024
    static var allowedKeys: Set<String> { Set(dataKeys+textKeys+scoreKeys+["spaceFreeRoam"]) }

    static func capture(defaults: UserDefaults, creationsURL: URL,customShipID:UUID? = nil,customLevelID:UUID? = nil) throws -> Self {
        var save = Self()
        save.customShipID = customShipID; save.customLevelID = customLevelID
        for key in dataKeys { if let data = defaults.data(forKey:key) { save.preferences[key] = .data(data) } }
        for key in textKeys { if let value = defaults.string(forKey:key) { save.preferences[key] = .text(value) } }
        for key in scoreKeys { if defaults.object(forKey:key) != nil { save.preferences[key] = .integer(defaults.integer(forKey:key)) } }
        save.preferences["spaceFreeRoam"] = .flag(defaults.bool(forKey:"spaceFreeRoam"))
        if FileManager.default.fileExists(atPath:creationsURL.path) {
            var totalBytes = 0
            for url in try FileManager.default.contentsOfDirectory(at:creationsURL,includingPropertiesForKeys:[.isRegularFileKey,.fileSizeKey]) {
                guard url.lastPathComponent == "library.json" || url.pathExtension.lowercased() == "usdz" else { continue }
                guard try url.resourceValues(forKeys:[.isRegularFileKey]).isRegularFile == true else { continue }
                let size = try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
                totalBytes += size
                guard size <= 20*1024*1024, totalBytes <= 32*1024*1024 else { throw AccountError.message("The creations library is too large for online saves.") }
                save.creations[url.lastPathComponent] = try Data(contentsOf:url)
            }
        }
        return try save.validated()
    }
    func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(validated())
        guard data.count <= Self.maximumBytes else { throw AccountError.message("This save is too large to upload. The online save limit is 48 MB including imported models.") }
        return data
    }
    func fingerprint() throws -> String {
        var copy = self; copy.savedAt = Date(timeIntervalSince1970:0)
        return SHA256.hash(data:try copy.encoded()).map { String(format:"%02x",$0) }.joined()
    }
    func validated() throws -> Self {
        guard version == 1, savedAt.timeIntervalSince1970.isFinite,
              Set(preferences.keys).isSubset(of:Self.allowedKeys) else { throw AccountError.message("This save has an unsupported format.") }
        for (key,value) in preferences {
            switch value {
            case .data(let data):
                guard Self.dataKeys.contains(key), data.count < 10*1024*1024 else { throw AccountError.message("Invalid progress data.") }
                if key == FlightEconomy.key {
                    let wallet = try JSONDecoder().decode(FlightEconomy.self,from:data)
                    guard wallet.quarterCredits >= 0, wallet.quarterCredits <= Int.max/4, wallet.trading?.valid != false, wallet.adventures?.valid != false, wallet.story?.valid != false, wallet.validStoryRewards else { throw AccountError.message("Invalid credit balance or adventure progress.") }
                } else { _ = try JSONDecoder().decode(PilotLogbook.self,from:data) }
            case .text(let text):
                let valid = key == "aircraft" ? AircraftType(rawValue:text) != nil : key == "aircraftColor" ? AircraftColor(rawValue:text) != nil : key == "droid" ? DroidType(rawValue:text) != nil : key == "level" && FlightLevel(rawValue:text) != nil
                guard valid else { throw AccountError.message("This save contains an unknown ship or region. Update Starflight first.") }
            case .integer(let value): guard Self.scoreKeys.contains(key), (0...10000).contains(value) else { throw AccountError.message("Invalid checkpoint score.") }
            case .flag: guard key == "spaceFreeRoam" else { throw AccountError.message("Invalid save setting.") }
            }
        }
        var total = 0
        for (name,data) in creations {
            guard name == "library.json" || (name.hasSuffix(".usdz") && UUID(uuidString:String(name.dropLast(5))) != nil),
                  !data.isEmpty, data.count <= 20*1024*1024 else { throw AccountError.message("Invalid imported-ship file in save.") }
            total += data.count
            guard total <= 32*1024*1024 else { throw AccountError.message("Your creations library is too large to sync (32 MB of models per save). Export some models before trying again.") }
        }
        if !creations.isEmpty {
            struct Library: Decodable { let ships:[CustomShip]; let levels:[CustomLevelDefinition] }
            guard let data = creations["library.json"] else { throw AccountError.message("The saved creations library is incomplete.") }
            let library = try JSONDecoder().decode(Library.self,from:data)
            guard customShipID == nil || library.ships.contains(where:{$0.id == customShipID}),
                  customLevelID == nil || library.levels.contains(where:{$0.id == customLevelID}) else { throw AccountError.message("The selected creation is missing from this save.") }
            for level in library.levels { _ = try level.validated() }
            guard Set(library.ships.map { $0.id.uuidString+".usdz" }) == Set(creations.keys.filter { $0 != "library.json" }) else { throw AccountError.message("The saved ship models do not match their library.") }
        } else if customShipID != nil || customLevelID != nil { throw AccountError.message("The selected creation has no saved library.") }
        return self
    }
    /// Validate and stage every file before touching a live save. Keep a full local
    /// backup for recovery; auth/device preferences are never replaced.
    func restore(defaults: UserDefaults, creationsURL: URL) throws {
        _ = try validated()
        let fm = FileManager.default
        let backupRoot = creationsURL.deletingLastPathComponent().appendingPathComponent("AccountSaveBackups",isDirectory:true)
        try fm.createDirectory(at:backupRoot,withIntermediateDirectories:true)
        let backup = backupRoot.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try fm.createDirectory(at:backup,withIntermediateDirectories:true)
        let local = try Self.capture(defaults:defaults,creationsURL:creationsURL)
        try local.encoded().write(to:backup.appendingPathComponent("previous-save.json"),options:.atomic)
        let staging = backup.appendingPathComponent("incoming",isDirectory:true)
        try fm.createDirectory(at:staging,withIntermediateDirectories:true)
        for (name,data) in creations { try data.write(to:staging.appendingPathComponent(name),options:.atomic) }
        let oldFiles = backup.appendingPathComponent("previous-creations",isDirectory:true)
        let hadOld = fm.fileExists(atPath:creationsURL.path)
        if hadOld { try fm.moveItem(at:creationsURL,to:oldFiles) }
        do { try fm.moveItem(at:staging,to:creationsURL) }
        catch { if hadOld { try? fm.moveItem(at:oldFiles,to:creationsURL) }; throw error }
        for key in Self.allowedKeys { defaults.removeObject(forKey:key) }
        defaults.removeObject(forKey:"starflight.pilot-drafts.v1")
        for (key,value) in preferences {
            switch value {
            case .data(let data): defaults.set(data,forKey:key)
            case .text(let text): defaults.set(text,forKey:key)
            case .integer(let number): defaults.set(number,forKey:key)
            case .flag(let flag): defaults.set(flag,forKey:key)
            }
        }
    }
}

enum AccountError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let value) = self { return value }; return nil }
}
