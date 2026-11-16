import RealityKit
import UIKit
import Metal
import simd

private struct SkyPoint {
    let position:SIMD3<Double>
    let magnitude:Double
    let distance:Double
    let rank:Int
}

/// Three draw batches. Vertex buffers are updated in place; flight never creates a star entity/mesh.
@MainActor
private final class MutableSkyBatch {
    let mesh:LowLevelMesh
    let entity:ModelEntity
    var points:[SkyPoint] = []
    init(color:UIColor) throws {
        let capacity = 3000
        let descriptor = LowLevelMesh.Descriptor(vertexCapacity:capacity*4,
            vertexAttributes:[.init(semantic:.position,format:.float3,offset:0)],
            vertexLayouts:[.init(bufferIndex:0,bufferStride:MemoryLayout<SIMD3<Float>>.stride)],indexCapacity:capacity*6,indexType:.uint32)
        mesh = try LowLevelMesh(descriptor:descriptor)
        mesh.withUnsafeMutableIndices { raw in
            let indices = raw.bindMemory(to:UInt32.self)
            for i in 0..<capacity {
                let v = UInt32(i*4), o = i*6
                indices[o] = v; indices[o+1] = v+1; indices[o+2] = v+2
                indices[o+3] = v; indices[o+4] = v+2; indices[o+5] = v+3
            }
        }
        mesh.parts.replaceAll([.init(indexCount:0,bounds:BoundingBox(min:[-48000,-48000,-48000],max:[48000,48000,48000]))])
        var material = UnlitMaterial(color:color); material.faceCulling = .none
        entity = ModelEntity(mesh:try MeshResource(from:mesh),materials:[material])
        entity.name = "Catalogue star batch"
    }
    func update(observer:SIMD3<Double>,limit:Int,lens:SIMD3<Float>?) {
        var count = 0
        mesh.withUnsafeMutableBytes(bufferIndex:0) { raw in
            let vertices = raw.bindMemory(to:SIMD3<Float>.self)
            for point in points where point.rank < limit {
                let delta = point.position-observer
                let distance = max(0.0001,simd_length(delta))
                let direction = StarSkyGeometry.direction(position:point.position,observer:observer,lens:lens)
                let center = direction*46000
                let right = simd_normalize(simd_cross(direction,abs(direction.y)>0.96 ? SIMD3<Float>(1,0,0):[0,1,0]))
                let up = simd_normalize(simd_cross(right,direction))
                let magnitude = point.magnitude+5*log10(distance/point.distance)
                let size = 20*Float(min(28,max(0.7,8*pow(10,-0.15*(magnitude+1)))))
                let o = count*4
                vertices[o] = center+up*size; vertices[o+1] = center+right*size
                vertices[o+2] = center-up*size; vertices[o+3] = center-right*size
                count += 1
            }
        }
        mesh.parts[0].indexCount = count*6
    }
}

@MainActor
enum UniverseMeshes {
    static func ring(inner:Float,outer:Float,segments:Int = 96) -> MeshResource {
        var positions:[SIMD3<Float>] = [], indices:[UInt32] = []
        for i in 0..<segments {
            let a = Float(i)*2 * .pi/Float(segments),b = Float(i+1)*2 * .pi/Float(segments), v = UInt32(positions.count)
            positions += [[cos(a)*inner,0,sin(a)*inner],[cos(a)*outer,0,sin(a)*outer],[cos(b)*outer,0,sin(b)*outer],[cos(b)*inner,0,sin(b)*inner]]
            indices += [v,v+1,v+2,v,v+2,v+3]
        }
        var descriptor = MeshDescriptor(name:"Prepared orbit ring")
        descriptor.positions = .init(positions); descriptor.normals = .init(Array(repeating:SIMD3<Float>(0,1,0),count:positions.count))
        descriptor.primitives = .triangles(indices)
        return (try? MeshResource.generate(from:[descriptor])) ?? .generateSphere(radius:outer)
    }
    static func galaxyIcon(_ galaxy:Galaxy) -> MeshResource {
        var positions:[SIMD3<Float>] = [],indices:[UInt32] = []
        for i in 0..<240 {
            let r = sqrt((Float(i)+0.5)/240)*1.25
            let angle = galaxy == .magellanic ? Float(i)*2.3999632 : r*7+Float(i%3)*2.0944+sin(Float(i)*7.3)*0.15
            let center = SIMD3<Float>(cos(angle)*r,Float(i%5)*0.008,sin(angle)*r*(galaxy == .magellanic ? 0.65:1))
            let size:Float = 0.018+Float(i%4)*0.008, v = UInt32(positions.count)
            positions += [center+[-size,0,-size],center+[size,0,-size],center+[size,0,size],center+[-size,0,size]]
            indices += [v,v+1,v+2,v,v+2,v+3]
        }
        var descriptor = MeshDescriptor(name:"Batched galaxy spiral")
        descriptor.positions = .init(positions); descriptor.primitives = .triangles(indices)
        return (try? MeshResource.generate(from:[descriptor])) ?? .generateSphere(radius:1)
    }
    static func material(_ color:UIColor,opacity:Float = 1) -> UnlitMaterial {
        var m = UnlitMaterial(color:color); m.faceCulling = .none
        if opacity < 1 { m.blending = .transparent(opacity:.init(floatLiteral:opacity)) }
        return m
    }
}

@MainActor
final class UniverseRenderer {
    let root = Entity()
    private let sky = Entity()
    private let blackHole = Entity()
    private let disc = Entity()
    private let solar = Entity()
    private let landscape = Entity()
    private var landscapeName: String?
    private var earthWildlife:EarthWildlifeRenderer?
    private var wildlifeReduced:Bool?
    private var aetherWorld: Entity?
    private var aetherPreparation: Task<Void,Never>?
    private var cloudCyclone: Entity?
    private var planetDetails: [PlanetOrbitDetail] = []
    private let courseMarker:ModelEntity
    private var batches:[MutableSkyBatch] = []
    private var fields:[Galaxy:[[SkyPoint]]] = [:]
    private var lastGalaxy:Galaxy?
    private var clock:Float = 0
    private var skyClock:Float = 1
    init() {
        root.name = "Prepared universe sectors"
        for color in [UIColor(red:0.72,green:0.85,blue:1,alpha:1),.white,UIColor(red:1,green:0.60,blue:0.30,alpha:1)] {
            if let batch = try? MutableSkyBatch(color:color) { sky.addChild(batch.entity); batches.append(batch) }
        }
        var real = [[SkyPoint](),[SkyPoint](),[SkyPoint]()]
        for (rank,star) in StarCatalogue.all.enumerated() {
            let group = star.bv < 0.15 ? 0 : star.bv > 0.85 ? 2:1
            real[group].append(.init(position:star.positionPC,magnitude:star.magnitude,distance:star.distancePC,rank:rank))
        }
        fields[.milkyWay] = real
        for (g,galaxy) in Galaxy.allCases.enumerated() where galaxy != .milkyWay {
            var groups = [[SkyPoint](),[SkyPoint](),[SkyPoint]()]
            for i in 0..<3000 {
                let t = Double(i)+Double(g)*123.5, y = sin(t*7.31)*0.95
                let a = t*2.3999632297, r = sqrt(max(0,1-y*y)), distance = 60+Double(i%179)
                let point = SIMD3<Double>(cos(a)*r,y,sin(a)*r)*distance
                groups[(i+g)%3].append(.init(position:point,magnitude:Double(i%60)/10,distance:distance,rank:i))
            }
            fields[galaxy] = groups
        }
        root.addChild(sky)
        let shadow = ModelEntity(mesh:.generateSphere(radius:150),materials:[UniverseMeshes.material(.black)])
        blackHole.addChild(shadow)
        for (i,radii) in [(Float(158),Float(178)),(185,240),(250,420),(430,700)].enumerated() {
            let ring = ModelEntity(mesh:UniverseMeshes.ring(inner:radii.0,outer:radii.1),materials:[UniverseMeshes.material(i<2 ? .systemYellow:.systemOrange,opacity:i<2 ? 1:0.42)])
            disc.addChild(ring)
        }
        disc.orientation = simd_quatf(angle:0.33,axis:[1,0,0]); blackHole.addChild(disc)
        let lens = ModelEntity(mesh:UniverseMeshes.ring(inner:154,outer:164),materials:[UniverseMeshes.material(.white)])
        lens.orientation = simd_quatf(angle:.pi/2,axis:[1,0,0]); blackHole.addChild(lens)
        for side:Float in [-1,1] {
            let jet = ModelEntity(mesh:.generateCone(height:1100, radius:45),materials:[UniverseMeshes.material(.cyan,opacity:0.18)])
            jet.position.y = side*650; if side < 0 { jet.orientation = simd_quatf(angle:.pi,axis:[1,0,0]) }; blackHole.addChild(jet)
        }
        root.addChild(blackHole)
        for body in SolarBody.all {
            let color = UIColor(red:CGFloat(body.tint.x),green:CGFloat(body.tint.y),blue:CGFloat(body.tint.z),alpha:1)
            let accepted = ["Mercury","Venus","Earth","Mars","Jupiter"].contains(body.name)
            let artwork = SolarArtwork.material(body:body,fallback:color)
            let paint: any RealityKit.Material = accepted ? ScenicMaterials.globe(artwork,planet:body.name) : artwork
            let sphere = ModelEntity(mesh:.generateSphere(radius:body.radius),materials:[paint])
            sphere.position = body.position; sphere.name = body.name; solar.addChild(sphere)
            if accepted {
                planetDetails.append(PlanetOrbitDetail(entity:sphere,name:body.name,radius:body.radius))
                PlanetOrbitAtmosphere.add(to:sphere,name:body.name,radius:body.radius,tint:color)
            }
            if body.name == "Saturn" {
                let ring = ModelEntity(mesh:UniverseMeshes.ring(inner:135,outer:210),materials:[UniverseMeshes.material(.init(red:0.74,green:0.63,blue:0.44,alpha:1),opacity:0.7)])
                ring.orientation = simd_quatf(angle:0.32,axis:[1,0,0]); sphere.addChild(ring)
            }

        }
        root.addChild(solar)
        root.addChild(landscape)
        courseMarker = ModelEntity(mesh:UniverseMeshes.ring(inner:18,outer:21),materials:[UniverseMeshes.material(.cyan)])
        root.addChild(courseMarker); root.isEnabled = false
        prepareAetherPlanet()
    }
    func prepareAetherPlanet() {
        guard aetherWorld == nil, aetherPreparation == nil else { return }
        if AetherPlanet.enabled {
            AetherPlanetRenderer.ready = false
            aetherPreparation = Task { [weak self] in
                let diagnosticStart = AetherReleaseProbe.shared == nil ? 0 : CACurrentMediaTime()
                let result = await Task.detached(priority:.userInitiated) { AetherPlanet.prepared }.value
                guard !Task.isCancelled, let self else { return }
                do {
                    self.aetherWorld = try AetherPlanetRenderer.make(result.get(),enhanced:AetherPlanet.flag("aetherSurfaceEnabled"))
                    AetherPlanetRenderer.failure = nil; AetherPlanetRenderer.ready = true
                    AetherReleaseProbe.shared?.event("aetherReachPreparationSeconds",seconds:CACurrentMediaTime()-diagnosticStart)
                } catch { AetherPlanetRenderer.failure = error.localizedDescription }
            }
        }

    }
    deinit { aetherPreparation?.cancel() }
    func update(flight:UniverseFlight,active:Bool,camera:PerspectiveCamera,state:FlightState,dt:Float,reduced:Bool,target:SIMD3<Float>?) {
        root.isEnabled = active; guard active else { return }
        clock += dt; skyClock += dt
        sky.position = camera.position
        if lastGalaxy != flight.galaxy {
            if let field = fields[flight.galaxy] { for (batch,points) in zip(batches,field) { batch.points = points } }
            lastGalaxy = flight.galaxy; skyClock = 1
        }
        if skyClock >= (reduced ? 0.25:0.1) {
            let observer = flight.catalogVisible ? flight.observerPC(local:state.position):.zero
            for batch in batches { batch.update(observer:observer,limit:reduced ? 1000:3000,lens:flight.blackHole.map { $0.center-camera.position }) }
            skyClock = 0
        }
        if landscapeName != flight.surfaceBody?.name {
            earthWildlife=nil;wildlifeReduced=nil
            landscape.children.removeAll()
            if let body = flight.surfaceBody {
                if body.name == AetherPlanet.name {
                    if let aetherWorld { landscape.addChild(aetherWorld) }
                } else { SolarArtwork.populate(landscape,body:body) }
            }
            cloudCyclone = landscape.findEntity(named: "Jupiter rotating cyclone")
            landscapeName = flight.surfaceBody?.name
        }
        if flight.surfaceBody?.name == "Earth" {
            if earthWildlife == nil || wildlifeReduced != reduced {
                earthWildlife?.root.removeFromParent()
                let wildlife=EarthWildlifeRenderer(reduced:reduced)
                landscape.addChild(wildlife.root);earthWildlife=wildlife;wildlifeReduced=reduced
            }
            earthWildlife?.update(time:clock,viewer:state.position)
        }
        cloudCyclone?.orientation = simd_quatf(angle: clock * 0.018, axis: [0,1,0])
        landscape.isEnabled = flight.surfaceBody != nil && !flight.jumping
        sky.isEnabled = !flight.jumping && (flight.surfaceBody == nil || flight.surfaceBody?.name == "Moon" || flight.surfaceBody?.name == "Mercury")
        blackHole.isEnabled = flight.blackHole != nil && !flight.jumping
        if let hole = flight.blackHole { blackHole.position = hole.center }
        disc.orientation = simd_quatf(angle:0.33,axis:[1,0,0])*simd_quatf(angle:clock*0.3,axis:[0,1,0])
        solar.isEnabled = flight.sector == .solarSystem && flight.surfaceBody == nil && !flight.jumping
        if solar.isEnabled { for detail in planetDetails { detail.update(camera:camera.position,reduced:reduced) } }
        courseMarker.isEnabled = target.map { simd_distance($0,state.position)>1 } == true && !flight.jumping
        if let target { courseMarker.position = state.position+simd_normalize(target-state.position)*300; courseMarker.look(at:camera.position,from:courseMarker.position,relativeTo:nil); courseMarker.orientation *= simd_quatf(angle:.pi/2,axis:[1,0,0]) }
    }
}

@MainActor
private enum SolarArtwork {
    static func material(body:SolarBody,fallback:UIColor) -> UnlitMaterial {
        // Bundled, credited 1.4–2K NASA maps with generated mipmaps. The runtime
        // never downloads imagery or substitutes low-resolution placeholders.
        if ["Earth", "Mars", "Venus", "Jupiter"].contains(body.name),
           let cg = UIImage(named: "Orbital" + body.name)?.cgImage,
           let texture = try? TextureResource(image: cg, options: .init(semantic: .color)) {
            var paint = UniverseMeshes.material(.white)
            paint.color = .init(tint: .white, texture: .init(texture))
            return paint
        }
        let image = UIGraphicsImageRenderer(size:CGSize(width:1024,height:512)).image { renderer in
            let ctx = renderer.cgContext
            fallback.setFill(); ctx.fill(CGRect(x:0,y:0,width:1024,height:512))
            func polygon(_ points:[CGPoint],color:UIColor) {
                guard let first = points.first else { return }
                ctx.beginPath(); ctx.move(to:first)
                points.dropFirst().forEach { ctx.addLine(to:$0) }; ctx.closePath(); ctx.setFillColor(color.cgColor); ctx.fillPath()
            }
            if body.name == "Earth" {
                UIColor(red:0.025,green:0.18,blue:0.42,alpha:1).setFill(); ctx.fill(CGRect(x:0,y:0,width:1024,height:512))
                // Original simplified longitude/latitude silhouettes, not a single green shell.
                let continents:[[(Double,Double)]] = [
                    [(-168,70),(-140,69),(-126,55),(-124,40),(-112,28),(-98,18),(-84,10),(-78,9),(-83,24),(-66,44),(-54,51),(-66,62),(-99,76),(-135,72)],
                    [(-81,12),(-64,10),(-50,1),(-35,-6),(-42,-23),(-55,-38),(-69,-55),(-76,-30),(-80,-4)],
                    [(-53,82),(-20,76),(-40,60),(-55,62),(-65,75)],
                    [(-10,36),(-17,16),(-10,5),(9,4),(15,-12),(20,-35),(34,-31),(50,12),(42,30),(25,32),(10,37)],
                    [(-10,36),(-10,58),(10,71),(30,70),(50,60),(85,76),(130,70),(178,65),(160,45),(140,38),(130,23),(110,3),(100,5),(78,8),(68,25),(43,12),(33,31),(25,40),(4,43)],
                    [(113,-22),(130,-12),(143,-11),(153,-26),(146,-39),(129,-34),(115,-35)],
                    [(47,-13),(51,-16),(48,-26),(44,-23)],[(130,33),(142,42),(145,45),(140,35)],
                    [(-8,50),(-2,59),(1,52)],[(166,-34),(178,-38),(169,-47)]]
                for continent in continents {
                    let pts = continent.map { CGPoint(x:($0.0+180)/360*1024,y:(90-$0.1)/180*512) }
                    polygon(pts,color:UIColor(red:0.25,green:0.42,blue:0.22,alpha:1))
                }
                polygon([CGPoint(x:490,y:165),CGPoint(x:575,y:160),CGPoint(x:600,y:202),CGPoint(x:500,y:215)],color:UIColor(red:0.66,green:0.52,blue:0.29,alpha:1))
                UIColor(white:0.91,alpha:1).setFill(); ctx.fill(CGRect(x:0,y:490,width:1024,height:22))
                for i in 0..<28 {
                    let x = CGFloat((i*173)%1024), y = CGFloat((i*89)%450)
                    ctx.setFillColor(UIColor.white.withAlphaComponent(0.12).cgColor)
                    ctx.fillEllipse(in:CGRect(x:x,y:y,width:90,height:9))
                }
            } else if body.isCloudWorld || body.name == "Venus" {
                for row in 0..<128 {
                    let latitude = CGFloat(row)*4
                    let wave = sin(Double(row)*0.47)*0.12+sin(Double(row)*0.11)*0.08
                    ctx.setFillColor(fallback.withAlphaComponent(CGFloat(0.25+wave)).cgColor)
                    ctx.setBlendMode(row.isMultiple(of:2) ? .screen:.multiply)
                    ctx.fill(CGRect(x:0,y:latitude,width:1024,height:4))
                }
                ctx.setBlendMode(.normal)
                if body.name == "Jupiter" {
                    ctx.setFillColor(UIColor(red:0.65,green:0.27,blue:0.12,alpha:0.8).cgColor)
                    ctx.fillEllipse(in:CGRect(x:640,y:320,width:95,height:38))
                }
            } else {
                for i in 0..<250 {
                    let x = CGFloat((i*173)%1024), y = CGFloat((i*89)%512), r = CGFloat(3+i%17)
                    ctx.setStrokeColor(UIColor(white:0.1,alpha:0.2).cgColor); ctx.setLineWidth(2)
                    ctx.strokeEllipse(in:CGRect(x:x,y:y,width:r*2,height:r))
                    ctx.setFillColor(UIColor.white.withAlphaComponent(0.04).cgColor); ctx.fillEllipse(in:CGRect(x:x,y:y,width:r*2,height:r))
                }
                if body.name == "Mars" { UIColor.white.setFill(); ctx.fill(CGRect(x:0,y:0,width:1024,height:15)) }
            }
        }
        var paint = UniverseMeshes.material(.white)
        if let cg = image.cgImage, let texture = try? TextureResource.generate(from:cg,options:.init(semantic:.color)) {
            paint.color = .init(tint:.white,texture:.init(texture))
        }
        return paint
    }
    /// Original native geometry for the selected expedition worlds. Small repeating
    /// details are merged per material; no content is streamed while flying.
    private struct ExpeditionBatch {
        var positions:[SIMD3<Float>] = []
        var normals:[SIMD3<Float>] = []
        mutating func triangle(_ a:SIMD3<Float>,_ b:SIMD3<Float>,_ c:SIMD3<Float>) {
            let cross = simd_cross(b-a,c-a)
            guard simd_length_squared(cross)>0.001 else { return }
            positions += [a,b,c]
            normals += Array(repeating:simd_normalize(cross),count:3)
        }
        mutating func quad(_ a:SIMD3<Float>,_ b:SIMD3<Float>,_ c:SIMD3<Float>,_ d:SIMD3<Float>) {
            triangle(a,b,c); triangle(a,c,d)
        }
        mutating func smoothTriangle(_ a:SIMD3<Float>,_ b:SIMD3<Float>,_ c:SIMD3<Float>,_ na:SIMD3<Float>,_ nb:SIMD3<Float>,_ nc:SIMD3<Float>) {
            guard simd_length_squared(simd_cross(b-a,c-a))>0.001 else { return }
            positions += [a,b,c]; normals += [na,nb,nc]
        }
        mutating func box(_ center:SIMD3<Float>,_ size:SIMD3<Float>) {
            let a = center-size/2, b = center+size/2
            quad([a.x,b.y,a.z],[a.x,b.y,b.z],[b.x,b.y,b.z],[b.x,b.y,a.z])
            quad([a.x,a.y,a.z],[b.x,a.y,a.z],[b.x,a.y,b.z],[a.x,a.y,b.z])
            quad([a.x,a.y,a.z],[a.x,b.y,a.z],[b.x,b.y,a.z],[b.x,a.y,a.z])
            quad([b.x,a.y,b.z],[b.x,b.y,b.z],[a.x,b.y,b.z],[a.x,a.y,b.z])
            quad([a.x,a.y,b.z],[a.x,b.y,b.z],[a.x,b.y,a.z],[a.x,a.y,a.z])
            quad([b.x,a.y,a.z],[b.x,b.y,a.z],[b.x,b.y,b.z],[b.x,a.y,b.z])
        }
        mutating func frustum(_ center:SIMD3<Float>,radius:Float,height:Float,top:Float,sides:Int = 8) {
            for i in 0..<sides {
                let a = Float(i)*2 * .pi/Float(sides), b = Float(i+1)*2 * .pi/Float(sides)
                let lowA = center+SIMD3<Float>(cos(a)*radius,-height/2,sin(a)*radius)
                let lowB = center+SIMD3<Float>(cos(b)*radius,-height/2,sin(b)*radius)
                let highA = center+SIMD3<Float>(cos(a)*radius*top,height/2,sin(a)*radius*top)
                let highB = center+SIMD3<Float>(cos(b)*radius*top,height/2,sin(b)*radius*top)
                quad(lowA,highA,highB,lowB)
                triangle(center+[0,height/2,0],highB,highA)
            }
        }
        mutating func ellipsoid(_ center:SIMD3<Float>,_ scale:SIMD3<Float>,billow:Float = 0,seed:Float = 0) {
            for row in 0..<6 { for column in 0..<10 {
                let a = -Float.pi/2+Float(row)*Float.pi/6, b = a+Float.pi/6
                let c = Float(column)*2 * .pi/10, d = c+2 * .pi/10
                func point(_ e:Float,_ t:Float) -> SIMD3<Float> {
                    // All longitudes must meet at the same pole. Varying the
                    // pole height by longitude pinches the cap into star points.
                    let poleFade = cos(e)*cos(e)
                    let ripple = 1+billow*poleFade*(0.7*sin(t*3+seed+sin(e*4))+0.3*sin(t*7+e*5-seed))
                    return center+scale*SIMD3<Float>(cos(e)*cos(t),sin(e),cos(e)*sin(t))*ripple
                }
                let p0 = point(a,c), p1 = point(b,c), p2 = point(b,d), p3 = point(a,d)
                func normal(_ p:SIMD3<Float>) -> SIMD3<Float> { simd_normalize((p-center)/(scale*scale)) }
                smoothTriangle(p0,p1,p2,normal(p0),normal(p1),normal(p2))
                smoothTriangle(p0,p2,p3,normal(p0),normal(p2),normal(p3))
            } }
        }
        @MainActor func append(to root:Entity,name:String,color:UIColor,unlit:Bool = false,opacity:Float = 1,kind:String = "rock",planet:String? = nil,continuous:Bool = false) {
            guard !positions.isEmpty else { return }
            var descriptor = MeshDescriptor(name:name)
            descriptor.positions = .init(positions); descriptor.normals = .init(normals)
            descriptor.textureCoordinates = .init(positions.map { SIMD2<Float>($0.x/180,$0.z/180) })
            descriptor.primitives = .triangles(Array(0..<UInt32(positions.count)))
            guard let resource = try? MeshResource.generate(from:[descriptor]) else { return }
            let paint:any RealityKit.Material
            if unlit { paint = UniverseMeshes.material(color,opacity:opacity) }
            else if kind == "water" {
                paint = ScenicMaterials.water(color:color)
            } else { paint = ScenicMaterials.terrain(color:color,kind:kind,planet:planet ?? root.name.split(separator:" ").first.map(String.init),continuous:continuous) }
            let entity = ModelEntity(mesh:resource,materials:[paint]); entity.name = name
            if unlit || kind == "cloud" || kind == "water" { entity.components.set(DynamicLightShadowComponent(castsShadow:false)) }
            root.addChild(entity)
        }
    }
    private static func populateExpedition(_ root:Entity,body:SolarBody) {
        root.name = body.name + " scenic expedition"
        let field = SolarLandscape(body:body)
        var skyPaint = expeditionSky(body)
        skyPaint.faceCulling = .front
        let sky = ModelEntity(mesh:.generateSphere(radius:60000),materials:[skyPaint]); sky.name = "Expedition atmosphere"
        sky.components.set(DynamicLightShadowComponent(castsShadow:false))
        root.addChild(sky)
        if body.name == "Jupiter" { populateJupiter(root); return }
        var terrain = Array(repeating:ExpeditionBatch(),count:8)
        let divisions = SolarLandscape.scenicDivisions, step = SolarLandscape.scenicStep
        // Cache smooth shading normals without changing a single collision vertex.
        // The fine material detail supplies close texture; these normals describe
        // the large continuous hills rather than the diagonals of the grid.
        let normalCount = divisions+1
        var shadingNormals = Array(repeating:SIMD3<Float>(0,1,0),count:normalCount*normalCount)
        for j in 0...divisions { for i in 0...divisions {
            let x = -SolarLandscape.extent+Float(i)*step, z = -SolarLandscape.extent+Float(j)*step
            let offset:Float = 35
            let dx = field.vertexHeight(x:x+offset,z:z)-field.vertexHeight(x:x-offset,z:z)
            let dz = field.vertexHeight(x:x,z:z+offset)-field.vertexHeight(x:x,z:z-offset)
            shadingNormals[j*normalCount+i] = simd_normalize(SIMD3<Float>(-dx,2*offset,-dz))
        } }
        for z in 0..<divisions { for x in 0..<divisions {
            let px = -SolarLandscape.extent+Float(x)*step, pz = -SolarLandscape.extent+Float(z)*step
            let a = SIMD3<Float>(px,field.vertexHeight(x:px,z:pz),pz)
            let b = SIMD3<Float>(px+step,field.vertexHeight(x:px+step,z:pz),pz)
            let c = SIMD3<Float>(px,field.vertexHeight(x:px,z:pz+step),pz+step)
            let d = SIMD3<Float>(px+step,field.vertexHeight(x:px+step,z:pz+step),pz+step)
            let h = (a.y+b.y+c.y+d.y)/4
            let slope = max(abs(a.y-d.y),abs(b.y-c.y))/step
            let index:Int
            switch body.name {
            case "Earth": index = h>1650 ? 7 : slope>0.6 ? 4 : h>900 ? 3 : 1
            case "Mercury": index = min(7,max(0,Int((h+70)/75)))
            case "Venus": index = slope>0.5 ? 4 : h>850 ? 3 : 1
            default: index = slope>0.5 ? 4 : h>600 ? 3 : 1
            }
            let na = shadingNormals[z*normalCount+x], nb = shadingNormals[z*normalCount+x+1]
            let nc = shadingNormals[(z+1)*normalCount+x], nd = shadingNormals[(z+1)*normalCount+x+1]
            terrain[index].smoothTriangle(a,c,b,na,nc,nb); terrain[index].smoothTriangle(b,c,d,nb,nc,nd)
        } }
        let palette:[UIColor]
        switch body.name {
        case "Earth": palette = [color(0.23,0.32,0.17),color(0.25,0.34,0.18),color(0.28,0.36,0.21),color(0.36,0.40,0.29),color(0.47,0.49,0.46),color(0.49,0.50,0.48),color(0.52,0.53,0.50),color(0.83,0.85,0.82)]
        case "Mercury": palette = (0..<8).map { let v = Float(0.37)+Float($0)*0.012; return color(v,v*0.97,v*0.94) }
        case "Venus": palette = [color(0.22,0.20,0.16),color(0.25,0.23,0.18),color(0.27,0.24,0.18),color(0.29,0.26,0.19),color(0.23,0.21,0.17),color(0.25,0.23,0.18),color(0.27,0.24,0.20),color(0.29,0.26,0.21)]
        default: palette = [color(0.56,0.29,0.18),color(0.59,0.31,0.19),color(0.62,0.33,0.21),color(0.64,0.35,0.22),color(0.55,0.29,0.19),color(0.57,0.31,0.20),color(0.60,0.33,0.21),color(0.62,0.35,0.22)]
        }
        for i in terrain.indices {
            let kind = body.name == "Earth" ? (i == 7 ? "snow" : i<4 ? "moss" : "rock") : body.name == "Mars" ? "sand" : "rock"
            terrain[i].append(to:root,name:body.name+" terrain band \(i)",color:palette[i],kind:kind,planet:body.name,continuous:true)
        }
        switch body.name {
        case "Earth": populateEarth(root,field:field)
        case "Venus": populateVenus(root,field:field)
        case "Mars": populateMars(root,field:field)
        default: break
        }
        populateCloudLayer(root,body:body)
    }
    private static func populateCloudLayer(_ root:Entity,body:SolarBody) {
        guard ["Earth","Venus","Mars"].contains(body.name) else { return }
        var positions:[SIMD3<Float>] = [],normals:[SIMD3<Float>] = [],uv:[SIMD2<Float>] = [],indices:[UInt32] = []
        for i in 0..<48 {
            let angle=Float(i)*2.39996, r=Float(1600+i%8*1500)
            let c=SIMD3<Float>(cos(angle)*r,body.name == "Venus" ? 2400:2800+Float(i%5)*120,sin(angle)*r)
            let right=SIMD3<Float>(cos(angle)*720,0,sin(angle)*720),up=SIMD3<Float>(0,240,0)
            let base=UInt32(positions.count)
            positions += [c-right-up,c+right-up,c+right+up,c-right+up]
            normals += Array(repeating:simd_normalize(simd_cross(right,up)),count:4)
            uv += [[0,1],[1,1],[1,0],[0,0]];indices += [base,base+1,base+2,base,base+2,base+3]
        }
        var descriptor=MeshDescriptor(name:"Prepared atmospheric cloud layer")
        descriptor.positions = .init(positions);descriptor.normals = .init(normals);descriptor.textureCoordinates = .init(uv);descriptor.primitives = .triangles(indices)
        if let mesh=try? MeshResource.generate(from:[descriptor]) {
            let color:UIColor = body.name == "Venus" ? .init(red:0.82,green:0.65,blue:0.38,alpha:1) : body.name == "Mars" ? .init(red:0.72,green:0.53,blue:0.4,alpha:1) : .init(white:0.96,alpha:1)
            let entity=ModelEntity(mesh:mesh,materials:[ScenicMaterials.cloud(color:color,planet:body.name)])
            entity.name=body.name+" prepared cloud layer";entity.components.set(DynamicLightShadowComponent(castsShadow:false));root.addChild(entity)
        }
    }
    /// A continuous sky gradient gives atmospheric depth without floating opaque
    /// bands. Generated once with each region; no texture updates during flight.
    private static func expeditionSky(_ body:SolarBody) -> UnlitMaterial {
        var paint = UniverseMeshes.material(UIColor(red:CGFloat(body.skyTint.x),green:CGFloat(body.skyTint.y),blue:CGFloat(body.skyTint.z),alpha:1))
        guard body.name != "Mercury" else { return paint }
        let horizon:SIMD3<Float>
        switch body.name {
        case "Earth": horizon = [0.68,0.79,0.84]
        case "Venus": horizon = [0.78,0.58,0.26]
        case "Mars": horizon = [0.66,0.43,0.29]
        default: horizon = [0.75,0.63,0.44]
        }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size:CGSize(width:32,height:256),format:format).image { context in
            for row in 0..<256 {
                let proximity = 1-abs(Float(row)/255-0.5)*2
                let mix = pow(proximity,4)*0.8
                let rgb = body.skyTint*(1-mix)+horizon*mix
                context.cgContext.setFillColor(UIColor(red:CGFloat(rgb.x),green:CGFloat(rgb.y),blue:CGFloat(rgb.z),alpha:1).cgColor)
                context.cgContext.fill(CGRect(x:0,y:row,width:32,height:1))
            }
        }
        if let cg = image.cgImage,let texture = try? TextureResource.generate(from:cg,options:.init(semantic:.color)) {
            paint.color = .init(tint:.white,texture:.init(texture))
        }
        return paint
    }
    private static func color(_ r:Float,_ g:Float,_ b:Float) -> UIColor { UIColor(red:CGFloat(r),green:CGFloat(g),blue:CGFloat(b),alpha:1) }
    private static func populateEarth(_ root:Entity,field:SolarLandscape) {
        var river = ExpeditionBatch(), foam = ExpeditionBatch(), mist = ExpeditionBatch(), trunks = ExpeditionBatch(), branches = ExpeditionBatch()
        var leaves = Array(repeating:ExpeditionBatch(),count:3)
        for i in 0..<280 {
            let z = -SolarLandscape.extent+Float(i)*100, next = z+100
            let x = field.riverCenter(z:z), nx = field.riverCenter(z:next)
            river.quad([x-65,field.riverLevel(z:z),z],[nx-65,field.riverLevel(z:next),next],[nx+65,field.riverLevel(z:next),next],[x+65,field.riverLevel(z:z),z])
        }
        for z:Float in [0,-3470] {
            let x = field.riverCenter(z:z), top = field.riverLevel(z:z+160), bottom = field.riverLevel(z:z-160)
            foam.quad([x-66,bottom,z-65],[x+66,bottom,z-65],[x+66,top,z+65],[x-66,top,z+65])
            foam.ellipsoid([x,bottom+10,z-110],[95,15,80])
            // Narrow streams break up the sheet; spray climbs around the plunge
            // pool so the falls remain readable from the normal approach.
            for i in 0..<26 {
                let offset = -62+Float(i)*5, front = z-67-Float(i%3)*2
                foam.quad([x+offset,bottom+6,front],[x+offset+1.8,bottom+6,front],[x+offset+1.8,top-4,z+66],[x+offset,top-4,z+66])
            }
            for i in 0..<14 {
                let angle = Float(i)*2.39996, radius = Float(25+i%4*12)
                mist.ellipsoid([x+cos(angle)*radius,bottom+18+Float(i%5)*13,z-95+sin(angle)*40],[30,22,22])
            }
        }
        for (index,solid) in field.scenerySolids.enumerated() {
            trunks.frustum(solid.base+[0,solid.height/2,0],radius:solid.radius,height:solid.height,top:1,sides:10)
            for tier in 0..<6 {
                let t = Float(tier)/6, rise = solid.height*(0.44+t*0.65)
                let width = solid.height*(0.29-t*0.21)*(1+0.10*sin(Float(index*17+tier*11)))
                let lean = SIMD3<Float>(sin(Float(index))*t*6,0,cos(Float(index))*t*6)
                leaves[(index+tier)%3].frustum(solid.base+lean+[0,rise,0],radius:width,height:solid.height*(0.26-t*0.12),top:0.04,sides:11)
                if tier<4 {
                    for side:Float in [-1,1] {
                        branches.box(solid.base+[side*width*0.35,rise-5,0],[width*0.7,1.4,1.4])
                    }
                }
            }
        }
        var sea = ExpeditionBatch()
        sea.quad([-14000,0,-14000],[-14000,0,14000],[14000,0,14000],[14000,0,-14000])
        sea.append(to:root,name:"Earth coastal sea",color:color(0.025,0.14,0.23),kind:"water")
        river.append(to:root,name:"Winding valley river",color:color(0.08,0.28,0.34),kind:"water")
        foam.append(to:root,name:"Waterfall curtains and spray",color:color(0.74,0.88,0.91),unlit:true)
        mist.append(to:root,name:"Waterfall plume mist",color:color(0.76,0.87,0.89),unlit:true,opacity:0.2)
        trunks.append(to:root,name:"Valley tree trunks",color:color(0.23,0.17,0.12),kind:"bark")
        branches.append(to:root,name:"Valley tree branches",color:color(0.19,0.15,0.10),kind:"bark")
        for i in leaves.indices { leaves[i].append(to:root,name:"Valley forest canopy \(i)",color:color(0.10+Float(i)*0.025,0.23+Float(i)*0.035,0.13+Float(i)*0.018),kind:"moss") }
    }
    private static func populateVenus(_ root:Entity,field:SolarLandscape) {
        var basalt = ExpeditionBatch(), vents = ExpeditionBatch()
        for solid in field.scenerySolids {
            basalt.frustum(solid.base+[0,solid.height/2,0],radius:solid.radius,height:solid.height,top:1,sides:6)
        }
        for i in 0..<32 {
            let angle = Float(i)*2 * .pi/32, x = -900+cos(angle)*510, z = -3600+sin(angle)*510
            let h = field.height(x:x,z:z)
            vents.ellipsoid([x,h+2,z],[28,4,15])
        }
        var fissures = ExpeditionBatch(), hotCore = ExpeditionBatch()
        for branch in 0..<11 {
            let baseX = -1500+Float(branch)*240
            for segment in 0..<64 {
                let z = 1700-Float(segment)*95, nz = z-95
                let x = baseX+140*sin(z/560+Float(branch)), nx = baseX+140*sin(nz/560+Float(branch))
                let width = Float(5+branch%4*3)
                func p(_ x:Float,_ z:Float) -> SIMD3<Float> { [x,field.height(x:x,z:z)+0.7,z] }
                fissures.quad(p(x-width,z),p(nx-width,nz),p(nx+width,nz),p(x+width,z))
                hotCore.quad(p(x-width*0.25,z)+[0,0.3,0],p(nx-width*0.25,nz)+[0,0.3,0],p(nx+width*0.25,nz)+[0,0.3,0],p(x+width*0.25,z)+[0,0.3,0])
            }
        }
        fissures.append(to:root,name:"Volcanic lava fissure margins",color:color(0.75,0.12,0.015),unlit:true)
        hotCore.append(to:root,name:"Volcanic fissure glow",color:color(1,0.51,0.06),unlit:true)
        basalt.append(to:root,name:"Hexagonal volcanic basalt",color:color(0.22,0.20,0.16))
        vents.append(to:root,name:"Caldera ember vents",color:color(0.95,0.29,0.04),unlit:true)
    }
    private static func populateMars(_ root:Entity,field:SolarLandscape) {
        var ribs = ExpeditionBatch()
        for solid in field.scenerySolids {
            // Recessed shelves stay inside the existing collision cylinder.
            for layer in 0..<3 {
                let radius = solid.radius*(1-Float(layer)*0.17)
                let h = solid.height/3
                ribs.frustum(solid.base+[0,h*(Float(layer)+0.5),0],radius:radius,height:h,top:0.87,sides:9)
            }
        }
        var strata = ExpeditionBatch()
        for bank:Float in [-1,1] {
            for layer in 0..<10 {
                for segment in 0..<360 {
                    let z = -11000+Float(segment)*60, nz = z+60
                    let x = bank*(1700+Float(layer)*53+130*sin(z/1900)), nx = bank*(1700+Float(layer)*53+130*sin(nz/1900))
                    func p(_ x:Float,_ z:Float) -> SIMD3<Float> { [x,field.height(x:x,z:z)+0.3,z] }
                    strata.quad(p(x-2,z),p(nx-2,nz),p(nx+2,nz),p(x+2,z))
                }
            }
        }
        strata.append(to:root,name:"Exposed sediment seams",color:color(0.43,0.23,0.15),kind:"sand")
        ribs.append(to:root,name:"Eroded dry sea escarpments",color:color(0.41,0.23,0.16))
    }
    private static func populateJupiter(_ root:Entity) {
        func noise(_ i:Int) -> Float { let value = sin(Float(i)*12.9898+17.37)*43758.5453; return value-floor(value) }
        var undercloud = ExpeditionBatch()
        undercloud.quad([-21000,-180,-21000],[-21000,-180,21000],[21000,-180,21000],[21000,-180,-21000])
        undercloud.append(to:root,name:"Continuous deep cloud ocean",color:color(0.55,0.39,0.25),unlit:true)
        var belts = Array(repeating:ExpeditionBatch(),count:4)
        // Overlapping clusters have smooth surface normals and actual vertical
        // depth. There are no empty strips of black sky between cloud ribbons.
        for row in 0..<22 {
            let z = -15000+Float(row)*1400
            for column in 0..<28 {
                let seed = row*137+column*7
                let x = -18000+Float(column)*1350+(noise(seed)-0.5)*800
                let bend = 300*sin(x/3900+Float(row)*0.47)
                let y = -60+noise(seed+1)*150+50*sin(x/2100)
                let rx = 900+noise(seed+2)*310
                belts[row%4].ellipsoid([x,y,z+bend+(noise(seed+3)-0.5)*700],[rx,230+noise(seed+4)*160,900+noise(seed+5)*300],billow:0.16,seed:Float(seed))
            }
        }
        let colors = [color(0.76,0.65,0.49),color(0.83,0.73,0.56),color(0.72,0.59,0.43),color(0.80,0.69,0.52)]
        for i in belts.indices { belts[i].append(to:root,name:"Layered cloud belt \(i)",color:colors[i],kind:"cloud") }
        var cyclone = Array(repeating:ExpeditionBatch(),count:3)
        let center = SIMD3<Float>(1200,0,-1500)
        let stormRoot = Entity(); stormRoot.name = "Jupiter rotating cyclone"; stormRoot.position = center
        root.addChild(stormRoot)
        for arm in 0..<3 {
            for index in 0..<72 {
                let t = Float(index)/71, radius = 360+t*2300
                let angle = Float(arm)*2 * .pi/3+t*9
                let p = SIMD3<Float>(cos(angle)*radius,150+t*330,sin(angle)*radius*0.66)
                let size:Float = 150+t*180
                cyclone[(index+arm)%3].ellipsoid(p,[size,105+t*80,size*0.7],billow:0.18,seed:Float(index+arm*11))
            }
        }
        let storm = [color(0.71,0.36,0.21),color(0.81,0.50,0.30),color(0.91,0.74,0.49)]
        for i in cyclone.indices { cyclone[i].append(to:stormRoot,name:"Cyclone cloud crest \(i)",color:storm[i],kind:"cloud") }
        var highCloud = ExpeditionBatch()
        for index in 0..<96 {
            let a = Float(index)*2.39996, radius = Float(3100+index%5*560)
            let size = Float(150)+noise(index)*320
            highCloud.ellipsoid([1200+cos(a)*radius,250+noise(index+17)*220,-1500+sin(a)*radius],[size,130+noise(index+31)*120,size*0.82],billow:0.22,seed:Float(index))
        }
        highCloud.append(to:root,name:"High cloud banks",color:color(0.86,0.78,0.63),kind:"cloud")
    }
    static func populate(_ root:Entity,body:SolarBody) {
        if ["Mercury", "Venus", "Earth", "Mars", "Jupiter"].contains(body.name) {
            populateExpedition(root,body:body)
            return
        }
        let field = SolarLandscape(body:body)
        let sky = ModelEntity(mesh:.generateSphere(radius:60000),materials:[UniverseMeshes.material(UIColor(red:CGFloat(body.skyTint.x),green:CGFloat(body.skyTint.y),blue:CGFloat(body.skyTint.z),alpha:1))])
        sky.scale = [-1,1,1]; root.addChild(sky)
        if !body.isCloudWorld {
            let divisions = 128, step = SolarLandscape.extent*2/Float(divisions)
            var groups = Array(repeating:[SIMD3<Float>](),count:8)
            for z in 0..<divisions { for x in 0..<divisions {
                let px = -SolarLandscape.extent+Float(x)*step, pz = -SolarLandscape.extent+Float(z)*step
                let a = SIMD3<Float>(px,field.height(x:px,z:pz),pz)
                let b = SIMD3<Float>(px+step,field.height(x:px+step,z:pz),pz)
                let c = SIMD3<Float>(px,field.height(x:px,z:pz+step),pz+step)
                let d = SIMD3<Float>(px+step,field.height(x:px+step,z:pz+step),pz+step)
                let h = (a.y+b.y+c.y+d.y)/4
                let group = body.name == "Earth" ? (h < 10 ? 0 : h < 80 ? 1 : h < 350 ? 2 : h < 600 ? 3 : 4) : min(7,max(0,Int(h/160)))
                groups[group] += [a,c,b,b,c,d]
            } }
            for (index,positions) in groups.enumerated() where !positions.isEmpty {
                var normals:[SIMD3<Float>] = []
                for i in stride(from:0,to:positions.count,by:3) {
                    let n = simd_normalize(simd_cross(positions[i+1]-positions[i],positions[i+2]-positions[i]))
                    normals += [n,n,n]
                }
                var descriptor = MeshDescriptor(name:body.name+" prepared terrain")
                descriptor.positions = .init(positions); descriptor.normals = .init(normals)
                descriptor.primitives = .triangles((0..<UInt32(positions.count)).map { $0 })
                let earth:[UIColor] = [.init(red:0.06,green:0.24,blue:0.32,alpha:1),.init(red:0.62,green:0.56,blue:0.36,alpha:1),.init(red:0.15,green:0.36,blue:0.21,alpha:1),.init(red:0.26,green:0.34,blue:0.24,alpha:1),.init(white:0.82,alpha:1)]
                let factor = CGFloat(0.5+Double(index)*0.045)
                let tint = UIColor(red:CGFloat(body.tint.x)*factor,green:CGFloat(body.tint.y)*factor,blue:CGFloat(body.tint.z)*factor,alpha:1)
                if let mesh = try? MeshResource.generate(from:[descriptor]) {
                    let color = body.name == "Earth" ? earth[min(index,4)] : tint
                    root.addChild(ModelEntity(mesh:mesh,materials:[SimpleMaterial(color:color,roughness:1,isMetallic:false)]))
                }
            }
            if body.name == "Earth" {
                let ocean = ModelEntity(mesh:.generatePlane(width:28000,depth:28000),materials:[UniverseMeshes.material(UIColor(red:0.035,green:0.22,blue:0.38,alpha:1))])
                ocean.position.y = 0; root.addChild(ocean)
            }
        }
        if !["Moon","Mercury"].contains(body.name) {
            let cloudMesh = MeshResource.generateSphere(radius:1)
            let cloudMaterial = UniverseMeshes.material(.init(white:body.isCloudWorld ? 0.5:0.9,alpha:1),opacity:0.35)
            for i in 0..<40 {
                let cloud = ModelEntity(mesh:cloudMesh,materials:[cloudMaterial])
                let angle = Float(i)*2.39996, radius = Float(1200+i*240)
                cloud.position = [cos(angle)*radius,body.isCloudWorld ? Float(200+i%5*160):1800+Float(i%5*50),sin(angle)*radius]
                cloud.scale = [Float(350+i%4*80),Float(50+i%3*30),250]; root.addChild(cloud)
            }
        }
    }
}
