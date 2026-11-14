import Foundation
import RealityKit
import SwiftUI

struct CustomShip: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let handling: AircraftType
}

@MainActor
final class CustomContentStore: ObservableObject {
    @Published private(set) var ships: [CustomShip] = []
    @Published private(set) var levels: [CustomLevelDefinition] = []
    @Published private(set) var loadError: String?
    private let directory: URL
    private struct Library: Codable { var ships: [CustomShip]; var levels: [CustomLevelDefinition] }

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MyCreations", isDirectory: true)
        reload()
    }
    var storageURL:URL { directory }
    func reload() {
        ships = []; levels = []; loadError = nil
        do {
            try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
            let manifest = self.directory.appendingPathComponent("library.json")
            if FileManager.default.fileExists(atPath: manifest.path) {
                let library = try JSONDecoder().decode(Library.self, from: Data(contentsOf: manifest))
                ships = library.ships.filter { FileManager.default.fileExists(atPath: self.shipURL($0).path) }
                levels = try library.levels.map { try $0.validated() }
            }
        } catch { loadError = "Your creations library could not load: \(error.localizedDescription)" }
    }

    func shipURL(_ ship: CustomShip) -> URL { directory.appendingPathComponent(ship.id.uuidString + ".usdz") }

    func importShip(from source: URL, handling: AircraftType) async throws -> CustomShip {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        guard source.pathExtension.lowercased() == "usdz" else {
            throw CustomContentError.invalid("Choose a USDZ ship model with its textures packed inside.")
        }
        let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 20 * 1024 * 1024 else {
            throw CustomContentError.invalid("Ship files must be under 20 MB. Reduce textures and mesh detail before exporting.")
        }
        // Copy to app storage while the document picker grant is still active.
        let ship = CustomShip(id: UUID(), name: String(source.deletingPathExtension().lastPathComponent.prefix(48)), handling: handling)
        let destination = shipURL(ship)
        try FileManager.default.copyItem(at: source, to: destination)
        do {
            let model = try await Entity(contentsOf: destination)
            let bounds = model.visualBounds(relativeTo: model)
            let values = [bounds.extents.x, bounds.extents.y, bounds.extents.z, bounds.center.x, bounds.center.y, bounds.center.z]
            guard values.allSatisfy(\.isFinite), max(bounds.extents.x, bounds.extents.y, bounds.extents.z) > 0.001 else {
                throw CustomContentError.invalid("This model has no usable visible geometry.")
            }
            var entities = 0
            func count(_ entity: Entity) { entities += 1; for child in entity.children { count(child) } }
            count(model)
            guard entities <= 1500 else { throw CustomContentError.invalid("Combine model parts in Blender; this ship has too many separate objects.") }
            try save(ships: ships + [ship], levels: levels)
            ships.append(ship)
            return ship
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    @discardableResult
    func addLevel(_ definition: CustomLevelDefinition) throws -> CustomLevelDefinition {
        var level = try definition.validated()
        level.id = UUID() // Imported recipes become independent library entries.
        try save(ships: ships, levels: levels + [level])
        levels.append(level)
        return level
    }

    func importLevel(from source: URL) throws -> CustomLevelDefinition {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size < 64 * 1024 else { throw CustomContentError.invalid("Choose a small terrain recipe JSON file, under 64 KB.") }
        return try addLevel(JSONDecoder().decode(CustomLevelDefinition.self, from: Data(contentsOf: source)))
    }

    private func save(ships: [CustomShip], levels: [CustomLevelDefinition]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(Library(ships: ships, levels: levels)).write(to: directory.appendingPathComponent("library.json"), options: .atomic)
    }
}
