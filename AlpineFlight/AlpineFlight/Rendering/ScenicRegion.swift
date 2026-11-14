import Foundation
import RealityKit
import UIKit

/// Fixed scenery is prepared with the terrain. The same solids are used for collision.
struct ScenicRegion: Sendable {
    enum Finish: Int, CaseIterable, Sendable { case rock, metal, dark, canopy, ice, amber, cyan }
    struct Solid: Sendable {
        var center: SIMD3<Float>
        var size: SIMD3<Float>
        var topScale: Float = 1
        var finish: Finish
        var collidable = true

        func contains(_ point: SIMD3<Float>, margin: Float = 1) -> Bool {
            let p = point - center, half = size / 2
            guard abs(p.y) <= half.y + margin else { return false }
            let fraction = clamp((p.y + half.y) / size.y, 0, 1)
            let scale = 1 + (topScale - 1) * fraction
            return abs(p.x) <= half.x * scale + margin && abs(p.z) <= half.z * scale + margin
        }
    }
    var solids: [Solid] = []
    private var bins: [SIMD2<Int>: [Int]] = [:]
    private static let binSize: Float = 400

    init(terrain: TerrainGenerator) {
        let level = terrain.level
        let portals = level.isFreeRoam ? HyperspaceManager(terrain:terrain).portals : []
        var candidates: [(Float, Float, Int)] = []
        if level.isFreeRoam {
            for i in -9...9 {
                for j in -9...9 {
                    let v = Self.random(i, j, seed: terrain.seed)
                    candidates.append((Float(i) * 480 + v * 180, Float(j) * 480 + (1-v) * 160, i * 31 + j))
                }
            }
        } else if level.isPodRace {
            let circuit = RaceCircuit(level: level)
            for i in 0..<Int(circuit.length / 210) {
                let distance = Float(i) * 210
                let p = circuit.point(at: distance), tangent = circuit.tangent(at: distance)
                let normal = SIMD3<Float>(-tangent.z, 0, tangent.x)
                for side: Float in [-1, 1] {
                    let q = p + normal * side * (level.valleyWidth * 0.7 + 150 + Float(i % 4) * 45)
                    // The returning lane can lie beside this one; keep both racing lines clear.
                    if circuit.projection(q).offset > level.valleyWidth * 0.62 + 90 {
                        candidates.append((q.x, q.z, i + (side < 0 ? 19 : 0)))
                    }
                }
            }
        } else {
            for i in 0..<Int((level.routeLength + 900) / 260) {
                let z = 600 - Float(i) * 260
                for side: Float in [-1, 1] {
                    let offset = level == .deathStar ? Float(340 + i % 3 * 70) : level.valleyWidth * 0.88 + Float(150 + i % 4 * 65)
                    candidates.append((terrain.valleyCenter(at: z) + offset * side, z, i))
                }
            }
        }
        for (x, z, index) in candidates {
            guard abs(x) < (level.isFreeRoam ? 4600 : 1710) else { continue }
            if level.isFreeRoam {
                // Existing portal arrivals and legacy clearings remain completely unobstructed.
                if abs(x) < 420 && abs(z) < 650 { continue }
                if FreeRoamActivities.pads.contains(where: { abs(x-$0.x) < 600 && abs(z-$0.z) < 1900 }) { continue }
                if portals.contains(where: { simd_distance(SIMD2<Float>(x,z), SIMD2<Float>($0.position.x,$0.position.z)) < 360 }) { continue }
            }
            let variation = Self.random(Int(x), Int(z), seed: terrain.seed)
            let h = terrain.surfaceHeight(x: x, z: z) - 15
            let p = SIMD3<Float>(x, h, z)
            switch level {
            case .endor, .lantaana:
                tree(p, height: 100 + variation * 130, width: 60 + variation * 38)
                tree(p + [70,-8,55], height: 75 + variation * 85, width: 50)
            case .alpine:
                let cluster = p + [(variation - 0.5) * 95, 0, (variation - 0.5) * 150]
                spire(cluster, width: 75 + variation * 80, height: 65 + variation * 170, finish: .ice)
                if variation > 0.58 {
                    spire(cluster + [70,0,55], width: 45 + variation * 25, height: 60 + variation * 95, finish: .ice)
                } else {
                    box(cluster + [-45,18,35], [125,36,100], .ice, top: 0.45)
                }
            case .andoPrime:
                spire(p, width: 65 + variation * 80, height: 90 + variation * 200, finish: .ice)
                spire(p + [55,0,35], width: 45, height: 80 + variation * 80, finish: .ice)
            case .volcano, .sentinelOne:
                refinery(p, height: 100 + variation * 160, variant: index)
            case .deathStar:
                station(p, height: 30 + variation * 70)
            case .narShaddaa, .corellia:
                tower(p, height: 160 + variation * 320, width: 65 + variation * 65, variant: index)
            case .ordMantell, .glacier:
                wreck(p, width: 100 + variation * 110, variant: index)
            case .skylands:
                cloudCity(p, height: 90 + variation * 170)
            case .storm:
                spire(p, width: 85, height: 160 + variation * 230, finish: .dark)
                tower(p + [75,0,60], height: 100 + variation * 210, width: 50, variant: index)
            case .canyon, .boontaEve, .ordIbanna:
                spire(p, width: 90 + variation * 70, height: 160 + variation * 180, finish: .rock)
                if index.isMultiple(of: 4) { settlement(p + [100,0,30]) }
            case .freeRoam:
                if index.isMultiple(of: 7) { settlement(p) }
                else if variation > 0.48 { tree(p, height: 80 + variation * 95, width: 60) }
                else { spire(p, width: 65 + variation * 70, height: 70 + variation * 150, finish: .rock) }
            }
        }
        for (index, solid) in solids.enumerated() where solid.collidable {
            let lo = solid.center - solid.size / 2 - SIMD3<Float>(repeating: 2)
            let hi = solid.center + solid.size / 2 + SIMD3<Float>(repeating: 2)
            for x in Int(floor(lo.x / Self.binSize))...Int(floor(hi.x / Self.binSize)) {
                for z in Int(floor(lo.z / Self.binSize))...Int(floor(hi.z / Self.binSize)) {
                    bins[SIMD2<Int>(x,z), default: []].append(index)
                }
            }
        }
    }
    func hits(_ point: SIMD3<Float>) -> Bool {
        let key = SIMD2<Int>(Int(floor(point.x / Self.binSize)), Int(floor(point.z / Self.binSize)))
        return (bins[key] ?? []).contains { solids[$0].contains(point) }
    }
    private static func random(_ x: Int, _ z: Int, seed: UInt32) -> Float {
        var n = UInt32(truncatingIfNeeded: x) &* 374761393 &+ UInt32(truncatingIfNeeded: z) &* 668265263 &+ seed
        n = (n ^ (n >> 13)) &* 1274126177
        return Float((n ^ (n >> 16)) & 65535) / 65535
    }
    private mutating func box(_ p: SIMD3<Float>, _ size: SIMD3<Float>, _ finish: Finish, top: Float = 1, light: Bool = false) {
        solids.append(Solid(center:p,size:size,topScale:top,finish:finish,collidable:!light))
    }
    private mutating func spire(_ p: SIMD3<Float>, width: Float, height: Float, finish: Finish) {
        box(p + [0,height*0.33,0], [width,height*0.66,width*0.8], finish, top:0.62)
        box(p + [0,height*0.83,0], [width*0.62,height*0.34,width*0.496], finish, top:0.06)
    }
    private mutating func tree(_ p: SIMD3<Float>, height: Float, width: Float) {
        box(p + [0,height*0.25,0],[width*0.12,height*0.5,width*0.12],.dark)
        for tier in 0..<3 {
            let k = Float(tier)
            box(p + [0,height*(0.42+k*0.2),0], [width*(1-k*0.22),height*0.45,width*(1-k*0.22)],.canopy,top:0.04)
        }
    }
    private mutating func settlement(_ p: SIMD3<Float>) {
        for i in 0..<3 {
            let center = p + [Float(i-1)*47,18,Float(i%2)*22]
            box(center,[40,36,45],.rock)
            box(center + [0,22,0],[40,8,45],.metal,top:0.55)
            box(center + [0,0,22.8],[13,17,1],.amber,light:true)
        }
    }
    private mutating func tower(_ p: SIMD3<Float>, height: Float, width: Float, variant: Int) {
        box(p + [0,height*0.3,0],[width,height*0.6,width*0.8],.metal)
        box(p + [0,height*0.76,0],[width*0.65,height*0.32,width*0.56],.dark)
        box(p + [0,height*0.96,0],[width*0.3,height*0.08,width*0.3],.metal,top:0.18)
        for i in 1...6 {
            box(p + [0,height*Float(i)*0.085,width*0.405],[width*0.8,3,1],variant.isMultiple(of:2) ? .cyan:.amber,light:true)
            box(p + [width*0.505,height*Float(i)*0.085,0],[1,3,width*0.65],.cyan,light:true)
        }
    }
    private mutating func station(_ p: SIMD3<Float>, height: Float) {
        box(p + [0,height*0.5,0],[110,height,135],.metal,top:0.82)
        for i in -2...2 {
            box(p + [Float(i)*18,height+4,0],[10,8,95],.dark)
            box(p + [Float(i)*18,height+8.5,0],[4,1,50],.cyan,light:true)
        }
    }
    private mutating func refinery(_ p: SIMD3<Float>, height: Float, variant: Int) {
        station(p,height:35)
        for side: Float in [-1,1] {
            box(p + [side*30,height*0.5,0],[24,height,30],.dark,top:0.7)
            for i in 1...5 { box(p + [side*30,height*Float(i)/6,15.5],[24,5,1],.amber,light:true) }
        }
    }
    private mutating func wreck(_ p: SIMD3<Float>, width: Float, variant: Int) {
        box(p + [0,24,0],[width,48,90],.metal,top:0.55)
        box(p + [width*0.35,55,10],[width*0.25,62,48],.dark,top:0.32)
        for i in 0..<5 { box(p + [Float(i-2)*width*0.16,42,0],[6,28,96],.rock,top:0.8) }
    }
    private mutating func cloudCity(_ p: SIMD3<Float>, height: Float) {
        box(p + [0,height*0.5,0],[60,height,60],.dark,top:0.65)
        box(p + [0,height+8,0],[180,16,150],.metal,top:0.86)
        box(p + [0,height+36,0],[100,40,90],.ice,top:0.25)
        for side: Float in [-1,1] { box(p + [side*82,height+9,0],[2,3,125],.amber,light:true) }
    }
}

/// Seven static material batches replace hundreds of individual scenery entities.
@MainActor
enum ScenicRegionRenderer {
    static func make(_ layout: ScenicRegion, level: FlightLevel) throws -> Entity {
        let root = Entity(); root.name = "Prepared scenic region"
        var batches = Array(repeating:TerrainMeshData(),count:ScenicRegion.Finish.allCases.count)
        for solid in layout.solids {
            let a = solid.center - solid.size / 2, b = solid.center + solid.size / 2
            let x = solid.size.x * solid.topScale / 2, z = solid.size.z * solid.topScale / 2
            let p: [SIMD3<Float>] = [[a.x,a.y,a.z],[b.x,a.y,a.z],[b.x,a.y,b.z],[a.x,a.y,b.z],
                [solid.center.x-x,b.y,solid.center.z-z],[solid.center.x+x,b.y,solid.center.z-z],
                [solid.center.x+x,b.y,solid.center.z+z],[solid.center.x-x,b.y,solid.center.z+z]]
            for face in [[0,4,5,1],[1,5,6,2],[2,6,7,3],[3,7,4,0],[4,7,6,5],[0,1,2,3]] {
                for t in [[face[0],face[1],face[2]],[face[0],face[2],face[3]]] {
                    let vertices = t.map { p[$0] }
                    let normal = simd_normalize(simd_cross(vertices[1]-vertices[0],vertices[2]-vertices[0]))
                    let index = solid.finish.rawValue, start = UInt32(batches[index].positions.count)
                    batches[index].positions += vertices
                    batches[index].normals += [normal,normal,normal]
                    batches[index].indices += [start,start+1,start+2]
                }
            }
        }
        let colors: [UIColor] = [UIColor(rgb:level.palette[2]), .init(red:0.32,green:0.36,blue:0.42,alpha:1),
            .init(red:0.10,green:0.13,blue:0.16,alpha:1), .init(red:0.11,green:0.31,blue:0.17,alpha:1),
            .init(red:0.77,green:0.9,blue:0.97,alpha:1),.init(red:1,green:0.45,blue:0.12,alpha:1),.cyan]
        for finish in ScenicRegion.Finish.allCases {
            let data = batches[finish.rawValue]
            guard !data.positions.isEmpty else { continue }
            var descriptor = MeshDescriptor(name:"Scenery \(finish)")
            descriptor.positions = MeshBuffers.Positions(data.positions)
            descriptor.normals = MeshBuffers.Normals(data.normals)
            descriptor.primitives = .triangles(data.indices)
            let material: any RealityKit.Material = finish == .amber || finish == .cyan ?
                UnlitMaterial(color:colors[finish.rawValue]) : SimpleMaterial(color:colors[finish.rawValue],roughness:0.82,isMetallic:finish == .metal)
            let entity = ModelEntity(mesh:try MeshResource.generate(from:[descriptor]),materials:[material])
            entity.name = "Scenery \(finish) batch"; root.addChild(entity)
        }
        return root
    }
}
