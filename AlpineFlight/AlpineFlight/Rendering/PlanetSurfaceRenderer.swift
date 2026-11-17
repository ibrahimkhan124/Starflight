import RealityKit
import UIKit

/// Prepared once per planet. Terrain uses the collision map's exact vertices;
/// solid scenery is contained inside that map's obstacle boxes. Detail is batched
/// by material rather than creating a light or an entity for every window/tree.
@MainActor
final class PlanetSurfaceRenderer {
    let root = Entity()
    private let planet: SpacePlanet
    private let reducedDetail: Bool
    private let sky: ModelEntity
    private var markers: [ModelEntity] = []
    private var traffic: [ModelEntity] = []
    private var residentGroups: [(Entity,SIMD3<Float>)] = []
    private var jobMarkers: [CityStation: ModelEntity] = [:]
    private var approachMarkers: [CityStation: ModelEntity] = [:]
    private var lastJobTarget: CityStation?
    private var lastJobServicing = false
    private var cloudLayer: Entity?
    private var time: Float = 0
    private var weatherParticles: ModelEntity?
    private var wildlife:PlanetWildlifeRenderer?
    private var sandWash:Entity?
    private var sandPuffs:[ModelEntity]=[]
    private var mirage:MirageBasinRenderer?
    private var canyonFunnels:[Entity] = []
    private struct CanyonBird {
        let root:Entity
        let left:Entity
        let right:Entity
    }
    private var canyonBirds:[CanyonBird] = []
    private var lastPassed = -1
    private let activeLight = UnlitMaterial(color: .cyan)
    private let visitedLight = UnlitMaterial(color: .systemGreen)
    private let idleStationLight = UnlitMaterial(color: .init(red:0.04,green:0.34,blue:0.42,alpha:1))
    private let targetStationLight = UnlitMaterial(color: .init(red:1,green:0.72,blue:0.13,alpha:1))
    private let servicingStationLight = UnlitMaterial(color: .init(red:0.20,green:1,blue:0.47,alpha:1))

    private struct Batch {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        var uvs: [SIMD2<Float>] = []
        mutating func quad(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>) {
            let cross = simd_cross(b - a, c - a)
            guard simd_length_squared(cross) > 0.0001 else { return }
            let start = UInt32(positions.count)
            positions += [a,b,c,d]
            uvs += [a,b,c,d].map { [($0.x+$0.z*0.15)/180,$0.y/90+$0.z/180] }
            normals += Array(repeating: simd_normalize(cross), count: 4)
            indices += [start,start+1,start+2,start,start+2,start+3]
        }
        mutating func triangle(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) {
            let cross = simd_cross(b-a,c-a)
            guard simd_length_squared(cross)>0.0001 else { return }
            let start = UInt32(positions.count)
            positions += [a,b,c]
            uvs += [a,b,c].map { [($0.x+$0.z*0.15)/180,$0.y/90+$0.z/180] }
            normals += Array(repeating:simd_normalize(cross),count:3)
            indices += [start,start+1,start+2]
        }
        // Neon is a thin luminous surface, never a real light for every strip.
        mutating func panel(center: SIMD3<Float>, size: SIMD3<Float>) {
            let a = center - size / 2, b = center + size / 2
            if size.y <= size.x && size.y <= size.z {
                quad([a.x,center.y,a.z],[a.x,center.y,b.z],[b.x,center.y,b.z],[b.x,center.y,a.z])
            } else if size.z <= size.x && size.z <= size.y {
                quad([a.x,a.y,center.z],[b.x,a.y,center.z],[b.x,b.y,center.z],[a.x,b.y,center.z])
            } else {
                quad([center.x,a.y,a.z],[center.x,b.y,a.z],[center.x,b.y,b.z],[center.x,a.y,b.z])
            }
        }
        mutating func softSprite(center:SIMD3<Float>,right:SIMD3<Float>,up:SIMD3<Float>) {
            let before = positions.count
            quad(center-right-up,center+right-up,center+right+up,center-right+up)
            guard positions.count == before+4 else { return }
            let corners:[SIMD2<Float>] = [[0,1],[1,1],[1,0],[0,0]]
            for index in 0..<4 { uvs[before+index] = corners[index] }
        }
        mutating func box(center: SIMD3<Float>, size: SIMD3<Float>) {
            let a = center - size / 2, b = center + size / 2
            quad([a.x,b.y,a.z],[a.x,b.y,b.z],[b.x,b.y,b.z],[b.x,b.y,a.z])
            quad([a.x,a.y,a.z],[b.x,a.y,a.z],[b.x,a.y,b.z],[a.x,a.y,b.z])
            quad([a.x,a.y,a.z],[a.x,b.y,a.z],[b.x,b.y,a.z],[b.x,a.y,a.z])
            quad([b.x,a.y,b.z],[b.x,b.y,b.z],[a.x,b.y,b.z],[a.x,a.y,b.z])
            quad([a.x,a.y,b.z],[a.x,b.y,b.z],[a.x,b.y,a.z],[a.x,a.y,a.z])
            quad([b.x,a.y,a.z],[b.x,b.y,a.z],[b.x,b.y,b.z],[b.x,a.y,b.z])
        }
        mutating func box(center:SIMD3<Float>,size:SIMD3<Float>,yaw:Float) {
            var source = Batch(); source.box(center:.zero,size:size)
            let rotation = simd_quatf(angle:yaw,axis:[0,1,0])
            let offset = UInt32(positions.count)
            positions += source.positions.map { center+rotation.act($0) }
            uvs += source.positions.map { let p = center+rotation.act($0); return [(p.x+p.z*0.15)/180,p.y/90+p.z/180] }
            normals += source.normals.map { rotation.act($0) }
            indices += source.indices.map { $0+offset }
        }
        /// Closed top, faceted sides; every radius stays inside the supplied box.
        mutating func frustum(center: SIMD3<Float>, size: SIMD3<Float>, top: Float, sides: Int = 8, rotation: Float = 0) {
            let half = size / 2
            for index in 0..<sides {
                let a = Float(index) * .pi * 2 / Float(sides) + rotation
                let b = Float(index + 1) * .pi * 2 / Float(sides) + rotation
                let lowA = center + SIMD3<Float>(cos(a) * half.x, -half.y, sin(a) * half.z)
                let lowB = center + SIMD3<Float>(cos(b) * half.x, -half.y, sin(b) * half.z)
                let highA = center + SIMD3<Float>(cos(a) * half.x * top, half.y, sin(a) * half.z * top)
                let highB = center + SIMD3<Float>(cos(b) * half.x * top, half.y, sin(b) * half.z * top)
                quad(lowA, highA, highB, lowB)
                triangle(center + SIMD3<Float>(0, half.y, 0), highB, highA)
            }
        }
        mutating func dome(center: SIMD3<Float>, radius: SIMD3<Float>, sides: Int = 12) {
            for ring in 0..<4 {
                let a = Float(ring) * .pi / 8, b = Float(ring + 1) * .pi / 8
                for slice in 0..<sides {
                    let x = Float(slice) * .pi * 2 / Float(sides), y = Float(slice+1) * .pi * 2 / Float(sides)
                    func point(_ elevation: Float, _ angle: Float) -> SIMD3<Float> {
                        center + radius * SIMD3<Float>(cos(elevation)*cos(angle), sin(elevation), cos(elevation)*sin(angle))
                    }
                    quad(point(a,x),point(b,x),point(b,y),point(a,y))
                }
            }
        }
        mutating func ellipsoid(center:SIMD3<Float>,radius:SIMD3<Float>) {
            for ring in 0..<6 {
                let a = -Float.pi/2+Float(ring)*Float.pi/6, b = a+Float.pi/6
                for slice in 0..<10 {
                    let x = Float(slice)*2 * .pi/10, y = Float(slice+1)*2 * .pi/10
                    func p(_ e:Float,_ angle:Float) -> SIMD3<Float> {
                        center+radius*SIMD3<Float>(cos(e)*cos(angle),sin(e),cos(e)*sin(angle))
                    }
                    quad(p(a,x),p(b,x),p(b,y),p(a,y))
                }
            }
        }
        /// Four smoothly shaded rings provide a rounded silhouette while keeping
        /// the prepared forest within the mobile geometry budget.
        mutating func canopy(center:SIMD3<Float>,radius:SIMD3<Float>,sides:Int,phase:Float = 0) {
            let rings = 4
            for ring in 0..<rings {
                let a = -Float.pi/2+Float(ring)*Float.pi/Float(rings), b = a+Float.pi/Float(rings)
                for slice in 0..<sides {
                    let x = Float(slice)*2 * .pi/Float(sides), y = Float(slice+1)*2 * .pi/Float(sides)
                    func p(_ elevation:Float,_ angle:Float) -> SIMD3<Float> {
                        let ripple = 0.88+0.08*sin(angle*3+phase)+0.04*cos(angle*5-phase+elevation*2)
                        return center+radius*SIMD3<Float>(cos(elevation)*cos(angle)*ripple,sin(elevation),cos(elevation)*sin(angle)*ripple)
                    }
                    let before = positions.count
                    if ring == 0 { triangle(p(a,x),p(b,x),p(b,y)) }
                    else if ring == rings-1 { triangle(p(a,x),p(b,x),p(a,y)) }
                    else { quad(p(a,x),p(b,x),p(b,y),p(a,y)) }
                    for index in before..<positions.count {
                        normals[index] = simd_normalize((positions[index]-center)/(radius*radius))
                        uvs[index] = [positions[index].x/24,positions[index].z/24+positions[index].y/32]
                    }
                }
            }
        }
        @MainActor func entity(name: String, material: any RealityKit.Material) -> ModelEntity? {
            guard !positions.isEmpty else { return nil }
            var mesh = MeshDescriptor(name: name)
            mesh.positions = MeshBuffers.Positions(positions)
            mesh.normals = MeshBuffers.Normals(normals)
            mesh.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
            mesh.primitives = .triangles(indices)
            guard let resource = try? MeshResource.generate(from: [mesh]) else { return nil }
            let result = ModelEntity(mesh: resource, materials: [material]); result.name = name
            return result
        }
    }

    init(planet: SpacePlanet, reducedDetail: Bool = false) {
        self.planet = planet
        self.reducedDetail = reducedDetail
        root.name = planet.name + " expanded surface"
        let skyColor: UIColor
        switch planet {
        case .coruscant: skyColor = .init(red:0.035,green:0.045,blue:0.085,alpha:1)
        case .tatooine: skyColor = .init(red:0.42,green:0.31,blue:0.24,alpha:1)
        case .hoth: skyColor = .init(red:0.20,green:0.39,blue:0.58,alpha:1)
        case .endor: skyColor = .init(red:0.33,green:0.43,blue:0.38,alpha:1)
        }
        let horizon:UIColor
        switch planet {
        case .coruscant: horizon = Self.color(0.14,0.10,0.23)
        case .tatooine: horizon = Self.color(0.83,0.63,0.43)
        case .hoth: horizon = Self.color(0.75,0.84,0.9)
        case .endor: horizon = Self.color(0.73,0.78,0.65)
        }
        var skyMaterial = ScenicMaterials.sky(zenith:skyColor,horizon:horizon)
        skyMaterial.faceCulling = .front
        sky = ModelEntity(mesh:.generateSphere(radius:11000),materials:[skyMaterial])
        sky.name = "Planet atmosphere"
        sky.components.set(DynamicLightShadowComponent(castsShadow:false))
        root.addChild(sky)
        buildAtmosphere()
        build()
        buildScenicAtmosphere()
        buildCloudLayer()
        buildSkyports()
        buildInhabitants()
        let animals=PlanetWildlifeRenderer(planet:planet,reduced:reducedDetail)
        wildlife=animals;root.addChild(animals.root)
        if planet == .tatooine { buildSandWash() }
        if planet == .tatooine,TatooineCanyon.enabled,let data = try? TatooineCanyon.mesh.get(),
           let mesh = try? AetherPlanetRenderer.mesh(data,name:"Sunlit sandstone arch",worldUVScale:180) {
            let arch = ModelEntity(mesh:mesh,materials:[ScenicMaterials.terrain(color:.white,kind:"sand",planet:"Tatooine",continuous:true,reducedDetail:reducedDetail)])
            arch.name="Canyon of Light study arch";arch.position=TatooineCanyon.origin;root.addChild(arch)
            buildCanyonDust()
            buildCanyonLife()
            if MirageBasin.enabled,let basin=try? MirageBasinRenderer() { mirage=basin;root.addChild(basin.root) }
        }
        if planet != .tatooine { buildBirdFlocks() }
        root.isEnabled = false
    }

    /// fx.js/part sandfall study: preallocated veils, no per-grain entities.
    private func buildCanyonDust() {
        guard let material = ScenicMaterials.canyonDust() else { return }
        var positions:[SIMD3<Float>]=[],normals:[SIMD3<Float>]=[],uvs:[SIMD2<Float>]=[],indices:[UInt32]=[]
        func veil(center:SIMD3<Float>,right:SIMD3<Float>,height:Float,kind:Float) {
            let start=UInt32(positions.count),up=SIMD3<Float>(0,height*0.5,0)
            positions += [center-right-up,center+right-up,center+right+up,center-right+up]
            normals += Array(repeating:simd_normalize(simd_cross(right,up)),count:4)
            // UV.x reserves separate bands for sandfalls (0..1) and ground dust (2..3).
            uvs += [[kind,0],[kind+1,0],[kind+1,1],[kind,1]]
            indices += [start,start+1,start+2,start,start+2,start+3]
        }
        // The fall is beside the right leg, leaving the central survey route visible.
        veil(center:[150,145,88],right:[16,0,0],height:280,kind:0)
        if !reducedDetail { veil(center:[150,145,88],right:[0,0,16],height:280,kind:0) }
        for i in 0..<(reducedDetail ? 2 : 4) {
            let x:Float = i.isMultiple(of:2) ? -220 : 215
            let z=Float(i)*180-200
            let ground=PlanetExploration(planet:.tatooine).groundHeight(x:TatooineCanyon.origin.x+x,z:TatooineCanyon.origin.z+z)
            veil(center:[x,ground-TatooineCanyon.origin.y+18,z],right:[65,0,18],height:34,kind:2)
        }
        var descriptor=MeshDescriptor(name:"Prepared canyon dust veils")
        descriptor.positions = .init(positions);descriptor.normals = .init(normals)
        descriptor.textureCoordinates = .init(uvs);descriptor.primitives = .triangles(indices)
        guard let mesh=try? MeshResource.generate(from:[descriptor]) else { return }
        let dust=ModelEntity(mesh:mesh,materials:[material]);dust.name="Canyon sandfall and drifting dust"
        dust.position=TatooineCanyon.origin;dust.components.set(DynamicLightShadowComponent(castsShadow:false))
        root.addChild(dust)
    }

    /// World/parts/kit composition prepared before the region becomes visible.
    private func buildCanyonLife() {
        if let data=try? CanyonLife.funnel.get(),
           let mesh=try? AetherPlanetRenderer.mesh(data,name:"Prepared wind funnel",textureCoordinates:CanyonLife.funnelUVs(data)),
           let material=ScenicMaterials.canyonWind() {
            let ground=PlanetExploration(planet:.tatooine)
            for offset in CanyonLife.funnelOffsets.prefix(reducedDetail ? 1:2) {
                let funnel=ModelEntity(mesh:mesh,materials:[material])
                funnel.name="Canyon wind funnel"
                let x=TatooineCanyon.origin.x+offset.x,z=TatooineCanyon.origin.z+offset.z
                funnel.position=[x,ground.groundHeight(x:x,z:z),z]
                funnel.components.set(DynamicLightShadowComponent(castsShadow:false))
                root.addChild(funnel);canyonFunnels.append(funnel)
            }
        }
        buildBirdFlocks()
    }
    var wildlifeLookoutPoint:SIMD3<Float> { PlanetWildlife.bird(0,time:time,planet:planet).position }
    private func buildBirdFlocks() {
        var descriptor=MeshDescriptor(name:"Shared planet glider wing")
        descriptor.positions = .init([[0,0,0],[3,0,-2],[7,0,2],[3.5,0,1]])
        descriptor.normals = .init(Array(repeating:[0,1,0],count:4))
        descriptor.primitives = .triangles([0,1,3,1,2,3])
        guard let wingMesh=try? MeshResource.generate(from:[descriptor]) else { return }
        let birdColor:UIColor
        switch planet {
        case .tatooine:birdColor=Self.color(0.14,0.10,0.07)
        case .endor:birdColor=Self.color(0.65,0.35,0.15)
        case .hoth:birdColor=Self.color(0.70,0.82,0.90)
        case .coruscant:birdColor=Self.color(0.38,0.29,0.46)
        }
        var paint=UnlitMaterial(color:birdColor);paint.faceCulling = .none
        let bodyMesh=MeshResource.generateBox(size:[1.3,0.8,3.4])
        for i in 0..<CanyonLife.birdCount(reduced:reducedDetail) {
            let bird=Entity();bird.name=PlanetWildlife.birdName(on:planet)+" \(i+1)";bird.scale=SIMD3(repeating:CanyonLife.birdScale(i))
            let body=ModelEntity(mesh:bodyMesh,materials:[paint])
            let left=ModelEntity(mesh:wingMesh,materials:[paint]),right=ModelEntity(mesh:wingMesh,materials:[paint])
            right.scale.x = -1
            bird.addChild(body);bird.addChild(left);bird.addChild(right)
            root.addChild(bird);canyonBirds.append(CanyonBird(root:bird,left:left,right:right))
        }
        updateCanyonLife()
    }
    private func updateCanyonLife(viewer:SIMD3<Float>?=nil) {
        for (i,funnel) in canyonFunnels.enumerated() {
            funnel.orientation=simd_quatf(angle:time*0.32+Float(i)*2,axis:[0,1,0])
        }
        for (i,bird) in canyonBirds.enumerated() {
            let pose=PlanetWildlife.bird(i,time:time,planet:planet)
            let world=pose.position
            if let viewer {
                let distance=simd_distance(world,viewer),visible=distance<3000
                if bird.root.isEnabled != visible { bird.root.isEnabled=visible }
                guard visible else { continue }
                bird.root.components.set(OpacityComponent(opacity:max(0,min(1,(3000-distance)/800))))
            }
            bird.root.position=world
            bird.root.orientation=simd_quatf(angle:pose.heading,axis:[0,1,0])*simd_quatf(angle:pose.bank,axis:[0,0,1])
            bird.left.orientation=simd_quatf(angle:pose.wing,axis:[0,0,1])
            bird.right.orientation=simd_quatf(angle:-pose.wing,axis:[0,0,1])
        }
    }

    private func buildSandWash() {
        var dust=Batch()
        let count=reducedDetail ? 4:8
        for i in 0..<count {
            let a=Float(i)*2 * .pi/Float(count)
            let center=SIMD3<Float>(cos(a)*8,3+Float(i%3)*2,sin(a)*8)
            dust.softSprite(center:center,right:[cos(a)*12,0,sin(a)*12],up:[0,5,0])
        }
        var material=Self.neon(Self.color(0.85,0.63,0.37))
        if let texture=Self.softMistTexture { material.color = .init(tint:Self.color(0.85,0.63,0.37),texture:.init(texture)) }
        material.blending = .transparent(opacity:.init(floatLiteral:0.28))
        guard let template=dust.entity(name:"Prepared sand puff",material:material),let model=template.model else { return }
        let emitter=Entity();emitter.name="Aircraft low-ground sand wash";emitter.isEnabled=false
        for i in 0..<(reducedDetail ? 2:3) {
            let puff=ModelEntity(mesh:model.mesh,materials:model.materials);puff.name="Rising sand puff \(i)"
            puff.components.set(DynamicLightShadowComponent(castsShadow:false));emitter.addChild(puff);sandPuffs.append(puff)
        }
        root.addChild(emitter);sandWash=emitter
    }
    private func updateSandWash(position:SIMD3<Float>?) {
        guard let sandWash else { return }
        guard let position else { sandWash.isEnabled=false;return }
        let ground=PlanetExploration(planet:.tatooine).groundHeight(x:position.x,z:position.z)
        let strength=PlanetWildlife.dustStrength(clearance:position.y-ground)
        sandWash.isEnabled=strength>0
        guard sandWash.isEnabled else { return }
        sandWash.position=[position.x,ground+0.5,position.z]
        sandWash.scale=SIMD3(repeating:0.6+strength*1.6)
        sandWash.components.set(OpacityComponent(opacity:strength))
        for (i,puff) in sandPuffs.enumerated() {
            let age=(time*0.65+Float(i)/Float(sandPuffs.count)).truncatingRemainder(dividingBy:1)
            puff.position=[sin(age*5+Float(i))*age*3,age*8,cos(age*5+Float(i))*age*3]
            puff.scale=SIMD3(repeating:0.5+age*0.8)
            puff.orientation=simd_quatf(angle:time*0.65+Float(i)*2,axis:[0,1,0])
            puff.components.set(OpacityComponent(opacity:(1-age)*(1-age)*0.8))
        }
    }

    private func buildAtmosphere() {
        if planet == .tatooine {
            for (index, position) in [SIMD3<Float>(-6200,4000,-6500),SIMD3<Float>(-5100,3250,-7600)].enumerated() {
                let sun = ModelEntity(mesh:.generateSphere(radius:index == 0 ? 380 : 240),materials:[Self.neon(index == 0 ? .init(red:1,green:0.86,blue:0.54,alpha:1) : .init(red:1,green:0.61,blue:0.34,alpha:1))])
                sun.position = position; sun.name = "Twin sun \(index+1)"; sun.components.set(DynamicLightShadowComponent(castsShadow:false)); sky.addChild(sun)
            }
        } else {
            let color:UIColor = planet == .endor ? .init(red:0.56,green:0.68,blue:0.72,alpha:1) : .init(red:0.62,green:0.72,blue:0.84,alpha:1)
            let moon = ModelEntity(mesh:.generateSphere(radius:planet == .endor ? 920 : 320),materials:[SimpleMaterial(color:color,roughness:1,isMetallic:false)])
            moon.position = [6500,5100,-5800]; moon.name = "Distant moon"; moon.components.set(DynamicLightShadowComponent(castsShadow:false)); sky.addChild(moon)
        }
        if planet == .coruscant {
            var stars = Batch()
            for index in 0..<(reducedDetail ? 70 : 150) {
                let a = Float(index) * 2.399963
                let elevation = 0.28 + abs(sin(Float(index)*2.137)) * 1.15
                let center = SIMD3<Float>(cos(a)*cos(elevation),sin(elevation),sin(a)*cos(elevation))*10200
                let right = simd_normalize(simd_cross(center,[0,1,0]))*Float(4+index%4)
                let up = simd_normalize(simd_cross(right,center))*Float(4+index%4)
                stars.quad(center-right-up,center+right-up,center+right+up,center-right+up)
            }
            if let entity = stars.entity(name:"City night stars",material:Self.neon(.init(red:0.65,green:0.75,blue:1,alpha:1))) { sky.addChild(entity) }
        }
    }

    private func build() {
        let surface = PlanetExploration(planet:planet)
        // Six terrain tones follow real slopes/elevation bands, including snow and exposed rock.
        var terrain = Array(repeating:Batch(),count:6)
        var scenery = [Batch(),Batch(),Batch()], lights = Batch(), accents = Batch(), signs = Batch(), violet = Batch(), trim = Batch(), foliage = Batch()
        // Prepare every section before publishing any of them. On failure keep
        // the complete legacy terrain rather than exposing a partially built region.
        let aetherTerrain:[ModelEntity]? = AetherHomeTerrain.enabled(for:planet)
            ? try? AetherPlanetRenderer.homeTiles(AetherHomeTerrain.prepared(for:planet).get(),planet:planet,reducedDetail:reducedDetail) : nil
        if aetherTerrain == nil {
        let row = PlanetExploration.grid+1
        var vertexGrid:[SIMD3<Float>] = [], normalGrid:[SIMD3<Float>] = []
        vertexGrid.reserveCapacity(row*row); normalGrid.reserveCapacity(row*row)
        for i in 0..<row { for j in 0..<row {
            let x = -PlanetExploration.extent+Float(i)*PlanetExploration.step
            let z = -PlanetExploration.extent+Float(j)*PlanetExploration.step
            vertexGrid.append([x,surface.vertexHeight(x:x,z:z),z])
            let e = PlanetExploration.step*0.5
            if planet == .coruscant { normalGrid.append([0,1,0]) }
            else {
                let dx = surface.vertexHeight(x:x+e,z:z)-surface.vertexHeight(x:x-e,z:z)
                let dz = surface.vertexHeight(x:x,z:z+e)-surface.vertexHeight(x:x,z:z-e)
                normalGrid.append(simd_normalize(SIMD3<Float>(-dx,2*e,-dz)))
            }
        } }
        func point(_ i:Int,_ j:Int) -> SIMD3<Float> { vertexGrid[i*row+j] }
        for i in 0..<PlanetExploration.grid {
            for j in 0..<PlanetExploration.grid {
                let a = point(i,j), b = point(i,j+1), c = point(i+1,j+1), d = point(i+1,j)
                let height = (a.y+b.y+c.y+d.y)/4
                let slope = max(abs(a.y-c.y),abs(b.y-d.y)) / PlanetExploration.step
                let band:Int
                switch planet {
                case .coruscant: band = (i/4+j/4)%2
                case .tatooine:
                    band = slope > 0.65 ? 3 + Int(max(0,height)/70)%3 : Int(max(0,height+35*sin(a.x*0.0006+a.z*0.0003))/190)%3
                case .hoth:
                    let ice = sin(a.x*0.0011+sin(a.z*0.0007))*cos(a.z*0.00045)
                    let rift = surface.glacierRift(x:(a.x+c.x)*0.5,z:(a.z+c.z)*0.5)
                    band = rift > 0.35 ? (rift > 0.7 ? 3:4) : slope > 0.9 ? 3 + (ice > 0 ? 1:0) : (height > 1050 ? 5 : ice > 0.4 ? 2 : ice < -0.2 ? 1:0)
                case .endor:
                    let grove = sin(a.x*0.0007+sin(a.z*0.0008))*cos(a.z*0.0005)
                    band = height > 1100 || slope > 0.85 ? 3 + Int(max(0,height)/180)%3 : grove > 0.3 ? 1 : grove < -0.3 ? 2:0
                }
                let before = terrain[band].positions.count
                terrain[band].quad(a,b,c,d)
                let normals = [normalGrid[i*row+j],normalGrid[i*row+j+1],normalGrid[(i+1)*row+j+1],normalGrid[(i+1)*row+j]]
                for (offset,index) in (before..<terrain[band].positions.count).enumerated() {
                    let p = terrain[band].positions[index]
                    terrain[band].normals[index] = normals[offset]
                    terrain[band].uvs[index] = [p.x/180,p.z/180]
                }
            }
        }
        }
        if let aetherTerrain { for entity in aetherTerrain { root.addChild(entity) } }
        let groundColors:[UIColor], colors:[UIColor]
        switch planet {
        case .coruscant:
            groundColors = [Self.color(0.045,0.055,0.09),Self.color(0.065,0.075,0.115),Self.color(0.08,0.09,0.14),.darkGray,.gray,.lightGray]
            colors = [Self.color(0.075,0.09,0.14),Self.color(0.11,0.10,0.14),Self.color(0.045,0.065,0.11)]
        case .tatooine:
            groundColors = [Self.color(0.76,0.54,0.32),Self.color(0.81,0.59,0.36),Self.color(0.73,0.50,0.29),Self.color(0.64,0.40,0.24),Self.color(0.68,0.44,0.27),Self.color(0.72,0.48,0.29)]
            colors = [Self.color(0.55,0.29,0.15),Self.color(0.88,0.69,0.44),Self.color(0.68,0.42,0.23)]
        case .hoth:
            groundColors = [Self.color(0.84,0.90,0.94),Self.color(0.79,0.87,0.93),Self.color(0.89,0.93,0.96),Self.color(0.37,0.60,0.74),Self.color(0.55,0.74,0.84),Self.color(0.93,0.96,0.98)]
            colors = [Self.color(0.37,0.67,0.84),Self.color(0.62,0.81,0.93),Self.color(0.91,0.96,1)]
        case .endor:
            groundColors = [Self.color(0.19,0.29,0.16),Self.color(0.23,0.32,0.18),Self.color(0.16,0.25,0.13),Self.color(0.34,0.36,0.28),Self.color(0.39,0.40,0.32),Self.color(0.30,0.33,0.25)]
            colors = [Self.color(0.10,0.30,0.12),Self.color(0.19,0.39,0.15),Self.color(0.05,0.20,0.12)]
        }
        // Tunnel walls use the exact solid boxes queried by collision. Neon follows
        // the inside of each opening; it never caps or crosses the flight corridor.
        for tunnel in surface.tunnels {
            for solid in tunnel.solids { scenery[1].box(center:solid.center,size:solid.size,yaw:solid.yaw) }
            let path = tunnel.path, half = tunnel.openingWidth/2
            for (index,pair) in zip(path,path.dropFirst()).enumerated() {
                let a = pair.0, b = pair.1, middle = (a+b)/2
                let yaw = atan2(b.x-a.x,b.z-a.z), length = simd_distance(a,b)+1
                let right = SIMD3<Float>(cos(yaw),0,-sin(yaw))
                for side:Float in [-1,1] {
                    let p = middle+right*side*(half-1)
                    lights.box(center:[p.x,tunnel.openingBottom+4,p.z],size:[2,2,length],yaw:yaw)
                    violet.box(center:[p.x,tunnel.openingBottom+tunnel.openingHeight-3,p.z],size:[2,2,length],yaw:yaw)
                }
                if index.isMultiple(of:4) {
                    lights.box(center:[middle.x,tunnel.openingBottom+tunnel.openingHeight-1,middle.z],size:[tunnel.openingWidth,1,2],yaw:yaw)
                    accents.box(center:[middle.x,tunnel.openingBottom+1,middle.z],size:[5,1,9],yaw:yaw)
                }
            }
            for p in [path[0],path[path.count-1]] {
                for side:Float in [-1,1] {
                    lights.box(center:[p.x+side*(half-1),p.y,p.z],size:[2,tunnel.openingHeight,2])
                }
                violet.box(center:[p.x,tunnel.openingBottom+tunnel.openingHeight-1,p.z],size:[tunnel.openingWidth,2,2])
            }
        }
        for (index,obstacle) in surface.obstacles.enumerated() {
            guard obstacle.style < 3 else { continue }
            let center = obstacle.center, size = obstacle.size, style = obstacle.style
            let detail = !reducedDetail && abs(center.x)<6500 && abs(center.z)<9500
            let base = center.y-size.y/2
            switch planet {
            case .coruscant:
                // Three architectural families. All parapets, spires and roof equipment
                // fit below the original box top, so the navigation avenues stay open.
                scenery[style].box(center:[center.x,base+size.y*0.08,center.z],size:[size.x,size.y*0.16,size.z])
                if style == 0 {
                    for tier in 0..<4 {
                        let scale = 0.92-Float(tier)*0.15
                        scenery[style].box(center:[center.x,base+size.y*(0.26+Float(tier)*0.20),center.z],size:[size.x*scale,size.y*0.20,size.z*scale])
                    }
                } else if style == 1 {
                    for side:Float in [-1,1] {
                        scenery[style].box(center:[center.x+side*size.x*0.27,base+size.y*0.53,center.z],size:[size.x*0.34,size.y*0.74,size.z*0.72])
                    }
                    scenery[2].box(center:[center.x,base+size.y*0.68,center.z],size:[size.x*0.25,size.y*0.11,size.z*0.58])
                } else {
                    scenery[style].frustum(center:[center.x,base+size.y*0.51,center.z],size:[size.x*0.92,size.y*0.72,size.z*0.92],top:0.66)
                    scenery[0].frustum(center:[center.x,base+size.y*0.91,center.z],size:[size.x*0.45,size.y*0.08,size.z*0.45],top:0.9)
                }
                scenery[style].box(center:[center.x,base+size.y*0.90,center.z],size:[size.x*0.25,size.y*0.10,size.z*0.30])
                trim.box(center:[center.x,base+size.y*0.96,center.z],size:[size.x*0.06,size.y*0.08,size.z*0.06])
                let floors = detail ? 12 : 4
                for floor in 0..<floors {
                    let fraction = 0.20 + Float(floor)*0.60/Float(floors)
                    let y = base+size.y*fraction
                    var inset:Float = 0.46
                    if style == 0 { inset = (0.92-Float(min(3,Int((fraction-0.16)/0.20)))*0.15)/2 }
                    else if style == 1 { inset = 0.36 }
                    else { inset = (0.92*(1-(fraction-0.15)*0.34/0.72))/2 }
                    let columns = detail ? 5 : 3
                    let facadeCenters:[Float] = style == 1 ? [-0.27,0.27] : [0]
                    for facade in facadeCenters {
                        for column in 0..<columns {
                            let along = (Float(column)+0.5)/Float(columns)-0.5
                            let length = style == 1 ? size.x*0.27 : size.x*inset*(style == 2 ? 0.75 : 1.55)
                            if (column+floor+index)%7 != 0 {
                                let x = center.x+facade*size.x+along*length
                                if (column+floor+index)%4 == 0 {
                                    signs.panel(center:[x,y,center.z+size.z*inset+0.6],size:[length/Float(columns)*0.55,3,1])
                                    signs.panel(center:[x,y,center.z-size.z*inset-0.6],size:[length/Float(columns)*0.55,3,1])
                                } else {
                                    lights.panel(center:[x,y,center.z+size.z*inset+0.6],size:[length/Float(columns)*0.55,3,1])
                                    lights.panel(center:[x,y,center.z-size.z*inset-0.6],size:[length/Float(columns)*0.55,3,1])
                                }
                            }
                        }
                    }
                    if floor.isMultiple(of:2) {
                        violet.panel(center:[center.x-size.x*inset-0.5,y,center.z],size:[1,3,size.z*inset*(style == 2 ? 0.70 : 1.4)])
                        lights.panel(center:[center.x+size.x*inset+0.5,y,center.z],size:[1,3,size.z*inset*(style == 2 ? 0.70 : 1.4)])
                    }
                }
                // Street signs use distinct glyphs instead of a continuous glowing wall.
                if index.isMultiple(of:3) {
                    let y = base+size.y*0.085, z = center.z+size.z*0.5+0.6
                    violet.panel(center:[center.x,y,z],size:[size.x*0.62,min(42,size.y*0.10),1])
                    for glyph in 0..<4 {
                        let x = center.x+(Float(glyph)-1.5)*size.x*0.115
                        signs.panel(center:[x,y,z+0.6],size:[3,min(24,size.y*0.065),1])
                        signs.panel(center:[x+6,y+4,z+0.6],size:[11,3,1])
                    }
                }
                let roof = base+size.y+0.7
                if index.isMultiple(of:3) {
                    for side:Float in [-1,1] {
                        accents.panel(center:[center.x+side*size.x*0.38,roof,center.z],size:[2,1,size.z*0.76])
                        violet.panel(center:[center.x,roof,center.z+side*size.z*0.38],size:[size.x*0.76,1,2])
                    }
                }
                accents.panel(center:[center.x,roof,center.z],size:[size.x*0.055,1,size.z*0.055])
                if detail {
                    for side:Float in [-1,1] {
                        trim.box(center:[center.x+side*size.x*0.16,base+size.y*0.91,center.z],size:[size.x*0.09,size.y*0.055,size.z*0.14])
                    }
                    if index.isMultiple(of: 4) {
                        // Suspended display strips sit on the facade, clear of flight lanes.
                        let z = center.z+size.z*0.36+0.8
                        violet.panel(center:[center.x,base+size.y*0.48,z],size:[size.x*0.16,size.y*0.34,1])
                        for glyph in 0..<5 {
                            signs.panel(center:[center.x,base+size.y*(0.36+Float(glyph)*0.05),z+0.5],size:[size.x*0.09,3,1])
                        }
                    }
                }
            case .tatooine:
                // Terraced, eroded mesas rather than one pointed pyramid per cell.
                for layer in 0..<3 {
                    let width = 1-Float(layer)*0.18
                    let h = size.y*(layer == 0 ? 0.38 : 0.31)
                    let y = base+size.y*(layer == 0 ? 0.19 : (layer == 1 ? 0.535 : 0.845))
                    scenery[(style+layer)%3].frustum(center:[center.x,y,center.z],size:[size.x*width,h,size.z*width],top:0.79,sides:detail ? 8 : 6,rotation:Float(style)*0.25)
                }
                if detail {
                    // Pale horizontal strata remain inside each rock's broad lower tier.
                    for layer in 0..<4 {
                        let t = Float(layer)*0.17+0.12
                        let width:Float = t < 0.38 ? 0.96 : t < 0.69 ? 0.77:0.61
                        trim.frustum(center:[center.x,base+size.y*t,center.z],size:[size.x*width,size.y*0.012,size.z*width],top:0.99,sides:8,rotation:Float(style)*0.25)
                    }
                }
            case .hoth:
                let yaw = Float(index%7)*0.21
                scenery[style].frustum(center:[center.x,base+size.y*0.40,center.z],size:[size.x,size.y*0.80,size.z],top:0.72,sides:5,rotation:yaw)
                scenery[2].frustum(center:[center.x-size.x*0.08,base+size.y*0.84,center.z+size.z*0.05],size:[size.x*0.72,size.y*0.24,size.z*0.72],top:0.53,sides:5,rotation:yaw)
                if detail {
                    for crack in 0..<3 {
                        let x = center.x+(Float(crack)-1)*size.x*0.18
                        scenery[0].panel(center:[x,base+size.y*0.48,center.z+size.z*0.40],size:[size.x*0.025,size.y*0.50,1])
                    }
                }
            case .endor:
                // Redwood-scale bare trunks rise into a high, irregular canopy.
                // Every trunk, branch and crown remains in the collision envelope.
                let count = detail && index.isMultiple(of:4) ? 2 : 1
                for tree in 0..<count {
                    let sign:Float = tree == 0 ? -1:1
                    let x = center.x+(count == 1 ? 0:sign*size.x*0.17)
                    let z = center.z+(count == 1 ? 0:sign*size.z*0.10)
                    let h = size.y*(tree == 0 ? 1:0.88)
                    let trunkWidth = size.x*(count == 1 ? 0.22:0.17)
                    trim.frustum(center:[x,base+h*0.44,z],size:[trunkWidth,h*0.88,trunkWidth],top:0.48,sides:detail ? 9:6,rotation:Float(style)*0.3)
                    scenery[0].frustum(center:[x,base+h*0.05,z],size:[trunkWidth*1.65,h*0.10,trunkWidth*1.65],top:0.58,sides:6)
                    if detail {
                        for ridge in 0..<5 {
                            let angle = Float(ridge)*2 * .pi/5
                            let offset = SIMD3<Float>(cos(angle),0,sin(angle))*trunkWidth*0.32
                            scenery[2].frustum(center:[x+offset.x,base+h*0.33,z+offset.z],size:[trunkWidth*0.07,h*0.60,trunkWidth*0.07],top:0.45,sides:4)
                        }
                        for branch in 0..<3 {
                            let a = Float(branch)*2.1+Float(style)
                            let width = size.x*0.28
                            trim.box(center:[x+cos(a)*width*0.27,base+h*(0.68+Float(branch)*0.07),z+sin(a)*width*0.27],size:[width,h*0.012,trunkWidth*0.16],yaw:-a)
                        }
                    }
                    let phase = Float(index)*1.73+Float(tree)*2.1
                    for branchPlane in 0..<(detail ? 5:3) {
                        let a = phase+Float(branchPlane)*Float.pi/Float(detail ? 5:3)
                        let radius = size.x*(count == 1 ? 0.46:0.30)
                        foliage.softSprite(center:[x,base+h*0.65,z],right:[cos(a)*radius,0,sin(a)*radius],up:[0,h*0.30,0])
                    }
                    if detail && index.isMultiple(of: 5) {
                        // Low ferns and moss clusters are contained in the tree cell.
                        for fern in 0..<4 {
                            let a = Float(fern)*1.7
                            let fx = x+cos(a)*size.x*0.20, fz = z+sin(a)*size.z*0.20
                            let fy = surface.groundHeight(x:fx,z:fz)+2
                            scenery[1].dome(center:[fx,fy,fz],radius:[8,5,8],sides:6)
                        }
                    }
                }
            }
        }
        if planet == .coruscant {
            for lane in -24...24 {
                let x = Float(lane)*PlanetExploration.spacing
                lights.panel(center:[x-45,2,0],size:[3,1,23000])
                accents.panel(center:[x+45,2,0],size:[3,1,23000])
                signs.panel(center:[x,2,0],size:[3,1,23000])
                if lane.isMultiple(of:4) {
                    lights.panel(center:[0,2,x],size:[23000,1,4])
                    violet.panel(center:[0,3,x+35],size:[23000,1,4])
                    for crossing in -12...12 {
                        accents.panel(center:[Float(crossing)*960,2,x+16],size:[80,1,9])
                    }
                }
            }
        }
        // Landmark lights follow the terrain. The two occupied outpost envelopes are
        // unchanged, while each world's small shelters now have their own architecture.
        for (index,landmark) in surface.landmarks.enumerated() {
            let p = landmark.position, groundY = surface.groundHeight(x:landmark.position.x,z:landmark.position.z)
            for slice in 0..<32 {
                let a = Float(slice) * .pi * 2 / 32, b = Float(slice+1) * .pi * 2 / 32
                func ring(_ angle:Float,_ radius:Float) -> SIMD3<Float> {
                    let x = p.x+cos(angle)*radius, z = p.z+sin(angle)*radius
                    return [x,surface.groundHeight(x:x,z:z)+1.5,z]
                }
                accents.quad(ring(a,81),ring(a,86),ring(b,86),ring(b,81))
            }
            let marker = ModelEntity(mesh:.generateBox(size:[18,130,18]),materials:[activeLight])
            marker.position = p; marker.name = "Scout beacon \(index+1)"
            root.addChild(marker); markers.append(marker)
            for side:Float in [-1,1] {
                let c = SIMD3<Float>(p.x+side*65,groundY+18,p.z)
                if planet == .tatooine {
                    scenery[1].box(center:c-[0,9,0],size:[35,18,45])
                    scenery[1].dome(center:c,radius:[17.5,18,22.5])
                    trim.panel(center:c+[0,-7,22.6],size:[10,15,1])
                } else if planet == .endor {
                    trim.box(center:c-[0,4,0],size:[35,28,45])
                    scenery[1].frustum(center:c+[0,12,0],size:[35,12,45],top:0.3,sides:4,rotation:.pi/4)
                    signs.panel(center:c+[0,-3,22.6],size:[12,8,1])
                } else {
                    scenery[1].box(center:c-[0,3,0],size:[35,30,45])
                    scenery[2].box(center:c+[0,14,0],size:[33,8,43])
                    lights.panel(center:c+[0,3,22.6],size:[24,5,1])
                }
                lights.panel(center:[c.x,groundY+36.5,c.z],size:[22,1,32])
            }
        }
        func add(_ batch:Batch,_ name:String,_ material:any RealityKit.Material) {
            if let entity = batch.entity(name:name,material:material) { root.addChild(entity) }
        }
        let groundKind = planet == .tatooine ? "sand" : planet == .hoth ? "snow" : planet == .endor ? "moss":"rock"
        for i in 0..<terrain.count { add(terrain[i],"Terrain stratum \(i)",ScenicMaterials.terrain(color:groundColors[i],kind:groundKind,planet:planet.name,continuous:true,reducedDetail:reducedDetail)) }
        for i in 0..<scenery.count { add(scenery[i],"District \(i)",ScenicMaterials.terrain(color:colors[i],kind:planet == .endor ? "moss":planet == .hoth ? "snow":"rock",planet:planet.name,reducedDetail:reducedDetail)) }
        let trimColor:UIColor = planet == .endor ? Self.color(0.27,0.17,0.09) : planet == .tatooine ? Self.color(0.88,0.66,0.42) : Self.color(0.12,0.19,0.24)
        if planet == .endor {
            trim.uvs = trim.positions.map { [$0.x*0.06,$0.y*0.025] }
        }
        add(trim,"Structural trim",ScenicMaterials.terrain(color:trimColor,kind:planet == .endor ? "bark":"rock",planet:planet.name,reducedDetail:reducedDetail))
        if planet == .endor { add(foliage,"Redwood needles and branch silhouettes",ScenicMaterials.foliage()) }
        add(lights,"Window and path lights",Self.neon(planet == .tatooine ? .systemOrange : .cyan))
        add(accents,"Accent lights",Self.neon(planet == .endor ? .systemGreen : .systemPink))
        add(signs,"Amber signs",Self.neon(.init(red:1,green:0.65,blue:0.1,alpha:1)))
        add(violet,"Violet neon",Self.neon(.init(red:0.65,green:0.2,blue:1,alpha:1)))
        if planet == .coruscant {
            let mesh = MeshResource.generateBox(size:[12,5,25])
            let material = SimpleMaterial(color:.lightGray,roughness:0.4,isMetallic:true)
            for index in 0..<(reducedDetail ? 12 : 24) {
                let vehicle = ModelEntity(mesh:mesh,materials:[material])
                let lamp = ModelEntity(mesh:.generateBox(size:[8,2,2]),materials:[UnlitMaterial(color:.cyan)])
                lamp.position = [0,0,13]; vehicle.addChild(lamp)
                vehicle.name = "Sky traffic \(index+1)"; root.addChild(vehicle); traffic.append(vehicle)
            }
        }
    }
    /// A few prepared translucent meshes provide depth and light; they never stream
    /// around the player or add solid geometry to a cleared flight corridor.
    private func buildScenicAtmosphere() {
        let surface = PlanetExploration(planet:planet)
        var mist = Batch(), shafts = Batch(), details = Batch()
        let count = reducedDetail ? 8:18
        for index in 0..<count {
            let z = Float(9000-index*470)
            let side:Float = index.isMultiple(of:2) ? -1:1
            let x:Float
            switch planet {
            case .coruscant: x = side*Float(700+(index%4)*960)
            case .tatooine: x = surface.canyonCenter(z:z)+side*Float(320+(index%3)*180)
            case .hoth: x = surface.glacierCenter(z:z)+side*Float(380+(index%3)*240)
            case .endor: x = side*Float(220+(index%4)*480)
            }
            let ground = surface.groundHeight(x:x,z:z)
            if planet == .coruscant {
                let angle = Float(index)*2.399
                mist.softSprite(center:[x,100+Float(index%3)*90,z],right:[cos(angle)*600,0,sin(angle)*600],up:[0,110,0])
                if !reducedDetail {
                    // Distant rain is a single mesh of lit streaks, not one entity per drop.
                    for drop in 0..<30 {
                        let dx = Float(drop%6)*95-250, dz = Float(drop/6)*110-220
                        let p = SIMD3<Float>(x+dx,300+Float((drop*71)%500),z+dz)
                        details.quad(p,p+[2,-32,0],p+[3,-32,0],p+[1,0,0])
                    }
                }
            } else {
                let width:Float = planet == .endor ? 440:planet == .hoth ? 520:380
                let angle = Float(index)*2.399
                mist.softSprite(center:[x,ground+60,z],right:[cos(angle)*width,0,sin(angle)*width],up:[0,65,0])
                if index.isMultiple(of:3) && planet != .hoth {
                    let height:Float = planet == .endor ? 520:440
                    shafts.frustum(center:[x,ground+height*0.5,z],size:[90,height,90],top:0.12,sides:5)
                }
                if planet == .hoth && !reducedDetail {
                    for flake in 0..<12 {
                        let p = SIMD3<Float>(x+Float(flake%4)*85-120,ground+80+Float((flake*37)%220),z+Float(flake/4)*90)
                        details.quad(p-[1,1,0],p+[1,-1,0],p+[1,1,0],p+[-1,1,0])
                    }
                }
            }
        }
        let tint:UIColor = planet == .tatooine ? Self.color(0.92,0.67,0.36) : planet == .coruscant ? Self.color(0.24,0.16,0.38) : planet == .hoth ? Self.color(0.68,0.82,0.93) : Self.color(0.65,0.72,0.48)
        var fog = Self.neon(tint)
        if let texture = Self.softMistTexture { fog.color = .init(tint:tint,texture:.init(texture)) }
        fog.blending = .transparent(opacity:.init(floatLiteral:0.24))
        var ray = Self.neon(planet == .endor ? Self.color(0.92,0.86,0.53):Self.color(1,0.8,0.47))
        ray.blending = .transparent(opacity:.init(floatLiteral:0.045))
        var weather = Self.neon(planet == .coruscant ? Self.color(0.5,0.65,0.95):.white)
        weather.blending = .transparent(opacity:.init(floatLiteral:0.22))
        for (batch,name,material) in [(mist,"Low atmospheric mist",fog),(shafts,"Scattered sun shafts",ray),(details,"Distant weather particles",weather)] {
            if let entity = batch.entity(name:name,material:material) {
                entity.components.set(DynamicLightShadowComponent(castsShadow:false))
                root.addChild(entity)
                if name == "Distant weather particles" { weatherParticles = entity }
            }
        }
    }

    /// One prepared cloud mesh drifts with a bounded transform. The material
    /// handles cloud density and distant detail without changing the region mesh.
    private func buildCloudLayer() {
        var cloud = Batch()
        let count = reducedDetail ? 24:64
        let altitude:Float = planet == .hoth ? 3400:planet == .tatooine ? 2900:planet == .coruscant ? 1900:2100
        for index in 0..<count {
            let angle = Float(index)*2.399963
            let radial = sqrt((Float(index)+0.5)/Float(count))*11500
            let center = SIMD3<Float>(cos(angle)*radial,altitude+sin(Float(index)*1.73)*210,sin(angle)*radial)
            let size = Float(1000+(index*173)%950)
            cloud.softSprite(center:center,right:[cos(angle)*size,0,sin(angle)*size],up:[-sin(angle)*size*0.65,190,cos(angle)*size*0.65])
        }
        let color:UIColor = planet == .coruscant ? Self.color(0.28,0.24,0.37):planet == .tatooine ? Self.color(0.88,0.74,0.56):Self.color(0.88,0.92,0.88)
        if let entity = cloud.entity(name:"Prepared atmospheric cloud layer",material:ScenicMaterials.cloud(color:color,planet:planet.name,reducedDetail:reducedDetail)) {
            entity.components.set(DynamicLightShadowComponent(castsShadow:false))
            root.addChild(entity); cloudLayer = entity
        }
    }

    private func buildSkyports() {
        guard planet == .coruscant else { return }
        var decks = Batch()
        for station in CityStation.allCases {
            let center = station.position
            decks.box(center:center-[0,17,0],size:[110,4,110])
            var outline = Batch()
            for side:Float in [-1,1] {
                outline.box(center:[side*54,-14.5,0],size:[2,0.7,110])
                outline.box(center:[0,-14.5,side*54],size:[110,0.7,2])
                // Approach stripes stay on the deck and leave the hover centre clear.
                outline.box(center:[side*13,-14.5,0],size:[2,0.7,34])
                outline.box(center:[side*51,-0.5,51],size:[2,28,2])
                outline.box(center:[side*51,14,51],size:[7,1,7])
            }
            outline.box(center:[0,-14.5,0],size:[24,0.7,2])
            guard let marker = outline.entity(name:"Skyport \(station.rawValue) outline and beacons",material:idleStationLight) else { continue }
            marker.position = center
            root.addChild(marker)
            jobMarkers[station] = marker
            var approach = Batch()
            approach.box(center:[0,100,0],size:[4,150,4])
            approach.box(center:[0,150,0],size:[110,4,4])
            approach.box(center:[0,150,0],size:[4,4,110])
            if let beacon = approach.entity(name:"Skyport approach beacon",material:targetStationLight) {
                beacon.position = center; beacon.isEnabled = false
                root.addChild(beacon); approachMarkers[station] = beacon
            }
        }
        if let deck = decks.entity(name:"Coruscant skyport service decks",material:SimpleMaterial(color:Self.color(0.08,0.12,0.18),roughness:0.8,isMetallic:true)) {
            root.addChild(deck)
        }
    }

    /// All geometry is prepared with the planet. A job only changes five cached materials.
    func updateJobs(target: CityStation?, servicing: Bool) {
        guard planet == .coruscant,
              target != lastJobTarget || servicing != lastJobServicing else { return }
        for (station,marker) in jobMarkers {
            let material = station == target ? (servicing ? servicingStationLight : targetStationLight) : idleStationLight
            marker.model?.materials = [material]
            approachMarkers[station]?.isEnabled = station == target && !servicing
        }
        lastJobTarget = target
        lastJobServicing = servicing
    }

    private func buildInhabitants() {
        guard let species = PlanetInhabitant.resident(on:planet) else { return }
        let surface = PlanetExploration(planet:planet)
        for (siteIndex,site) in PlanetInhabitant.sites(on:planet,reduced:reducedDetail).enumerated() {
            var body = Batch(), clothes = Batch(), dark = Batch(), eyes = Batch()
            let count = species == .wampa ? 2 : 4
            for index in 0..<count {
                let x = Float(index)*4.5-Float(count-1)*2.25
                let z:Float = index.isMultiple(of:2) ? -3:3
                let ground = surface.groundHeight(x:site.x+x,z:site.z+z)-site.y
                let origin = SIMD3<Float>(x,ground,z)
                func p(_ x:Float,_ y:Float,_ z:Float) -> SIMD3<Float> { origin+SIMD3<Float>(x,y,z) }
                switch species {
                case .ewok:
                    body.ellipsoid(center:p(0,1.2,0),radius:[0.68,1.05,0.52])
                    body.ellipsoid(center:p(0,2.5,0),radius:[0.68,0.68,0.58])
                    clothes.ellipsoid(center:p(0,2.3,0.14),radius:[0.76,0.73,0.52])
                    body.ellipsoid(center:p(0,2.45,-0.38),radius:[0.50,0.46,0.32])
                    for side:Float in [-1,1] {
                        body.ellipsoid(center:p(side*0.59,2.95,0),radius:[0.3,0.34,0.18])
                        body.ellipsoid(center:p(side*0.76,1.5,0),radius:[0.25,0.7,0.25])
                        body.ellipsoid(center:p(side*0.34,0.28,-0.1),radius:[0.28,0.33,0.42])
                        dark.ellipsoid(center:p(side*0.2,2.56,-0.67),radius:[0.065,0.07,0.035])
                    }
                    dark.ellipsoid(center:p(0,2.38,-0.71),radius:[0.10,0.075,0.05])
                    clothes.box(center:p(1,1.15,-0.2),size:[0.06,2.3,0.06])
                case .jawa:
                    clothes.frustum(center:p(0,1.2,0),size:[1.6,2.4,1.3],top:0.5,sides:10)
                    clothes.ellipsoid(center:p(0,2.3,0),radius:[0.64,0.72,0.60])
                    dark.ellipsoid(center:p(0,2.30,-0.48),radius:[0.44,0.47,0.18])
                    for side:Float in [-1,1] {
                        eyes.ellipsoid(center:p(side*0.18,2.35,-0.66),radius:[0.07,0.07,0.025])
                        clothes.ellipsoid(center:p(side*0.62,1.55,0),radius:[0.23,0.62,0.25])
                    }
                    dark.box(center:p(0,1.2,-0.64),size:[1.3,0.14,0.12])
                    body.box(center:p(0.35,1.35,-0.73),size:[0.3,0.34,0.12])
                case .wampa:
                    body.ellipsoid(center:p(0,3.3,0),radius:[1.6,2.5,1.0])
                    body.ellipsoid(center:p(0,5.7,-0.2),radius:[1.15,1.1,0.85])
                    for side:Float in [-1,1] {
                        body.ellipsoid(center:p(side*1.65,3,0),radius:[0.62,2,0.66])
                        body.ellipsoid(center:p(side*0.85,0.9,0),radius:[0.66,1.1,0.85])
                        dark.frustum(center:p(side*1.1,6.0,0),size:[0.5,1.2,0.55],top:0.10,sides:6)
                        dark.ellipsoid(center:p(side*0.4,5.9,-0.95),radius:[0.14,0.13,0.06])
                        for claw in 0..<3 {
                            dark.frustum(center:p(side*1.7+Float(claw-1)*0.18,1.0,-0.52),size:[0.10,0.44,0.12],top:0.08,sides:5)
                        }
                    }
                    dark.box(center:p(0,5.15,-0.94),size:[0.7,0.20,0.1])
                }
            }
            let group = Entity(); group.name = "\(species.label) camp \(siteIndex+1)"; group.position = site
            let fur:UIColor = species == .wampa ? .init(white:0.91,alpha:1):.init(red:0.42,green:0.26,blue:0.12,alpha:1)
            let robe:UIColor = species == .ewok ? .init(red:0.56,green:0.33,blue:0.16,alpha:1):.init(red:0.23,green:0.11,blue:0.06,alpha:1)
            for (batch,name,material) in [(body,"Fur and skin",SimpleMaterial(color:fur,roughness:1,isMetallic:false) as any RealityKit.Material),(clothes,"Hoods and robes",SimpleMaterial(color:robe,roughness:1,isMetallic:false)),(dark,"Faces and horns",SimpleMaterial(color:.init(white:0.035,alpha:1),roughness:1,isMetallic:false)),(eyes,"Glowing Jawa eyes",Self.neon(.yellow))] {
                if let entity = batch.entity(name:name,material:material) { group.addChild(entity) }
            }
            root.addChild(group); residentGroups.append((group,site))
        }
    }
    private static let softMistTexture:TextureResource? = {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = false
        let image = UIGraphicsImageRenderer(size:CGSize(width:128,height:128),format:format).image { renderer in
            let colors = [UIColor.white.withAlphaComponent(0.55).cgColor,UIColor.white.withAlphaComponent(0.18).cgColor,UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors,locations:[0,0.45,1]) else { return }
            renderer.cgContext.drawRadialGradient(gradient,startCenter:CGPoint(x:64,y:64),startRadius:0,endCenter:CGPoint(x:64,y:64),endRadius:64,options:[])
        }
        guard let cg = image.cgImage else { return nil }
        return try? TextureResource.generate(from:cg,options:.init(semantic:.color))
    }()
    private static func color(_ red:CGFloat,_ green:CGFloat,_ blue:CGFloat) -> UIColor { UIColor(red:red,green:green,blue:blue,alpha:1) }
    private static func neon(_ color:UIColor) -> UnlitMaterial {
        var material = UnlitMaterial(color:color)
        material.faceCulling = .none
        return material
    }
    func update(camera:SIMD3<Float>,dt:Float,passed:Int,surfaceTime:Float?=nil,aircraftPosition:SIMD3<Float>?=nil) {
        sky.position = camera
        time += min(dt,0.1)
        updateCanyonLife(viewer:aircraftPosition ?? camera)
        wildlife?.update(time:surfaceTime ?? time,viewer:aircraftPosition ?? camera)
        updateSandWash(position:aircraftPosition)
        mirage?.update(time:surfaceTime ?? time)
        cloudLayer?.position = [sin(time*0.013)*180,0,cos(time*0.009)*120]
        // Move one prepared batch; individual drops/flakes never create entities.
        if let weatherParticles {
            let speed: Float = planet == .coruscant ? 130 : 8
            weatherParticles.position.y = -(time * speed).truncatingRemainder(dividingBy: 100)
        }
        if passed != lastPassed {
            for (index,marker) in markers.enumerated() {
                marker.model?.materials = [index < passed ? visitedLight : activeLight]
                marker.isEnabled = index <= passed
            }
            lastPassed = passed
        }
        for (index,resident) in residentGroups.enumerated() {
            let phase = time*0.6+Float(index)*1.8
            resident.0.position = resident.1+SIMD3<Float>(sin(phase)*0.6,0,cos(phase)*0.5)
            resident.0.orientation = simd_quatf(angle:sin(phase*0.7)*0.12,axis:[0,1,0])
        }
        for (index,vehicle) in traffic.enumerated() {
            let sign:Float = index.isMultiple(of:2) ? 1 : -1
            let lane = Float(index%3-1)*1920+sign*35
            let z = (Float(index)*1290+time*110).truncatingRemainder(dividingBy:22000)-11000
            vehicle.position = [lane,Float(160+index%3*180),z*sign]
        }
    }
}
