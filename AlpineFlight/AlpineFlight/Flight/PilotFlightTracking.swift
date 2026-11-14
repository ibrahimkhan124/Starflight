import Foundation
import simd

/// Samples the real integrated flight path. Teleports, loading and menus never add distance.
struct PilotFlightTracker {
    private(set) var record:PilotFlightRecord
    private var lastPosition:SIMD3<Float>?
    private var lastHeading:Float?
    private var region:String?
    private var shaveTime:Float = 0
    private var shaveRecovery:Float = 0
    private var shaveBlocked = false
    private var shaveCooldown:Float = 0
    private var turnAngle:Float = 0
    private var turnTime:Float = 0
    private var turnDirection:Float = 0
    private var turnCounted = false
    private var climbTime:Float = 0
    private var climbStart:Float = 0
    private var climbCounted = false
    private var hothNorth = false
    init(at date:Date = Date(),aircraft:String,route:String) {
        record = PilotFlightRecord(startedAt:date,endedAt:date,aircraft:aircraft,route:route)
    }
    mutating func relocate() {
        lastPosition = nil; lastHeading = nil; region = nil; hothNorth = false
        resetManeuvers()
    }
    private mutating func resetManeuvers() {
        shaveTime = 0; shaveRecovery = 0; shaveBlocked = false
        turnAngle = 0; turnTime = 0; turnCounted = false; turnDirection = 0
        climbTime = 0; climbCounted = false
    }
    mutating func observe(state:FlightState,clearance:Float?,planet:SpacePlanet?,region newRegion:String,canManeuver:Bool,countDistance:Bool = true,dt:Float) {
        guard dt.isFinite,dt > 0,dt <= 0.1,
              state.position.x.isFinite,state.position.y.isFinite,state.position.z.isFinite,
              state.heading.isFinite,state.roll.isFinite,state.pitch.isFinite,state.airspeed.isFinite else { return }
        record.seconds += Double(dt)
        record.endedAt = record.startedAt.addingTimeInterval(record.seconds)
        if state.stalled { record.stallSeconds += Double(dt) }
        let moved = lastPosition.map { simd_distance($0,state.position) } ?? 0
        let displaced = region != newRegion || moved > max(100,state.airspeed*dt*4+10)
        let previousHeading = lastHeading
        if displaced { resetManeuvers(); hothNorth = false }
        else if lastPosition != nil && countDistance { record.metres += Double(moved) }
        lastPosition = state.position; lastHeading = state.heading; region = newRegion
        if let planet { record.visitedPlanets.insert(planet.rawValue) }
        if planet == .hoth {
            if state.position.z <= -6000 { hothNorth = true }
            if hothNorth && simd_distance(SIMD2<Float>(state.position.x,state.position.z),SIMD2<Float>(0,8400)) <= 800 {
                record.hothRoundTrip = true
            }
        }
        guard !displaced,canManeuver,!state.stalled,state.airspeed >= 45 else { resetManeuvers(); shaveBlocked = true; return }
        let ground = clearance.flatMap { $0.isFinite ? $0:nil }
        shaveCooldown = max(0,shaveCooldown-dt)
        if let ground {
            if ground < 8 { shaveBlocked = true }
            if ground >= 8 && ground <= 25 && !shaveBlocked && shaveCooldown == 0 {
                shaveTime += dt; shaveRecovery = 0
            } else if ground >= 50 {
                shaveRecovery += dt
                if shaveRecovery >= 1 {
                    if shaveTime >= 0.25 && !shaveBlocked && shaveCooldown == 0 {
                        record.closeShaves += 1; shaveCooldown = 20
                    }
                    shaveTime = 0; shaveBlocked = false
                }
            } else { shaveRecovery = 0 }
        }
        let safelyClear = ground.map { $0 >= 60 } ?? true
        if safelyClear,abs(state.roll) >= 0.18,abs(state.roll) <= 1.6,abs(state.pitch) <= 0.6,let previousHeading {
            let delta = atan2(sin(state.heading-previousHeading),cos(state.heading-previousHeading))
            let direction:Float = delta < 0 ? -1:1
            if abs(delta)/dt <= 1.2 {
                if turnDirection != 0 && direction != turnDirection && abs(delta) > 0.0001 { turnAngle = 0; turnTime = 0 }
                if abs(delta) > 0.0001 { turnDirection = direction }
                turnAngle += abs(delta); turnTime += dt
                if !turnCounted && turnAngle >= .pi/2 && turnTime >= 3 { record.controlledTurns += 1; turnCounted = true }
            }
        } else { turnAngle = 0; turnTime = 0; turnCounted = false; turnDirection = 0 }
        if ground != nil,safelyClear,state.velocity.y > 3,abs(state.roll) <= 0.9 {
            if climbTime == 0 { climbStart = state.position.y }
            climbTime += dt
            if !climbCounted && climbTime >= 10 && state.position.y-climbStart >= 100 {
                record.soaringClimbs += 1; climbCounted = true
            }
        } else { climbTime = 0; climbCounted = false }
    }
    func snapshot(at date:Date = Date()) -> PilotFlightRecord {
        var value = record; value.endedAt = date; return value
    }
    func finished(_ outcome:PilotFlightOutcome,at date:Date = Date()) -> PilotFlightRecord {
        var value = snapshot(at:date); value.outcome = outcome; return value
    }
}
