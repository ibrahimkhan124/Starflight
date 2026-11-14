import Foundation
import simd

enum HomeLandingPhase { case approaching, landed, departing }

/// Repulsor landing follows three checked legs: climb, align above the pad, descend.
/// The ship remains parked until an explicit departure, including while visiting its room.
struct HomeDocking {
    static let captureRadius:Float = 750
    private(set) var plot:CityPlot?
    private(set) var phase:HomeLandingPhase = .approaching
    private var waypoints:[SIMD3<Float>] = []
    private var targetHeading:Float = 0
    private var exitSpeed:Float = 35
    var landed:Bool { plot != nil && phase == .landed }
    static func padPosition(_ plot:CityPlot,aircraft:AircraftType) -> SIMD3<Float> {
        // The luminous deck tops out at 17.5 m. Account for body and probe radii.
        plot.position+[0,19.5+aircraft.bodyRadius*2,225]
    }
    static func distance(to plot:CityPlot,state:FlightState,aircraft:AircraftType) -> Float {
        simd_distance(state.position,padPosition(plot,aircraft:aircraft))
    }
    static func approachSpeedLimit(state:FlightState,plot:CityPlot,aircraft:AircraftType) -> Float? {
        let delta = padPosition(plot,aircraft:aircraft)-state.position, distance = simd_length(delta)
        guard distance>1,distance<1100,simd_dot(state.velocity,delta/distance)>10 else { return nil }
        return 35
    }
    mutating func begin(_ plot:CityPlot,state:inout FlightState,aircraft:AircraftType,housing:CityHousing) -> Bool {
        guard self.plot == nil,housing.owned.contains(plot),
              Self.distance(to:plot,state:state,aircraft:aircraft)<Self.captureRadius else { return false }
        let pad = Self.padPosition(plot,aircraft:aircraft)
        let height = max(260,state.position.y)
        let points:[SIMD3<Float>] = [[state.position.x,height,state.position.z],[pad.x,height,pad.z],pad]
        guard Self.clearPath([state.position]+points,aircraft:aircraft,housing:housing) else { return false }
        self.plot = plot; phase = .approaching; waypoints = points; targetHeading = .pi
        state.velocity = .zero; state.airspeed = 0; state.pitch = 0; state.roll = 0; state.stalled = false
        return true
    }
    static func clearPath(_ points:[SIMD3<Float>],aircraft:AircraftType,housing:CityHousing) -> Bool {
        let city = PlanetExploration(planet:.coruscant)
        // A sphere enclosing every yaw/pitch orientation prevents even the largest wing clipping.
        let span = sqrt(pow(aircraft.wingspan/2,2)+pow(aircraft.length/2,2))
        for (from,to) in zip(points,points.dropFirst()) {
            let steps = max(1,Int(ceil(simd_distance(from,to)/8)))
            for i in 0...steps {
                let point = from+(to-from)*Float(i)/Float(steps)
                // Use a flat footprint for the wing envelope, with the real body height.
                for offset:SIMD3<Float> in [[0,0,0],[span,0,0],[-span,0,0],[0,0,span],[0,0,-span],[0,-aircraft.bodyRadius,0]] {
                    let probe = point+offset
                    if city.clearance(at:probe)<=aircraft.bodyRadius || city.hitsObstacle(at:probe,radius:aircraft.bodyRadius) || housing.hits(probe,radius:aircraft.bodyRadius) { return false }
                }
            }
        }
        return true
    }
    /// A return value of true signals the one-time touchdown.
    mutating func advance(state:inout FlightState,dt:Float) -> Bool {
        guard plot != nil,dt.isFinite,dt>0,dt<=0.25 else { return false }
        state.pitch = 0; state.roll = 0; state.stalled = false
        if phase == .landed {
            state.velocity = .zero; state.airspeed = 0; state.heading = .pi
            return false
        }
        guard let target = waypoints.first else { return false }
        let delta = target-state.position, distance = simd_length(delta)
        let speed:Float = phase == .departing ? 38 : abs(delta.y)>4 && abs(delta.x)+abs(delta.z)<4 ? 25:48
        let move = min(distance,speed*dt)
        let velocity = distance > 0.001 ? delta/distance*(move/dt):.zero
        state.position += velocity*dt; state.velocity = velocity; state.airspeed = simd_length(velocity)
        let turn = atan2(sin(targetHeading-state.heading),cos(targetHeading-state.heading))
        state.heading += turn*min(1,dt*3)
        if simd_distance(state.position,target)<0.05 {
            state.position = target; waypoints.removeFirst()
            if waypoints.isEmpty {
                if phase == .departing {
                    self.plot = nil; state.heading = .pi; state.airspeed = exitSpeed
                    state.velocity = state.forward*exitSpeed
                } else {
                    phase = .landed; state.velocity = .zero; state.airspeed = 0; state.heading = .pi
                    return true
                }
            }
        }
        return false
    }
    mutating func depart(state:inout FlightState,aircraft:AircraftType,housing:CityHousing) -> Bool {
        guard let plot,landed else { return false }
        let points:[SIMD3<Float>] = [state.position,plot.position+[0,180,225],plot.position+[0,180,550]]
        guard Self.clearPath(points,aircraft:aircraft,housing:housing) else { return false }
        phase = .departing; waypoints = Array(points.dropFirst()); targetHeading = .pi
        exitSpeed = 45; state.velocity = .zero; return true
    }
    mutating func reset() { plot = nil; phase = .approaching; waypoints = [] }
}

/// Walking is local to the room and cannot move the aircraft or earn flight rewards.
struct HomeRoomWalk {
    var position:SIMD2<Float> = HomeRoomGeometry.walkingStart
    var yaw:Float = 0
    var pitch:Float = 0
    var items:Set<InteriorItem> = []
    var area:HomeArea = .room
    var layout:[InteriorItem:RoomPlacement] = [:]
    private(set) var velocity:SIMD2<Float> = .zero
    mutating func stop() { velocity = .zero }
    mutating func look(dx:Float,dy:Float) {
        guard dx.isFinite,dy.isFinite else { return }
        yaw = (yaw-dx*0.004).truncatingRemainder(dividingBy:2 * .pi)
        pitch = clamp(pitch-dy*0.004,-1.1,1.1)
    }
    func blocked(_ point:SIMD2<Float>) -> Bool {
        let limit = HomeRoomGeometry.walkingLimit
        if !point.x.isFinite || !point.y.isFinite || abs(point.x)>limit.x || abs(point.y)>limit.y { return true }
        return items.contains { item in
            guard item.blocksWalking,item.area == area else { return false }
            let p = HomeRoomLayout.placement(item,in:layout), half = p.halfSize(for:item)+SIMD2<Float>(repeating:0.25)
            return abs(point.x-p.x)<half.x && abs(point.y-p.z)<half.y
        }
    }
    mutating func move(_ input:SIMD2<Float>,dt:Float,brisk:Bool = false) {
        guard dt.isFinite,dt>0,dt<=0.1,input.x.isFinite,input.y.isFinite else { return }
        var axis = input
        if simd_length(axis)>1 { axis = simd_normalize(axis) }
        let target = (SIMD2<Float>(cos(yaw),-sin(yaw))*axis.x + SIMD2<Float>(-sin(yaw),-cos(yaw))*axis.y)*(brisk ? 5.5:3)
        let response:Float = simd_length_squared(axis)<0.001 ? 22:14
        velocity += (target-velocity)*(1-exp(-response*dt))
        if simd_length_squared(velocity)<0.0001 { velocity = .zero }
        let delta = velocity*dt
        // Short swept steps keep brisk walking from skipping furniture corners.
        let steps = max(1,Int(ceil(simd_length(delta)/0.12)))
        let step = delta/Float(steps)
        for _ in 0..<steps {
            if !blocked(position+SIMD2<Float>(step.x,0)) { position.x += step.x } else { velocity.x = 0 }
            if !blocked(position+SIMD2<Float>(0,step.y)) { position.y += step.y } else { velocity.y = 0 }
        }
    }
}
