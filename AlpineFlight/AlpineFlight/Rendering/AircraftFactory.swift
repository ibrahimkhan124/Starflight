import RealityKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
typealias UIColor = NSColor
#endif

@MainActor
enum AircraftFactory {
    static func blenderAssetURL(for type: AircraftType, bundle: Bundle = .main) -> URL? {
        bundle.url(
            forResource: "Ship_\(type.rawValue)",
            withExtension: "usdz",
            subdirectory: "Ships"
        )
    }

    static func make(type: AircraftType = .kestrel, color: UIColor, customURL: URL? = nil) -> Entity {
        if let url = customURL ?? blenderAssetURL(for: type),
           let blenderModel = try? Entity.load(contentsOf: url) {
            let aircraft = Entity()
            aircraft.name = type.name
            blenderModel.name = "Blender model"
            // USD identifiers replace spaces with underscores; restore the hook used by the effects renderer.
            blenderModel.findEntity(named: "podracer_energy_field")?.name = "podracer energy field"
            let bounds = blenderModel.visualBounds(relativeTo: blenderModel)
            let widthScale = type.wingspan / max(bounds.extents.x, 0.01)
            let lengthScale = type.length / max(bounds.extents.z, 0.01)
            if customURL != nil {
                // Fit inside the preset's collision envelope without stretching the artwork.
                let scale = min(widthScale, lengthScale, type.bodyRadius * 2 / max(bounds.extents.y, 0.01))
                blenderModel.scale = SIMD3<Float>(repeating: scale)
                blenderModel.position = -bounds.center * scale
            } else {
                blenderModel.scale = [widthScale, min(widthScale, lengthScale), lengthScale]
            }
            applyPaint(color, to: blenderModel)
            aircraft.addChild(blenderModel)
            return aircraft
        }
        if type != .kestrel { return AircraftModels.make(type: type, color: color) }
        let aircraft = Entity()
        aircraft.name = type.name
        let paint = SimpleMaterial(color: color, roughness: 0.35, isMetallic: true)
        let dark = SimpleMaterial(color: UIColor(red: 0.06, green: 0.13, blue: 0.16, alpha: 1), roughness: 0.24, isMetallic: true)
        let accent = SimpleMaterial(color: UIColor(red: 0.96, green: 0.44, blue: 0.23, alpha: 1), roughness: 0.45, isMetallic: false)
        func part(_ name: String, mesh: MeshResource, material: SimpleMaterial, at position: SIMD3<Float>, scale: SIMD3<Float> = [1, 1, 1]) -> ModelEntity {
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.name = name
            entity.position = position
            entity.scale = scale
            aircraft.addChild(entity)
            return entity
        }
        _ = part("snowspeeder armored hull", mesh: .generateSphere(radius: 1), material: paint, at: .zero, scale: [0.82, 0.72, 4.2])
        _ = part("snowspeeder cockpit", mesh: .generateSphere(radius: 1), material: dark, at: [0, 0.58, -0.7], scale: [0.7, 0.58, 1.45])
        _ = part("snowspeeder nose", mesh: .generateSphere(radius: 1), material: paint, at: [0, -0.06, -3.4], scale: [0.64, 0.62, 1.7])
        _ = part("snowspeeder rear stabilizer", mesh: .generateBox(size: [6.2, 0.2, 1.1], cornerRadius: 0.08), material: paint, at: [0, 0.12, 2.35])
        for side: Float in [-1, 1] {
            _ = part("snowspeeder forward wing", mesh: .generateBox(size: [5.8, 0.25, 1.4], cornerRadius: 0.08), material: paint, at: [side * 2.8, 0.05, -0.1])
            _ = part("snowspeeder laser cannon", mesh: .generateBox(size: [0.22, 0.22, 3.5]), material: accent, at: [side * 5.7, 0, -0.8])
            _ = part("snowspeeder repulsorlift", mesh: .generateSphere(radius: 1), material: dark, at: [side * 1.4, -0.55, 2.7], scale: [0.62, 0.5, 1.15])
            _ = part("snowspeeder engine glow", mesh: .generateSphere(radius: 1), material: accent, at: [side * 1.4, -0.55, 3.8], scale: [0.42, 0.35, 0.2])
        }
        return aircraft
    }

    private static func applyPaint(_ color: UIColor, to entity: Entity) {
        // Tint only squadron markings; preserve the authored hull, glass, vents and metallic finish.
        let paintNames = ["PaintStripe", "TailFin", "LeftStripe", "RightStripe"]
        if let model = entity as? ModelEntity,
           paintNames.contains(where: { model.name.hasPrefix($0) }) {
            model.model?.materials = [SimpleMaterial(color: color, roughness: 0.34, isMetallic: true)]
        }
        for child in entity.children { applyPaint(color, to: child) }
    }
}
