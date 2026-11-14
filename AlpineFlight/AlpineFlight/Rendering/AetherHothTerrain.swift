import Foundation
import simd
import ProceduralCore
import ProceduralTerrain

/// Shared home-world pilots retain each original height recipe and diagonal.
/// Reflecting X adapts Aether's opposite cell diagonal without changing contact.
enum AetherHomeTerrain {
    static func enabled(for planet:SpacePlanet) -> Bool {
        switch planet {
        case .hoth:return AetherPlanet.flag("aetherHothTerrainEnabled")
        case .tatooine:return AetherPlanet.flag("aetherTatooineTerrainEnabled")
        case .endor:return AetherPlanet.flag("aetherEndorTerrainEnabled")
        case .coruscant:return false
        }
    }
    struct Field:HeightField {
        let planet:SpacePlanet
        func height(at p:SIMD2<Float>) -> Float { PlanetExploration(planet:planet).vertexHeight(x:-p.x,z:p.y) }
    }
    struct Tile:Sendable {
        let x:Int, z:Int
        // Keep one upload payload rather than retaining duplicate top/skirt arrays.
        let renderMesh:MeshData
    }
    struct Prepared:Sendable {
        let grid:TerrainGrid
        let tiles:[Tile]
        func height(x:Float,z:Float) -> Float? { grid.sample(at:[-x,z])?.position.y }
    }
    private static let hoth:Result<Prepared,Error> = Result { try build(planet:.hoth) }
    private static let tatooine:Result<Prepared,Error> = Result { try build(planet:.tatooine) }
    private static let endor:Result<Prepared,Error> = Result { try build(planet:.endor) }
    static func prepared(for planet:SpacePlanet) -> Result<Prepared,Error> {
        switch planet {
        case .hoth:return hoth
        case .tatooine:return tatooine
        case .endor:return endor
        case .coruscant:return .failure(SurfaceError.invalidParameter("Coruscant keeps its city terrain"))
        }
    }
    static func build(planet:SpacePlanet) throws -> Prepared {
        let extent = PlanetExploration.extent, n = PlanetExploration.grid, side = 40
        let grid = try TerrainGrid.build(field:Field(planet:planet),request:TerrainGridRequest(
            bounds:WorldBounds(minimum:[-extent,-extent],maximum:[extent,extent]),cellsX:n,cellsZ:n))
        let row = n+1
        var tiles:[Tile] = []
        for tz in 0..<4 { for tx in 0..<4 {
            try Task.checkCancellation()
            var positions:[SIMD3<Float>] = [],normals:[SIMD3<Float>] = [],indices:[UInt32] = []
            for z in 0...side { for x in 0...side {
                let i = (tz*side+z)*row+tx*side+x
                let p = grid.mesh.positions[i], normal = grid.mesh.normals[i]
                positions.append([-p.x,p.y,p.z]);normals.append([-normal.x,normal.y,normal.z])
            } }
            for z in 0..<side { for x in 0..<side {
                let a = UInt32(z*(side+1)+x), b = a+UInt32(side+1)
                // Reverse winding after reflecting X; the visible face stays up.
                indices += [a,a+1,b,a+1,b+1,b]
            } }
            var sp:[SIMD3<Float>] = [],sn:[SIMD3<Float>] = [],si:[UInt32] = []
            let edges = [(0...side).map { $0 },(0...side).map { $0*(side+1)+side },(0...side).reversed().map { side*(side+1)+$0 },(0...side).reversed().map { $0*(side+1) }]
            for edge in edges { for pair in zip(edge,edge.dropFirst()) {
                let a = positions[pair.0], b = positions[pair.1], c = b-[0,140,0], d = a-[0,140,0]
                let base = UInt32(sp.count), normal = -simd_normalize(simd_cross(b-a,c-a))
                sp += [a,b,c,d];sn += Array(repeating:normal,count:4)
                si += [base,base+2,base+1,base,base+3,base+2]
            } }
            let offset = UInt32(positions.count)
            tiles.append(Tile(x:tx,z:tz,renderMesh:try MeshData(positions:positions+sp,normals:normals+sn,indices:indices+si.map { $0+offset })))
        } }
        return Prepared(grid:grid,tiles:tiles)
    }
}

/// Compatibility facade for the stage-two pilot and its regression fixtures.
enum AetherHothTerrain {
    typealias Prepared = AetherHomeTerrain.Prepared
    static var enabled:Bool { AetherHomeTerrain.enabled(for:.hoth) }
    static var prepared:Result<Prepared,Error> { AetherHomeTerrain.prepared(for:.hoth) }
    static func build() throws -> Prepared { try AetherHomeTerrain.build(planet:.hoth) }
}
