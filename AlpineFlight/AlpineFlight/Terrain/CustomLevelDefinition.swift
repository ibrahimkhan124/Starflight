import Foundation

/// Versioned terrain recipes keep rendering and collisions on the same height field.
struct CustomLevelDefinition: Codable, Equatable, Identifiable, Sendable {
    // Shared by the editor and recipe validation so every slider value can be saved.
    static let mountainRange: ClosedRange<Float> = 0.25...2
    static let valleyRange: ClosedRange<Float> = 0.7...2
    static let bendRange: ClosedRange<Float> = 0.5...20
    static let saddleRange: ClosedRange<Float> = 0...2

    var id = UUID()
    var formatVersion = 1
    var name = "Star wars level"
    var seed: UInt32 = 7319
    var mountainScale: Float = 1
    var valleyWidth: Float = 1
    var bends: Float = 1
    var saddles: Float = 1

    func validated() throws -> Self {
        guard formatVersion == 1 else { throw CustomContentError.invalid("This level uses an unsupported format version.") }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 48 else {
            throw CustomContentError.invalid("Give the level a name of 1–48 characters.")
        }
        guard mountainScale.isFinite, Self.mountainRange.contains(mountainScale),
              valleyWidth.isFinite, Self.valleyRange.contains(valleyWidth),
              bends.isFinite, Self.bendRange.contains(bends),
              saddles.isFinite, Self.saddleRange.contains(saddles) else {
            throw CustomContentError.invalid("Terrain settings are outside the supported ranges.")
        }
        return self
    }
}

extension CustomLevelDefinition {
    private enum CodingKeys: String, CodingKey { case id, formatVersion, name, seed, mountainScale, valleyWidth, bends, saddles }

    init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        formatVersion = try values.decodeIfPresent(Int.self, forKey: .formatVersion) ?? 1
        name = try values.decode(String.self, forKey: .name)
        seed = try values.decode(UInt32.self, forKey: .seed)
        mountainScale = try values.decodeIfPresent(Float.self, forKey: .mountainScale) ?? 1
        valleyWidth = try values.decodeIfPresent(Float.self, forKey: .valleyWidth) ?? 1
        bends = try values.decodeIfPresent(Float.self, forKey: .bends) ?? 1
        saddles = try values.decodeIfPresent(Float.self, forKey: .saddles) ?? 1
    }
}

enum CustomContentError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}
