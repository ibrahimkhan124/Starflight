import Foundation
import simd
import ProceduralCore
import ProceduralTerrain

/// Stage-two pilot: retain Hoth's authored height recipe and diagonal exactly.
/// Reflecting X adapts Aether's opposite cell diagonal without changing contact.
enum AetherHothTerrain {
    static var enabled:Bool { AetherPlanet.flag("aetherHothTerrainEnabled") }
    struct Field:HeightField {
        func height(at p:SIMD2<Float>) -> Float { PlanetExploration(planet:.hoth).vertexHeight(x:-p.x,z:p.y) }
    }
    struct Tile:Sendable {
        let x:Int, z:Int
        let mesh:MeshData
        let skirt:MeshData
        let renderMesh:MeshData
    }
    struct Prepared:Sendable {
        let grid:TerrainGrid
        let tiles:[Tile]
        func height(x:Float,z:Float) -> Float? { grid.sample(at:[-x,z])?.position.y }
    }
    static let prepared:Result<Prepared,Error> = Result { try build() }
    static func build() throws -> Prepared {
        let extent = PlanetExploration.extent, n = PlanetExploration.grid, side = 40
        let grid = try TerrainGrid.build(field:Field(),request:TerrainGridRequest(
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
            tiles.append(Tile(x:tx,z:tz,mesh:try MeshData(positions:positions,normals:normals,indices:indices),
                skirt:try MeshData(positions:sp,normals:sn,indices:si),
                renderMesh:try MeshData(positions:positions+sp,normals:normals+sn,indices:indices+si.map { $0+offset })))
        } }
        return Prepared(grid:grid,tiles:tiles)
    }
}
