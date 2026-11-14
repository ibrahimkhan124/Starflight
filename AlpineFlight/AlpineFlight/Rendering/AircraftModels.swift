import RealityKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Procedural, dimensioned models. Local forward is -Z for every aircraft.
@MainActor
enum AircraftModels {
    static func make(type: AircraftType, color: UIColor) -> Entity {
        if type.blueprintRequirement > 0 { return BlueprintShipModels.make(type:type,color:color) }
        let root = Entity()
        root.name = type.name
        let sphere = MeshResource.generateSphere(radius: 1)
        let paint = SimpleMaterial(color: color, roughness: 0.4, isMetallic: true)
        let white = SimpleMaterial(color: UIColor(white: 0.87, alpha: 1), roughness: 0.4, isMetallic: true)
        let dark = SimpleMaterial(color: UIColor(red: 0.06, green: 0.1, blue: 0.14, alpha: 1), roughness: 0.25, isMetallic: true)
        let accent = SimpleMaterial(color: UIColor(red: 0.95, green: 0.52, blue: 0.21, alpha: 1), roughness: 0.45, isMetallic: false)
        let engineGlow = SimpleMaterial(color: .cyan, roughness: 0.15, isMetallic: false)

        @discardableResult
        func part(_ name: String, _ mesh: MeshResource, _ material: SimpleMaterial, _ position: SIMD3<Float>, _ scale: SIMD3<Float> = .one) -> ModelEntity {
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.name = name
            entity.position = position
            entity.scale = scale
            root.addChild(entity)
            return entity
        }

        func box(_ name: String, _ size: SIMD3<Float>, _ position: SIMD3<Float>, _ material: SimpleMaterial) {
            part(name, .generateBox(size: size, cornerRadius: min(size.x, min(size.y, size.z)) * 0.15), material, position)
        }

        func engine(at position: SIMD3<Float>, propeller: Bool) {
            part("engine nacelle", sphere, paint, position, [0.85, 0.85, 2.5])
            part("engine intake", sphere, dark, position + [0, 0, -2.15], [0.72, 0.72, 0.12])
            if propeller {
                let rotor = Entity()
                rotor.name = "rotor"
                rotor.position = position + [0, 0, -2.65]
                for angle: Float in [0, .pi / 2] {
                    let blade = ModelEntity(mesh: .generateBox(size: [3.9, 0.2, 0.1]), materials: [dark])
                    blade.orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
                    rotor.addChild(blade)
                }
                root.addChild(rotor)
                part("propeller spinner", sphere, white, position + [0, 0, -2.75], [0.3, 0.3, 0.5])
            } else {
                part("exhaust", sphere, dark, position + [0, 0, 2.25], [0.65, 0.65, 0.1])
            }
        }

        switch type {
        case .bWing, .imperialShuttle, .tieDefender, .tieInterceptor, .slaveI, .scimitar: return BlueprintShipModels.make(type:type,color:color)
        case .starDestroyer:
            // Compact, game-scale capital ship. Reuse meshes for the repeated surface details.
            let hull = SimpleMaterial(color: UIColor(white: 0.58, alpha: 1), roughness: 0.68, isMetallic: true)
            let upper = SimpleMaterial(color: UIColor(white: 0.76, alpha: 1), roughness: 0.62, isMetallic: true)
            let panel = SimpleMaterial(color: UIColor(white: 0.48, alpha: 1), roughness: 0.72, isMetallic: true)
            let trench = SimpleMaterial(color: UIColor(red: 0.13, green: 0.16, blue: 0.19, alpha: 1), roughness: 0.7, isMetallic: true)
            let unitBox = MeshResource.generateBox(size: 1)
            let engineCylinder = MeshResource.generateCylinder(height: 1, radius: 1)
            part("armoured wedge hull", destroyerHull(), hull, .zero)
            for side: Float in [-1, 1] {
                part("upper armour", wing(span: 18, rootFront: -23.5, rootBack: 23.5, tipFront: 21.5, tipBack: 23.5, side: side), upper, [0, 0.78, 0])
                // A continuous dark trench follows the sloping edge from bow to stern.
                let edge = part("side trench", unitBox, trench, [side * 9.5, 0.12, 0], [0.58, 0.65, 53.5])
                edge.orientation = simd_quatf(angle: side * 0.363, axis: [0, 1, 0])
                for (i, z): (Int, Float) in [-11, -4, 3, 10, 17].enumerated() {
                    let width = (z + 25) * 0.37
                    let x = max(1.4, width * 0.58)
                    part("armour panel", unitBox, i.isMultiple(of: 2) ? hull : panel, [side * x, 0.94, z], [max(0.5, width * 0.36), 0.08, 2.6])
                    if i >= 2 {
                        part("turbolaser base", unitBox, hull, [side * (width * 0.75), 1.12, z], [1.35, 0.48, 1.5])
                        part("turbolaser turret", unitBox, panel, [side * (width * 0.75), 1.45, z - 0.12], [0.9, 0.35, 0.9])
                        part("turbolaser barrels", unitBox, trench, [side * (width * 0.75), 1.47, z - 1.1], [0.36, 0.14, 1.65])
                    }
                }
                for z: Float in [3, 7, 11, 15, 19, 22] {
                    let width = (z + 25) * 0.38
                    part("trench machinery", unitBox, hull, [side * (width - 0.35), 0.12, z], [0.45, 0.3, 0.75])
                }
            }
            // Layered decks and a recognisable command tower with paired sensor globes.
            box("lower command deck", [12, 0.9, 18], [0, 1.32, 12], hull)
            box("middle command deck", [9.3, 0.8, 13], [0, 2.12, 14], upper)
            box("upper command deck", [6.8, 0.7, 8], [0, 2.85, 16.5], hull)
            box("bridge pedestal", [4.5, 2.3, 3.3], [0, 4.25, 18.3], hull)
            box("bridge wing", [10, 1.15, 2.7], [0, 5.85, 18.3], upper)
            box("bridge window band", [7.2, 0.26, 0.09], [0, 5.92, 16.9], trench)
            box("bridge upper deck", [5.4, 0.32, 1.7], [0, 6.55, 18.3], hull)
            for side: Float in [-1, 1] {
                part("sensor pedestal", unitBox, panel, [side * 3.25, 6.55, 18.2], [0.7, 0.55, 0.7])
                part("sensor globe", sphere, upper, [side * 3.25, 7.25, 18.2], [0.85, 0.85, 0.85])
                for z: Float in [7, 10, 13, 16, 19] {
                    part("deck vent", unitBox, panel, [side * 4, 2.55, z], [0.7, 0.13, 1.4])
                }
            }
            // Three primary engines and four smaller auxiliary drives at the stern.
            for (x, radius): (Float, Float) in [(-6, 2.1), (0, 2.4), (6, 2.1), (-11, 0.8), (-3, 0.8), (3, 0.8), (11, 0.8)] {
                let nozzle = part("engine housing", engineCylinder, trench, [x, -0.1, 24.9], [radius, 1.2, radius])
                nozzle.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                let rim = part("engine rim", engineCylinder, hull, [x, -0.1, 25.5], [radius * 1.04, 0.18, radius * 1.04])
                rim.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                part("engine glow", sphere, engineGlow, [x, -0.1, 25.64], [radius * 0.82, radius * 0.82, 0.12])
            }
        case .falcon:
            part("ARC-170 armored fuselage", sphere, paint, .zero, [1.05, 0.9, 8])
            part("ARC-170 nose", sphere, white, [0, 0, -6.2], [0.75, 0.65, 2.7])
            part("ARC-170 canopy", sphere, dark, [0, 0.76, -2.5], [0.82, 0.6, 1.9])
            for side: Float in [-1, 1] {
                part("ARC-170 broad wing", wing(span: 7, rootFront: -2.6, rootBack: 4.8, tipFront: 1.7, tipBack: 5.4, side: side), paint, .zero)
                engine(at: [side * 5.5, -0.35, 3.5], propeller: false)
                box("ARC-170 laser cannon", [0.24, 0.24, 4.5], [side * 6.8, -0.1, -2.3], accent)
            }
            part("ARC-170 dorsal turret", sphere, dark, [0, 1.5, 1.2], [1, 0.45, 1.4])
            part("ARC-170 rear engine", sphere, engineGlow, [0, 0, 7.5], [0.72, 0.72, 0.35])
        case .starkJet:
            let resistanceBlue = SimpleMaterial(color: UIColor(red: 0.16, green: 0.42, blue: 0.82, alpha: 1), roughness: 0.4, isMetallic: true)
            part("T-70 fuselage", sphere, paint, .zero, [0.78, 0.74, 7])
            part("T-70 reinforced nose", sphere, white, [0, 0, -5.8], [0.54, 0.5, 2.5])
            part("T-70 cockpit", sphere, dark, [0, 0.68, -2.5], [0.65, 0.52, 1.8])
            for side: Float in [-1, 1] {
                for upper: Float in [-1, 1] {
                    let foil = part("T-70 split S-foil", .generateBox(size: [5.7, 0.22, 4.5]), resistanceBlue, [side * 3.05, upper * 0.6, 0.2])
                    foil.orientation = simd_quatf(angle: upper * side * 0.1, axis: [0, 0, 1])
                    box("T-70 laser cannon", [0.2, 0.2, 5.2], [side * 5.7, upper * 0.7, -1.2], accent)
                    part("T-70 engine glow", sphere, engineGlow, [side * 2.15, upper * 0.68, 3], [0.42, 0.42, 0.28])
                }
                box("T-70 wing stripe", [0.65, 0.23, 2.8], [side * 3.2, 0.83, 1], white)
            }
            box("T-70 dorsal ridge", [0.32, 1, 3.2], [0, 0.3, 3.4], resistanceBlue)
        case .atlas:
            let body = part("LAAT gunship fuselage", .generateCylinder(height: 17, radius: 1.85), paint, [0, 0, -1])
            body.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            part("gunship nose", sphere, paint, [0, 0, -9.2], [1.85, 1.85, 4])
            part("gunship cockpit", sphere, dark, [0, 1.1, -10], [1.55, 0.65, 1.9])
            box("gunship wing", [26, 0.35, 4], [0, 1.35, -0.5], paint)
            for side: Float in [-1, 1] {
                let pod = part("gunship engine pod", sphere, paint, [side * 13, 1.35, -0.3], [1.5, 1.3, 3])
                pod.orientation = simd_quatf(angle: side * -0.22, axis: [0, 0, 1])
                part("gunship repulsorlift", sphere, engineGlow, [side * 13, 1.35, 2.1], [1.1, 0.9, 0.35])
                box("wing laser cannon", [0.35, 0.35, 4], [side * 13, -0.25, -2.7], dark)
                box("assault door", [0.15, 2.1, 8], [side * 1.88, 0, 1.2], dark)
            }
            part("gunship tail", sphere, paint, [0, 0.3, 8], [1.75, 1.65, 5])
            box("gunship tailplane", [11, 0.25, 3.4], [0, 2.2, 10.5], paint)
            box("gunship vertical tail", [0.3, 4.7, 4], [0, 2.5, 9.6], paint)
            for side: Float in [-1, 1] {
                part("gear fairing", sphere, paint, [side * 1.5, -1.3, 2.2], [0.8, 0.8, 3.3])
                box("Republic gunship marking", [1.2, 0.35, 4.1], [side * 12.5, 1.9, -0.5], white)
            }
        case .xwing:
            part("X-wing fuselage", sphere, white, .zero, [0.72, 0.72, 6.5])
            part("X-wing nose", sphere, white, [0, 0, -5.7], [0.5, 0.5, 2.2])
            part("X-wing canopy", sphere, dark, [0, 0.65, -1.6], [0.62, 0.5, 1.65])
            for side: Float in [-1, 1] {
                for upper: Float in [-1, 1] {
                    let y = upper * 0.68
                    let wingPart = part("S-foil", .generateBox(size: [5.4, 0.2, 4.5], cornerRadius: 0.05), white, [side * 3.05, y, 0.5])
                    wingPart.orientation = simd_quatf(angle: upper * side * 0.12, axis: [0, 0, 1])
                    part("laser cannon", .generateCylinder(height: 5.4, radius: 0.09), accent, [side * 5.7, y, -1.7]).orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                    part("engine glow", sphere, engineGlow, [side * 2.1, y, 3.1], [0.38, 0.38, 0.25])
                }
            }
            box("rebel stripe", [0.9, 0.76, 3.4], [0, 0, 0.4], accent)
        case .tieFighter:
            part("TIE cockpit", sphere, dark, .zero, [2.25, 2.25, 2.25])
            part("TIE viewport", sphere, SimpleMaterial(color: .black, roughness: 0.2, isMetallic: true), [0, 0, -1.85], [1.28, 1.28, 0.35])
            for side: Float in [-1, 1] {
                box("wing pylon", [2.4, 0.28, 0.28], [side * 2.8, 0, 0], white)
                let panel = part("hexagonal solar wing", .generateCylinder(height: 0.25, radius: 3.35), dark, [side * 4.05, 0, 0])
                panel.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
                for y: Float in [-2.25, 0, 2.25] { box("solar panel brace", [0.32, 0.18, 6.2], [side * 4.2, y, 0], white) }
            }
            for x: Float in [-0.65, 0.65] { part("ion engine", sphere, engineGlow, [x, 0, 2.05], [0.28, 0.28, 0.2]) }
        case .millenniumFalcon:
            let saucer = part("Falcon saucer", .generateCylinder(height: 1.8, radius: 12), white, [0, 0, 1])
            saucer.name = "Falcon saucer"
            part("Falcon upper hull", sphere, white, [0, 1.2, 1.2], [6.8, 1.4, 6.8])
            for side: Float in [-1, 1] {
                box("forward mandible", [4.1, 1.5, 17.2], [side * 4.7, 0, -8], white)
                box("mandible recess", [2.2, 0.35, 8], [side * 4.7, 0.82, -8.4], dark)
            }
            let cockpitTube = part("offset cockpit tunnel", .generateCylinder(height: 8.5, radius: 0.9), white, [9.4, 0.2, -3.7])
            cockpitTube.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            part("offset cockpit", sphere, dark, [9.4, 0.2, -8.1], [1.25, 1.05, 1.7])
            box("sensor dish", [0.18, 3.4, 3.4], [-2.7, 2.6, 1], white)
            box("blue drive glow", [12.5, 0.55, 0.22], [0, 0, 11.35], SimpleMaterial(color: .cyan, roughness: 0.2, isMetallic: false))
            for x: Float in [-6, 0, 6] { box("hull panel", [2.7, 0.12, 2.1], [x, 1.95, 2.3], dark) }
        case .aWing:
            part("A-wing cockpit pod", sphere, white, [0, 0, -0.5], [1.1, 0.7, 4.6])
            part("A-wing canopy", sphere, dark, [0, 0.62, -1.3], [0.77, 0.42, 1.7])
            for side: Float in [-1, 1] {
                part("A-wing wedge", wing(span: 4.5, rootFront: -4.5, rootBack: 4.2, tipFront: 1.2, tipBack: 3.9, side: side), paint, .zero)
                part("A-wing engine", sphere, white, [side * 2.1, -0.2, 2.15], [0.55, 0.55, 2.7])
                part("A-wing exhaust", sphere, engineGlow, [side * 2.1, -0.2, 4.75], [0.45, 0.45, 0.22])
            }
        case .yWing:
            part("Y-wing forward cabin", sphere, white, [0, 0, -4.3], [1.65, 0.9, 3.7])
            part("Y-wing canopy", sphere, dark, [0, 0.72, -4.9], [0.92, 0.45, 1.45])
            box("Y-wing central spine", [1.6, 0.7, 10], [0, 0, 1.5], white)
            for side: Float in [-1, 1] {
                box("Y-wing pylon", [4.4, 0.25, 2], [side * 3, 0, -1.5], white)
                part("Y-wing engine", sphere, paint, [side * 5.2, 0, 1.2], [0.75, 0.75, 6.7])
                part("Y-wing engine glow", sphere, engineGlow, [side * 5.2, 0, 7.8], [0.58, 0.58, 0.28])
            }
        case .n1Starfighter:
            let gold = SimpleMaterial(color: UIColor(red: 0.96, green: 0.75, blue: 0.25, alpha: 1), roughness: 0.24, isMetallic: true)
            part("N-1 pointed fuselage", sphere, gold, [0, 0, -1], [0.84, 0.65, 5.8])
            part("N-1 canopy", sphere, dark, [0, 0.55, -1.6], [0.7, 0.38, 1.6])
            for side: Float in [-1, 1] {
                part("N-1 swept wing", wing(span: 5.8, rootFront: -3.1, rootBack: 2, tipFront: -1.4, tipBack: 0.8, side: side), gold, .zero)
                part("N-1 engine pod", sphere, white, [side * 5.2, -0.08, -1.1], [0.5, 0.5, 6.3])
                part("N-1 exhaust", sphere, engineGlow, [side * 5.2, -0.08, 5], [0.42, 0.42, 0.3])
            }
        case .enterprise:
            let federation = SimpleMaterial(color: UIColor(red: 0.77, green: 0.81, blue: 0.85, alpha: 1), roughness: 0.34, isMetallic: true)
            part("Enterprise saucer", sphere, federation, [0, 1.5, -11.5], [19.2, 1.35, 13.7])
            part("Enterprise bridge", sphere, white, [0, 2.95, -11.5], [2.1, 0.85, 2])
            part("Enterprise secondary hull", sphere, federation, [0, -2, 9], [4.2, 2.6, 14])
            box("Enterprise neck", [1.5, 4, 12], [0, -0.1, -0.8], federation)
            for side: Float in [-1, 1] {
                box("Enterprise nacelle pylon", [12, 0.45, 1.5], [side * 9.5, -1.5, 8], federation)
                part("Enterprise warp nacelle", sphere, federation, [side * 15, -1.2, 10], [1.3, 1.2, 12.3])
                part("Enterprise blue bussard", sphere, engineGlow, [side * 15, -1.2, -1.4], [1.1, 1.05, 0.35])
            }
        case .voyager:
            let federation = SimpleMaterial(color: UIColor(red: 0.8, green: 0.83, blue: 0.86, alpha: 1), roughness: 0.36, isMetallic: true)
            part("Voyager saucer", sphere, federation, [0, 0, -10], [11.8, 1.3, 10.8])
            part("Voyager hull", sphere, federation, [0, -0.9, 5], [5.6, 2.1, 13.6])
            part("Voyager bridge", sphere, dark, [0, 1.3, -10], [2.3, 0.32, 2])
            for side: Float in [-1, 1] {
                part("Voyager swept pylon", wing(span: 16, rootFront: 1, rootBack: 9, tipFront: 7, tipBack: 12, side: side), federation, [0, -1.7, 0])
                part("Voyager warp nacelle", sphere, federation, [side * 15.5, -0.7, 8], [1.2, 0.9, 11])
                part("Voyager engine glow", sphere, engineGlow, [side * 15.5, -0.7, -2.3], [0.92, 0.66, 0.35])
            }
        case .birdOfPrey:
            let green = SimpleMaterial(color: UIColor(red: 0.2, green: 0.35, blue: 0.22, alpha: 1), roughness: 0.5, isMetallic: true)
            part("Bird-of-Prey command hull", sphere, green, [0, 0.2, -3], [3.5, 1.6, 8])
            part("Bird-of-Prey bridge", sphere, dark, [0, 0.7, -10.6], [1.1, 0.8, 1.4])
            for side: Float in [-1, 1] {
                let wingPart = part("Bird-of-Prey swept wing", wing(span: 13.8, rootFront: -4, rootBack: 7, tipFront: 2, tipBack: 9, side: side), green, .zero)
                wingPart.orientation = simd_quatf(angle: side * -0.16, axis: [0, 0, 1])
                box("Bird-of-Prey wing cannon", [0.42, 0.42, 3.3], [side * 13.5, -1.9, 3], dark)
                part("Bird-of-Prey engine", sphere, engineGlow, [side * 2.5, 0, 8.7], [0.65, 0.38, 0.32])
            }
        case .novaSkiff:
            let gold = SimpleMaterial(color: UIColor(red: 0.96, green: 0.75, blue: 0.25, alpha: 1), roughness: 0.24, isMetallic: true)
            part("Jedi interceptor fuselage", sphere, white, [0, 0, -1], [0.62, 0.58, 4.8])
            part("Jedi interceptor canopy", sphere, dark, [0, 0.48, -1.1], [0.58, 0.38, 1.25])
            for side: Float in [-1, 1] {
                _ = part("Jedi interceptor solar wing", wing(span: 4, rootFront: -2.6, rootBack: 2.8, tipFront: -0.6, tipBack: 2.5, side: side), gold, .zero)
                part("Jedi interceptor engine", sphere, white, [side * 3.6, 0, 1.8], [0.45, 0.45, 2.7])
                part("Jedi interceptor engine glow", sphere, engineGlow, [side * 3.6, 0, 4.4], [0.36, 0.36, 0.25])
                box("Jedi interceptor laser", [0.16, 0.16, 3.8], [side * 3.4, -0.2, -2.2], accent)
            }
        case .anakinPodracer, .sebulbaPodracer, .quadinPodracer, .rattsPodracer, .nevaKeePodracer, .voltwingPodracer:
            let isSebulba = type == .sebulbaPodracer
            let isQuad = type == .quadinPodracer
            let isRatts = type == .rattsPodracer
            let isNevaKee = type == .nevaKeePodracer
            let isVoltwing = type == .voltwingPodracer
            let podPaint = isSebulba
                ? SimpleMaterial(color: UIColor(red: 0.62, green: 0.18, blue: 0.12, alpha: 1), roughness: 0.36, isMetallic: true)
                : isQuad ? SimpleMaterial(color: UIColor(red: 0.26, green: 0.64, blue: 0.54, alpha: 1), roughness: 0.38, isMetallic: true)
                : isRatts ? SimpleMaterial(color: UIColor(red: 0.92, green: 0.69, blue: 0.2, alpha: 1), roughness: 0.32, isMetallic: true)
                : isNevaKee ? SimpleMaterial(color: UIColor(red: 0.31, green: 0.46, blue: 0.69, alpha: 1), roughness: 0.4, isMetallic: true)
                : isVoltwing ? SimpleMaterial(color: UIColor(red: 0.04, green: 0.2, blue: 0.48, alpha: 1), roughness: 0.23, isMetallic: true) : paint
            let hotGlow = SimpleMaterial(color: UIColor(red: 0.25, green: 0.68, blue: 1, alpha: 1), roughness: 0.16, isMetallic: false)
            let energyGlow = UnlitMaterial(color: UIColor(red: 0.35, green: 0.82, blue: 1, alpha: 0.96))
            let engineX: Float = isSebulba ? 16 : isNevaKee ? 20 : isRatts ? 11 : isVoltwing ? 11.5 : 14
            let energyField = Entity()
            energyField.name = "podracer energy field"
            let arcPoints: [SIMD3<Float>] = stride(from: -1, through: 1, by: 0.25).enumerated().map { index, fraction in
                [Float(fraction) * engineX, index.isMultiple(of: 2) ? 0.6 : -0.35, -4.7 + Float(index % 3) * 0.22]
            }
            for (index, pair) in zip(arcPoints, arcPoints.dropFirst()).enumerated() {
                let delta = pair.1 - pair.0
                let segment = ModelEntity(mesh: .generateBox(size: [simd_length(delta), index.isMultiple(of: 3) ? 0.3 : 0.2, 0.22]), materials: [energyGlow])
                segment.name = "energy bolt \(index)"
                segment.position = (pair.0 + pair.1) * 0.5
                segment.orientation = simd_quatf(from: SIMD3<Float>(1, 0, 0), to: simd_normalize(delta))
                energyField.addChild(segment)
            }
            root.addChild(energyField)
            let cockpit = part("podracer cockpit", sphere, podPaint, [0, 0, 2.5], isSebulba || isNevaKee ? [1.45, 0.82, 2.5] : [isRatts ? 0.82 : 1.05, 0.7, 2.1])
            _ = cockpit
            part("podracer canopy", sphere, dark, [0, 0.63, 1.9], [0.8, 0.42, 1.2])
            box("podracer nose", [1.05, 0.48, 2.1], [0, -0.05, 0.8], podPaint)
            for side: Float in [-1, 1] {
                let x = side * engineX
                let z: Float = isQuad ? (side < 0 ? -1 : -5) : -4.5
                box("podracer steering spar", [abs(x) * 0.92, 0.25, 0.35], [x * 0.48, 0.22, -0.1], dark)
                let nacellePosition: SIMD3<Float> = [x, 0.35, z]
                let nacelleScale: SIMD3<Float> = [isSebulba || isNevaKee ? 2.3 : isRatts ? 1.3 : 1.75, isSebulba || isNevaKee ? 1.9 : isRatts ? 1.2 : 1.5, isQuad ? 5.2 : 6.2]
                let nacelle = part("podracer turbine", sphere, isSebulba ? dark : white, nacellePosition, nacelleScale)
                nacelle.orientation = simd_quatf(angle: side * 0.08, axis: [0, 1, 0])
                let intakePosition: SIMD3<Float> = [x, 0.35, z - (isQuad ? 4.8 : 5.8)]
                part("podracer intake ring", .generateCylinder(height: 0.3, radius: isSebulba || isNevaKee ? 1.95 : isRatts ? 1.12 : 1.48), accent, intakePosition)
                    .orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                let corePosition: SIMD3<Float> = [x, 0.35, z + (isQuad ? 5.1 : 6.05)]
                part("podracer energy core", sphere, hotGlow, corePosition, [1.05, 1.05, 0.36])
                for rib: Float in [-0.7, 0.7] {
                    let support = part("podracer engine support", .generateBox(size: [0.18, 0.18, 11]), dark, [x * 0.82, 0.08, 1.4 + rib * 0.2])
                    support.orientation = simd_quatf(angle: side * 0.12, axis: [0, 1, 0])
                }
            }
            if isQuad {
                for side: Float in [-1, 1] {
                    let x = side * 18
                    let pod = part("Quadinaros outer turbine", sphere, white, [x, 0.05, 3], [1.35, 1.2, 4.4])
                    pod.orientation = simd_quatf(angle: side * -0.06, axis: [0, 1, 0])
                    part("Quadinaros outer engine glow", sphere, hotGlow, [x, 0.05, 7.2], [0.9, 0.9, 0.3])
                    box("Quadinaros outer spar", [2.6, 0.2, 0.25], [side * 16, 0.14, 0.4], dark)
                }
            }
            box("podracer tail fin", [0.22, 1.15, 1.5], [0, 1, 4.1], podPaint)
        case .meridian:
            // Rebel U-wing assault transport with folding wings and troop-bay lights.
            part("U-wing central fuselage", sphere, paint, [0, 0, 0], [1.8, 1.25, 8.2])
            part("U-wing nose", sphere, white, [0, 0, -6.5], [1.45, 1, 2.8])
            part("U-wing cockpit glazing", sphere, dark, [0, 1.05, -5.3], [1.15, 0.55, 1.5])
            box("U-wing troop bay", [2.3, 1.7, 7.1], [0, -0.2, 2.2], dark)
            for side: Float in [-1, 1] {
                let wingPart = part("U-wing swept wing", AircraftModels.wing(span: 11, rootFront: -3, rootBack: 7, tipFront: 1.5, tipBack: 9, side: side), paint, [0, 0.4, 0])
                wingPart.orientation = simd_quatf(angle: side * 0.16, axis: [0, 1, 0])
                engine(at: [side * 8.7, 0.8, 3], propeller: false)
                box("U-wing laser cannon", [0.28, 0.28, 4.6], [side * 2.4, 0.2, -5.2], accent)
            }
        case .razorCrest:
            part("Razor Crest armored hull", sphere, white, [0, 0, 0], [3, 2.4, 11])
            part("Razor Crest cockpit", sphere, dark, [0, 2, -7], [2, 1, 3])
            for side: Float in [-1, 1] {
                box("Razor Crest pylon", [8, 0.7, 4], [side * 5, 1, 0], white)
                part("Razor Crest turbine", sphere, white, [side * 10, 1.5, 0], [2, 2, 7])
                part("Razor Crest engine glow", sphere, engineGlow, [side * 10, 1.5, 7], [1.5, 1.5, 0.3])
                box("Razor Crest cannon", [0.3, 0.3, 6], [side * 3, 0, -8], dark)
            }
        case .kestrel:
            break
        }
        return root
    }

    /// A closed triangular prism, so the ship remains solid from above and below.
    private static func destroyerHull() -> MeshResource {
        var mesh = MeshDescriptor(name: "capital ship hull")
        mesh.positions = MeshBuffers.Positions([
            [0, 0.7, -25], [-19, 0.7, 25], [19, 0.7, 25],
            [0, -0.7, -25], [-19, -0.7, 25], [19, -0.7, 25]
        ])
        mesh.primitives = .triangles([0, 1, 2, 3, 5, 4, 0, 3, 4, 0, 4, 1,
                                      1, 4, 5, 1, 5, 2, 2, 5, 3, 2, 3, 0])
        return (try? MeshResource.generate(from: [mesh])) ?? .generateBox(size: [38, 1.4, 50])
    }

    private static func wing(span: Float, rootFront: Float, rootBack: Float, tipFront: Float, tipBack: Float, side: Float) -> MeshResource {
        let outline: [SIMD3<Float>] = [[0, 0, rootFront], [span * side, 0, tipFront], [span * side, 0, tipBack], [0, 0, rootBack]]
        let positions = outline.map { $0 + [0, 0.12, 0] } + outline.map { $0 - [0, 0.12, 0] }
        var descriptor = MeshDescriptor(name: "swept airfoil")
        descriptor.positions = MeshBuffers.Positions(positions)
        var indices: [UInt32] = [0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7, 0, 1, 5, 0, 5, 4,
                                 1, 2, 6, 1, 6, 5, 2, 3, 7, 2, 7, 6, 3, 0, 4, 3, 4, 7]
        if side < 0 {
            for i in stride(from: 0, to: indices.count, by: 3) { indices.swapAt(i + 1, i + 2) }
        }
        descriptor.primitives = .triangles(indices)
        return (try? MeshResource.generate(from: [descriptor])) ?? .generateBox(size: [span, 0.24, 2])
    }
}
