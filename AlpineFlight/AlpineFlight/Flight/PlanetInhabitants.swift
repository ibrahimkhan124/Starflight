import simd

/// Decorative residents have no combat or collision behaviour.
enum PlanetInhabitant: String {
    case ewok, jawa, wampa
    var label: String { rawValue.capitalized + "s" }
    static func resident(on planet:SpacePlanet) -> Self? {
        switch planet { case .endor:return .ewok; case .tatooine:return .jawa; case .hoth:return .wampa; case .coruscant:return nil }
    }
    static func sites(on planet:SpacePlanet,reduced:Bool) -> [SIMD3<Float>] {
        guard resident(on:planet) != nil else { return [] }
        let surface = PlanetExploration(planet:planet)
        let anchors = [surface.arrival]+surface.landmarks.map(\.position)
        return anchors.prefix(reduced ? 3:7).compactMap { anchor in
            for offset:SIMD2<Float> in [[110,-130],[-110,-130],[160,90],[-160,90],[0,180]] {
                let x = anchor.x+offset.x, z = anchor.z+offset.y
                let ground = surface.groundHeight(x:x,z:z)
                let point = SIMD3<Float>(x,ground+10,z)
                if !surface.hitsObstacle(at:point,radius:20) { return SIMD3<Float>(x,ground,z) }
            }
            return nil
        }
    }
}
