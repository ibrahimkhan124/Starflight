import Foundation
import simd

/// Real galaxy identities, with deliberately schematic map/flight coordinates.
enum Galaxy: String, CaseIterable, Codable, Identifiable {
    case milkyWay, andromeda, triangulum, magellanic
    var id:String { rawValue }
    var name:String { switch self { case .milkyWay:return "Milky Way"; case .andromeda:return "Andromeda"; case .triangulum:return "Triangulum"; case .magellanic:return "Large Magellanic Cloud" } }
    var distance:String { switch self { case .milkyWay:return "Our home galaxy"; case .andromeda:return "About 2.5 million light-years from Earth"; case .triangulum:return "About 3 million light-years from Earth"; case .magellanic:return "About 160,000 light-years from Earth" } }
    var detail:String { switch self { case .milkyWay:return "Home to the Solar System. Catalogued stars are shown from your current observer position."; case .andromeda:return "A vast spiral galaxy. Explore an original blue-and-gold survey sector."; case .triangulum:return "A smaller spiral galaxy, with a violet survey sector and bright star-forming clouds."; case .magellanic:return "An irregular satellite galaxy. Explore a scattered, amber-and-teal star cloud." } }
    var mapPosition:SIMD3<Float> { switch self { case .milkyWay:return [-2,0,2]; case .andromeda:return [2,0.4,-2]; case .triangulum:return [4,-0.3,1.6]; case .magellanic:return [-4,0,0] } }
    var tint:SIMD3<Float> { switch self { case .milkyWay:return [0.35,0.65,1]; case .andromeda:return [1,0.62,0.27]; case .triangulum:return [0.75,0.4,1]; case .magellanic:return [0.25,1,0.75] } }
    var blackHole:BlackHoleField { BlackHoleField(center:self == .milkyWay ? [5200,400,-6000] : [-800,400,-4800]) }
}

struct CatalogStar: Codable, Identifiable, Equatable {
    let hip:Int
    let name:String?
    let raDegrees:Double
    let decDegrees:Double
    let magnitude:Double
    let parallaxMas:Double
    let parallaxErrorMas:Double
    let bv:Double
    var id:Int { hip }
    var title:String { name ?? "HIP \(hip)" }
    var distancePC:Double { 1000/parallaxMas }
    var distanceLY:Double { distancePC*3.26156 }
    /// RA zero points down -Z; north celestial pole is +Y. ICRS reference epoch J1991.25.
    var positionPC:SIMD3<Double> {
        let ra = raDegrees * .pi/180, dec = decDegrees * .pi/180, r = distancePC
        return [r*cos(dec)*sin(ra), r*sin(dec), -r*cos(dec)*cos(ra)]
    }
    func apparentMagnitude(from observer:SIMD3<Double>) -> Double {
        magnitude + 5*log10(max(0.0001,simd_distance(positionPC,observer))/distancePC)
    }
    var valid:Bool { hip > 0 && hip <= 120500 && raDegrees.isFinite && (0..<360).contains(raDegrees) && decDegrees.isFinite && (-90...90).contains(decDegrees) && magnitude.isFinite && parallaxMas.isFinite && parallaxMas > 0 && parallaxErrorMas.isFinite && parallaxErrorMas >= 0 && bv.isFinite }
}

enum StarCatalogue {
    static let all:[CatalogStar] = {
        guard let url = Bundle.main.url(forResource:"hipparcos-bright",withExtension:"json",subdirectory:"Astronomy") ?? Bundle.main.url(forResource:"hipparcos-bright",withExtension:"json"),
              let data = try? Data(contentsOf:url),let stars = try? JSONDecoder().decode([CatalogStar].self,from:data),stars.count == 3000,stars.allSatisfy(\.valid),Set(stars.map(\.hip)).count == stars.count else { return [] }
        return stars
    }()
    static func star(_ hip:Int) -> CatalogStar? { all.first { $0.hip == hip } }
    static let source = "ESA Hipparcos (1997), NASA HEASARC · ICRS, epoch J1991.25"
}

enum GravityZone:String { case clear, outer, strong, horizon }
struct BlackHoleField {
    let center:SIMD3<Float>
    let influence:Float = 3200
    let horizon:Float = 150
    func zone(at point:SIMD3<Float>) -> GravityZone {
        let r = simd_distance(point,center)
        return r <= horizon ? .horizon : r < 850 ? .strong : r < influence ? .outer : .clear
    }
    func acceleration(at point:SIMD3<Float>) -> SIMD3<Float> {
        let delta = center-point, r = simd_length(delta)
        guard r.isFinite,r > 0.001,r < influence else { return .zero }
        let taper = 1-pow(r/influence,4)
        return delta/r * min(280,60_000_000/max(r*r,horizon*horizon))*taper
    }
    func crossed(from a:SIMD3<Float>,to b:SIMD3<Float>,radius:Float) -> Bool {
        let segment = b-a
        let t = clamp(simd_dot(center-a,segment)/max(0.0001,simd_length_squared(segment)),0,1)
        return simd_distance(a+segment*t,center) <= horizon+max(0,radius)
    }
}

enum UniverseSector:String { case home, stellar, solarSystem }
enum UniverseDestination:Equatable {
    case galaxy(Galaxy), star(Int?), solarSystem, surface(String), blackHole
    var title:String { switch self { case .galaxy(let galaxy):return galaxy.name; case .star(let hip):return hip.flatMap(StarCatalogue.star)?.title ?? "Earth reference sky"; case .solarSystem:return "Solar System orbit"; case .surface(let name):return name + " exploration"; case .blackHole:return "Black-hole approach" } }
}

/// Travel and hazards use bounded local coordinates. No million-light-year Float positions.
struct UniverseFlight {
    static let jumpDuration:Float = 5
    static let metresPerParsec:Double = 20_000 // Explicitly exaggerated stellar movement for gameplay.
    private(set) var galaxy:Galaxy = .milkyWay
    private(set) var sector:UniverseSector = .home
    private(set) var surfaceBody: SolarBody?
    private(set) var observerHIP:Int?
    private(set) var destination:UniverseDestination?
    private(set) var remaining:Float = 0
    private(set) var gravityDrift = SIMD3<Float>.zero
    private var departure:FlightState?
    private(set) var localOrigin = SIMD3<Float>(0,0,260)
    var jumping:Bool { destination != nil }
    var homePlanets:Bool { galaxy == .milkyWay && sector == .home }
    var catalogVisible:Bool { galaxy == .milkyWay }
    var blackHole:BlackHoleField? { sector == .solarSystem ? nil:galaxy.blackHole }
    var location:String { surfaceBody.map { $0.name + ($0.isCloudWorld ? " · cloud expedition" : " · surface expedition") } ?? (sector == .solarSystem ? "Solar System orbit" : homePlanets ? "Starflight home sector" : observerHIP.flatMap(StarCatalogue.star)?.title ?? (galaxy == .milkyWay ? "Earth reference sector":"Survey sector")) }
    func observerPC(local:SIMD3<Float>) -> SIMD3<Double> {
        var base = SIMD3<Double>.zero
        if let hip = observerHIP,let star = StarCatalogue.star(hip) {
            base = star.positionPC - simd_normalize(star.positionPC)*0.03
        }
        let delta = local-localOrigin
        return base + SIMD3<Double>(Double(delta.x),Double(delta.y),Double(delta.z))/Self.metresPerParsec
    }
    mutating func begin(_ destination:UniverseDestination,state:FlightState) -> Bool {
        guard !jumping else { return false }
        if case .star(let hip?) = destination,StarCatalogue.star(hip) == nil { return false }
        if case .surface(let name) = destination, name != AetherPlanet.name {
            guard galaxy == .milkyWay, sector == .solarSystem,
                  SolarBody.all.contains(where: { $0.name == name && $0.name != "Sun" }) else { return false }
        }
        if destination == .surface(AetherPlanet.name), !AetherPlanet.enabled { return false }
        self.destination = destination; remaining = Self.jumpDuration; departure = state; return true
    }
    mutating func cancel(state:inout FlightState) {
        guard jumping else { return }
        if let departure { state = departure }
        destination = nil; remaining = 0; departure = nil
    }
    /// Returns an arrival once. Calls are made only on active physics steps, so pause freezes travel.
    mutating func advanceJump(state:inout FlightState,dt:Float) -> UniverseDestination? {
        guard let destination,dt.isFinite,dt > 0 else { return nil }
        remaining = max(0,remaining-min(dt,0.25))
        guard remaining == 0 else { return nil }
        surfaceBody = nil
        switch destination {
        case .surface(let name): galaxy = .milkyWay; sector = .solarSystem; observerHIP = nil; surfaceBody = name == AetherPlanet.name ? AetherPlanet.body : SolarBody.all.first { $0.name == name }
        case .galaxy(let next): galaxy = next; sector = next == .milkyWay ? .home:.stellar; observerHIP = nil
        case .star(let hip): galaxy = .milkyWay; sector = .stellar; observerHIP = hip
        case .solarSystem: galaxy = .milkyWay; sector = .solarSystem; observerHIP = nil
        case .blackHole: sector = .stellar
        }
        state.position = sector == .solarSystem ? [0,300,900] : [0,400,800]
        if destination == .blackHole { state.position = galaxy.blackHole.center+[0,0,3800] }
        if let body = surfaceBody { state.position = [0, body.isCloudWorld ? 800 : SolarLandscape(body:body).height(x:0,z:1200)+400,1200] }
        state.pitch = 0; state.roll = 0; state.heading = 0; state.pitchRate = 0
        if case .star(let hip?) = destination,let star = StarCatalogue.star(hip) {
            let direction = SIMD3<Float>(simd_normalize(star.positionPC))
            state.heading = atan2(direction.x,-direction.z); state.pitch = asin(clamp(direction.y,-1,1))
        }
        state.airspeed = 0; state.velocity = .zero
        self.destination = nil; departure = nil; gravityDrift = .zero; localOrigin = state.position
        return destination
    }
    /// Persistent drift is applied separately from engine thrust, so steering cannot reset gravity.
    mutating func applyGravity(state:inout FlightState,from previous:SIMD3<Float>,radius:Float,dt:Float) -> Bool {
        guard !jumping,let hole = blackHole,dt.isFinite,dt > 0 else { return false }
        let step = min(dt,0.1)
        gravityDrift += hole.acceleration(at:state.position)*step
        gravityDrift *= exp(-step*0.08)
        let speed = simd_length(gravityDrift)
        if speed > 900 { gravityDrift *= 900/speed }
        state.position += gravityDrift*step
        return hole.crossed(from:previous,to:state.position,radius:radius)
    }
}

struct SolarBody:Identifiable {
    let name:String
    let radius:Float
    let position:SIMD3<Float>
    let tint:SIMD3<Float>
    var id:String { name }
    static let all:[SolarBody] = [
        .init(name:"Sun",radius:170,position:[0,0,-2500],tint:[1,0.65,0.14]),
        .init(name:"Mercury",radius:28,position:[-650,0,-2400],tint:[0.55,0.51,0.45]),
        .init(name:"Venus",radius:46,position:[-1100,0,-2000],tint:[0.95,0.75,0.4]),
        .init(name:"Earth",radius:52,position:[-1400,0,-1000],tint:[0.16,0.45,1]),
        .init(name:"Mars",radius:38,position:[1200,0,-1800],tint:[0.83,0.3,0.15]),
        .init(name:"Jupiter",radius:120,position:[2100,0,-2900],tint:[0.75,0.58,0.38]),
        .init(name:"Saturn",radius:100,position:[-2600,0,-3900],tint:[0.9,0.77,0.5]),
        .init(name:"Uranus",radius:72,position:[1700,0,-5300],tint:[0.4,0.85,0.88]),
        .init(name:"Neptune",radius:70,position:[-1800,0,-6500],tint:[0.17,0.31,0.9]),
        .init(name:"Moon",radius:14,position:[-1270,0,-1000],tint:[0.65,0.65,0.67])]
    static func impact(from a:SIMD3<Float>,to b:SIMD3<Float>,radius:Float) -> SolarBody? {
        let segment = b-a, length = max(0.001,simd_length_squared(segment))
        return all.first { body in
            let t = clamp(simd_dot(body.position-a,segment)/length,0,1)
            return simd_distance(a+segment*t,body.position)<body.radius+radius
        }
    }
}

extension SolarBody {
    var isCloudWorld: Bool { ["Jupiter","Saturn","Uranus","Neptune"].contains(name) }
    var skyTint: SIMD3<Float> {
        switch name {
        case "Earth": return [0.22,0.48,0.76]
        case "Mars": return [0.42,0.22,0.14]
        case "Venus": return [0.59,0.4,0.13]
        case "Mercury", "Moon": return [0.008,0.01,0.025]
        default: return tint*0.35
        }
    }
}
/// A bounded, original exploration landscape. Both collision and drawing use this field.
/// These are scenic interpretations, not geographic terrain surveys.
struct SolarLandscape {
    let body: SolarBody
    static let extent: Float = 14000
    func noise(_ x:Float,_ z:Float) -> Float {
        let ix = floor(x), iz = floor(z), fx = x-ix, fz = z-iz
        let sx = fx*fx*(3-2*fx), sz = fz*fz*(3-2*fz)
        func hash(_ a:Float,_ b:Float) -> Float {
            let v = sin(a*127.1+b*311.7+Float(body.name.utf8.reduce(0) { $0+Int($1) }))*43758.5453
            return (v-floor(v))*2-1
        }
        let a = hash(ix,iz)*(1-sx)+hash(ix+1,iz)*sx
        let b = hash(ix,iz+1)*(1-sx)+hash(ix+1,iz+1)*sx
        return a*(1-sz)+b*sz
    }
    /// New expedition terrain is rendered on this same grid. Sampling the same
    /// triangles keeps a low pass from meeting an invisible analytic ridge.
    static let scenicDivisions = 192
    static let scenicStep = extent * 2 / Float(scenicDivisions)
    var usesScenicTerrain: Bool { ["Mercury", "Venus", "Earth", "Mars"].contains(body.name) }
    func height(x:Float,z:Float) -> Float {
        if body.name == AetherPlanet.name { return AetherPlanet.height(x:x,z:z) }
        guard usesScenicTerrain else { return legacyHeight(x:x,z:z) }
        let step = Self.scenicStep
        let gx = (x + Self.extent) / step, gz = (z + Self.extent) / step
        let ix = floor(gx), iz = floor(gz), u = gx-ix, v = gz-iz
        let px = -Self.extent + ix*step, pz = -Self.extent + iz*step
        let a = vertexHeight(x:px,z:pz), b = vertexHeight(x:px+step,z:pz)
        let c = vertexHeight(x:px,z:pz+step), d = vertexHeight(x:px+step,z:pz+step)
        return u+v <= 1 ? a+(b-a)*u+(c-a)*v : b*(1-v)+c*(1-u)+d*(u+v-1)
    }
    private func softEdge(_ low:Float,_ high:Float,_ value:Float) -> Float {
        let t = clamp((value-low)/(high-low),0,1)
        return t*t*(3-2*t)
    }
    /// Domain warping removes the square alignment of the noise lattice. Broad
    /// ridges split into smaller drainage branches instead of repeated sine teeth.
    private func ridgedRelief(x:Float,z:Float,scale:Float) -> Float {
        let wx = x+noise(x/5200+17,z/5200-9)*820
        let wz = z+noise(x/5200-31,z/5200+23)*820
        let first = pow(1-abs(noise(wx/scale,wz/scale)),3)
        let second = pow(1-abs(noise(wx/scale*2.03+11,wz/scale*2.03-7)),3)
        return first*0.72+second*0.28
    }
    func riverCenter(z:Float) -> Float { 900*sin(z/2700)+250*sin(z/1100) }
    func riverLevel(z:Float) -> Float {
        let upstream = 40+(z+Self.extent)*0.006 +
            190*softEdge(-3500,3500,z)+110*softEdge(-6500,-500,z)
        // A gentle estuary joins the coastal sea rather than ending the river
        // above sea level at the edge of the prepared region.
        return upstream*softEdge(-14000,-11400,z)
    }
    private struct SurfaceCrater {
        let center:SIMD2<Float>
        let radius:Float
        let depth:Float
        let rim:Float
        let aspect:Float
    }
    private static let mercuryCraters:[SurfaceCrater] = {
        var seed:UInt32 = 0x9e3779b9
        func random() -> Float {
            seed = seed &* 1664525 &+ 1013904223
            var n = seed
            n = (n ^ (n >> 16)) &* 2246822519
            n = (n ^ (n >> 13)) &* 3266489917
            return Float((n ^ (n >> 16)) & 0x00ffffff)/Float(0x00ffffff)
        }
        var craters = [SurfaceCrater(center:[600,-900],radius:1800,depth:230,rim:150,aspect:1.04)]
        for _ in 0..<27 {
            let center = SIMD2<Float>((random()-0.5)*23200,(random()-0.5)*23200)
            let radius = 520+random()*1200
            craters.append(.init(center:center,radius:radius,depth:radius*(0.10+random()*0.045),rim:radius*(0.055+random()*0.035),aspect:0.88+random()*0.24))
        }
        return craters
    }()
    func vertexHeight(x:Float,z:Float) -> Float {
        let wx = x+noise(x/4700+13,z/4700-5)*560
        let wz = z+noise(x/4700-19,z/4700+29)*560
        let broad = noise(wx/2900,wz/2900), detail = noise(wx/680,wz/680)
        switch body.name {
        case "Earth":
            let distance = abs(x-riverCenter(z:z))
            let shoulder = pow(clamp((distance-150)/2100,0,1),1.3)
            let mountains = 680+1100*ridgedRelief(x:x,z:z,scale:2900)+260*(broad+1)*0.5
            let inland = riverLevel(z:z)-7+shoulder*mountains+detail*40*clamp(distance/700,0,1)
            let shore = 6500+850*noise(z/3200+7,3)+420*noise(z/1450-9,11)
            let coast = softEdge(shore,shore+2500,abs(x))
            let natural=inland*(1-coast)-45*coast
            let town=EarthCity.flattening(x:x,z:z)
            return natural*(1-town)+EarthCity.foundation*town
        case "Mercury":
            var value = 170+100*broad+22*detail
            for crater in Self.mercuryCraters {
                let delta = SIMD2<Float>((x-crater.center.x)*crater.aspect,(z-crater.center.y)/crater.aspect)
                let d = simd_length(delta)/crater.radius
                if d < 1.55 {
                    // Rounded bowl, raised fractured rim and an outer ejecta apron.
                    let rim = crater.rim*exp(-pow((d-1-detail*0.025)/0.105,2))
                    let bowl = -crater.depth*pow(max(0,1-d*d),1.45)
                    let ejecta = crater.rim*0.20*max(0,1-(d-1)/0.55)*softEdge(0.94,1.12,d)
                    let peak = crater.radius>1300 ? 24*exp(-d*d*38):0
                    value += rim+bowl+ejecta+peak
                }
            }
            return max(-160,value)
        case "Venus":
            let distance = simd_length(SIMD2<Float>(wx+900,wz+3600))
            let cone = 1350*exp(-pow(distance/2300,2))
            let caldera = 660*exp(-pow(distance/620,2))
            let basalt = ridgedRelief(x:x,z:z,scale:1800)*420
            return 180+cone-caldera+basalt+detail*35
        case "Mars":
            let axis = 1200*sin(z/3800)+340*noise(z/2300+4,8)
            let basin = exp(-pow((x-axis)/2700,4))
            let escarpment = 360+800*ridgedRelief(x:x,z:z,scale:3400)
            let dunePhase = wx/210+0.9*noise(wx/1400,wz/1400)
            let dunes = sin(dunePhase)*10+detail*18
            return 100+(1-basin)*escarpment+(broad+1)*90+dunes
        default: return legacyHeight(x:x,z:z)
        }
    }
    private func legacyHeight(x:Float,z:Float) -> Float {
        if body.isCloudWorld { return -600 }
        let broad = noise(x/2400,z/2400), detail = noise(x/700,z/700)*0.22+noise(x/210,z/210)*0.055
        if body.name == "Earth" { return max(-14,(broad+0.08)*900+detail*350) }
        var value = 90+abs(broad)*850+detail*400
        if body.name == "Mars" { value += abs(noise(x/4000,z/4000))*450 }
        if body.name == "Moon" || body.name == "Mercury" {
            // Depression bowls with raised rims rather than tall, repeating mountain teeth.
            for index in 0..<12 {
                let a = Float(index)*2.39996
                let center = SIMD2<Float>(cos(a),sin(a))*Float(800+index*720)
                let d = simd_distance(SIMD2<Float>(x,z),center)/Float(450+index%4*100)
                if d < 1.3 { value += 120*exp(-pow((d-1)*5,2))-180*max(0,1-d*d) }
            }
        }
        return value
    }
    /// Cylinders are shared by solid scenic geometry and swept collision. Foliage
    /// stays decorative; the trunk is the solid part of each tree.
    struct ScenicSolid {
        let base:SIMD3<Float>
        let radius:Float
        let height:Float
        func hits(from a:SIMD3<Float>,to b:SIMD3<Float>,radius shipRadius:Float) -> Bool {
            let step = b-a, offset = a-base, r = radius+shipRadius
            let aa = step.x*step.x+step.z*step.z
            var enter:Float = 0, leave:Float = 1
            if aa < 0.0001 {
                if offset.x*offset.x+offset.z*offset.z > r*r { return false }
            } else {
                let bb = 2*(offset.x*step.x+offset.z*step.z)
                let cc = offset.x*offset.x+offset.z*offset.z-r*r
                let discriminant = bb*bb-4*aa*cc
                if discriminant < 0 { return false }
                let delta = sqrt(discriminant)
                enter = max(enter,(-bb-delta)/(2*aa)); leave = min(leave,(-bb+delta)/(2*aa))
            }
            if abs(step.y)<0.0001 {
                if offset.y < -shipRadius || offset.y > height+shipRadius { return false }
            } else {
                let t0 = (-shipRadius-offset.y)/step.y, t1 = (height+shipRadius-offset.y)/step.y
                enter = max(enter,min(t0,t1)); leave = min(leave,max(t0,t1))
            }
            return enter <= leave
        }
    }
    private static let scenicSolidCache:[String:[ScenicSolid]] = {
        var result:[String:[ScenicSolid]] = [:]
        for body in SolarBody.all where ["Earth","Venus","Mars"].contains(body.name) {
            let field = SolarLandscape(body:body)
            var solids:[ScenicSolid] = []
            let count = body.name == "Earth" ? 180 : body.name == "Venus" ? 96 : 85
            for i in 0..<count {
                let x:Float, z:Float, radius:Float, height:Float
                switch body.name {
                case "Earth":
                    z = -12000+Float(i/2)*260
                    let side:Float = i.isMultiple(of:2) ? -1:1
                    x = field.riverCenter(z:z)+side*(240+Float(i%7)*70)
                    radius = 5; height = Float(65+i%5*16)
                case "Venus":
                    let angle = Float(i)*2.39996, distance = Float(900+i%12*180)
                    x = -900+cos(angle)*distance; z = -3600+sin(angle)*distance
                    radius = Float(18+i%4*7); height = Float(20+i%5*14)
                default:
                    z = -11000+Float(i)*230
                    x = Float(i%2 == 0 ? -1:1)*(1800+Float(i%7)*160)
                    radius = 45; height = 36
                }
                if body.name == "Earth",EarthCity.clearsScenery(x:x,z:z) { continue }
                solids.append(.init(base:[x,field.height(x:x,z:z)-2,z],radius:radius,height:height))
            }
            result[body.name] = solids
        }
        return result
    }()
    var scenerySolids:[ScenicSolid] { Self.scenicSolidCache[body.name] ?? [] }
    func impact(from a:SIMD3<Float>,to b:SIMD3<Float>,radius:Float) -> Bool {
        if body.name == AetherPlanet.name, AetherWorldDetails.enabled, let asset = try? AetherPlanet.prepared.get(),
           AetherWorldDetails.hits(from:a,to:b,radius:radius,placements:asset.scatter.placements) { return true }
        if body.name == AetherPlanet.name, AetherPlanet.hitsArch(from:a,to:b,radius:radius) { return true }
        guard !body.isCloudWorld else { return b.y < -400 }
        if body.name == "Earth",EarthCity.hits(from:a,to:b,radius:radius) { return true }
        if scenerySolids.contains(where:{ $0.hits(from:a,to:b,radius:radius) }) { return true }
        let steps = min(256,max(1,Int(ceil(simd_distance(a,b)/20))))
        for index in 0...steps {
            let point = a+(b-a)*Float(index)/Float(steps)
            if point.y-radius <= max(body.name == "Earth" ? 0 : -10000,height(x:point.x,z:point.z)) { return true }
        }
        return false
    }
}

extension CatalogStar {
    var featureFact: String? {
        switch hip {
        case 32349: return "Sirius is the brightest star in Earth's night sky. Its faint companion, Sirius B, is a white dwarf."
        case 27989: return "Betelgeuse is a red supergiant marking Orion's shoulder. Its swollen outer layers give it its warm colour."
        case 11767: return "Polaris lies close to Earth's north celestial pole, making it a useful guide to north. It appears almost still as the sky turns."
        default: return nil
        }
    }
}

/// Shared by star rendering and taps, including the same stylised black-hole deflection.
enum StarSkyGeometry {
    static func direction(position:SIMD3<Double>,observer:SIMD3<Double>,lens:SIMD3<Float>?) -> SIMD3<Float> {
        let delta = position-observer
        var direction = simd_length(delta)>0.000001 ? SIMD3<Float>(simd_normalize(delta)):SIMD3<Float>(0,0,-1)
        if let lens {
            let distance = simd_length(lens)
            if distance > 1 && distance < 8000 {
                let axis = lens/distance
                let angle = acos(clamp(simd_dot(direction,axis),-1,1))
                let tangent = direction-axis*simd_dot(direction,axis)
                if angle < 0.35 && simd_length_squared(tangent)>0.000001 {
                    let ringAngle = atan(200/max(distance,160))
                    let apparent = (angle+sqrt(angle*angle+4*ringAngle*ringAngle))/2
                    let faded = angle+(apparent-angle)*pow(1-angle/0.35,2)
                    direction = axis*cos(faded)+simd_normalize(tangent)*sin(faded)
                }
            }
        }
        return direction
    }
}


/// One bounded city recipe drives the plateau, visible blocks and swept contacts.
enum EarthCity {
    private static let earth=SolarLandscape(body:SolarBody.all.first { $0.name == "Earth" }!)
    static let center=SIMD2<Float>(earth.riverCenter(z:-6200)+1450,-6200)
    static let foundation:Float=earth.riverLevel(z:center.y)+70
    struct Building {
        let center:SIMD3<Float>,size:SIMD3<Float>
        func hits(from a:SIMD3<Float>,to b:SIMD3<Float>,radius:Float) -> Bool {
            let low=center-size/2-SIMD3(repeating:radius),high=center+size/2+SIMD3(repeating:radius),delta=b-a
            var enter:Float=0,leave:Float=1
            for axis in 0..<3 {
                if abs(delta[axis])<0.00001 { if a[axis]<low[axis] || a[axis]>high[axis] { return false } }
                else {
                    let first=(low[axis]-a[axis])/delta[axis],second=(high[axis]-a[axis])/delta[axis]
                    enter=max(enter,min(first,second));leave=min(leave,max(first,second))
                    if enter>leave { return false }
                }
            }
            return true
        }
    }
    static let buildings:[Building] = (-3...3).flatMap { i -> [Building] in
        (-3...3).compactMap { j in
            guard i != 0,j != 0 else { return nil }
            let height:Float=(i == -1 && j == -1) ? 260:70+Float(abs(i*71+j*113)%145)
            let width:Float=110+Float(abs(i*29+j*19)%30)
            return Building(center:[center.x+Float(i)*230,foundation+height/2,center.y+Float(j)*230],size:[width,height,width])
        }
    }
    static func flattening(x:Float,z:Float) -> Float {
        let d=max(abs(x-center.x),abs(z-center.y)),t=clamp((d-850)/750,0,1)
        let riverDistance=abs(x-earth.riverCenter(z:z)),bank=clamp((riverDistance-320)/100,0,1)
        return (1-t*t*(3-2*t))*bank*bank*(3-2*bank)
    }
    static func clearsScenery(x:Float,z:Float) -> Bool {
        abs(x-center.x)<900 && abs(z-center.y)<900
    }
    static func hits(from a:SIMD3<Float>,to b:SIMD3<Float>,radius:Float) -> Bool {
        guard min(a.x,b.x)-radius<center.x+850,max(a.x,b.x)+radius>center.x-850,
              min(a.z,b.z)-radius<center.y+850,max(a.z,b.z)+radius>center.y-850 else { return false }
        return buildings.contains { $0.hits(from:a,to:b,radius:radius) }
    }
}


enum EarthRiver {
    static func surface(z:Float,across:Float=0,raise:Float=0) -> SIMD3<Float> {
        let field=EarthWildlife.field,x=field.riverCenter(z:z)+across
        return [x,max(field.riverLevel(z:z),field.height(x:x,z:z)+1.2)+raise,z]
    }
}
