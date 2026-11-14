import XCTest
import RealityKit
import SceneKit
import AVFoundation
import simd
@testable import AlpineFlight

final class CityExpansionTests:XCTestCase {
    @MainActor
    func testOriginalHomeMusicIsDecodableAndEightSecondsLong() throws {
        let player = try AVAudioPlayer(data:HomeLoungeAudio.wave,fileTypeHint:AVFileType.wav.rawValue)
        XCTAssertEqual(player.duration,8,accuracy:0.01); XCTAssertEqual(player.numberOfChannels,1)
        XCTAssertEqual(player.format.sampleRate,16000)
    }
    @MainActor
    func testExteriorFurnitureIsBatchedVisibleAndUpdatesOnlyWhenHousingChanges() {
        var housing = CityHousing(); housing.build(.aurora); XCTAssertTrue(housing.furnish(.lantern,in:.aurora))
        let renderer = CityResidenceRenderer(); renderer.update(housing)
        let home = renderer.root.children.first { $0.name == CityPlot.aurora.name }!
        let terrace = home.findEntity(named:"Editable terrace")!
        XCTAssertTrue(home.isEnabled); XCTAssertFalse(terrace.children.isEmpty)
        let ids = terrace.children.map(\.id)
        renderer.update(housing); XCTAssertEqual(terrace.children.map(\.id),ids)
        func glowingBatches() -> Int { terrace.children.compactMap { $0 as? ModelEntity }.filter { $0.model?.materials.first is UnlitMaterial }.count }
        XCTAssertGreaterThan(glowingBatches(),0)
        XCTAssertTrue(housing.interact(.lantern,in:.aurora)); renderer.update(housing)
        XCTAssertEqual(glowingBatches(),0); XCTAssertNotEqual(terrace.children.map(\.id),ids)
        let bounds = terrace.visualBounds(relativeTo:home)
        XCTAssertLessThan(bounds.max.x,-90)
        XCTAssertEqual(bounds.center.z,HomeArea.terraceOrigin.z,accuracy:1)
    }
    func testExpandedCatalogueFitsAndPreservesPricesOwnershipAndLegacySave() throws {
        XCTAssertEqual(InteriorItem.allCases.count,22)
        XCTAssertEqual(InteriorItem.allCases.filter { $0.area == .terrace }.count,6)
        XCTAssertEqual(InteriorItem.allCases.filter { $0.layer == .wall }.count,2)
        var wallet = FlightEconomy(); wallet.earn(lowFlightPoints:40000)
        XCTAssertTrue(wallet.buyHome(.aurora))
        for item in InteriorItem.allCases { XCTAssertTrue(wallet.buyInterior(item,in:.aurora),item.name) }
        XCTAssertEqual(wallet.quarterCredits,40000-4*(CityPlot.aurora.price+InteriorItem.allCases.reduce(0) { $0+$1.price }))
        let housing = wallet.housing!, layout = housing.layout(in:.aurora)
        for item in InteriorItem.allCases where item.movable {
            XCTAssertTrue(HomeRoomLayout.canPlace(item,at:layout[item]!,items:housing.items(in:.aurora),layout:layout),item.name)
        }
        let unchanged = wallet; XCTAssertFalse(wallet.buyInterior(.nebulaPainting,in:.aurora)); XCTAssertEqual(wallet,unchanged)
        var json = try JSONSerialization.jsonObject(with:JSONEncoder().encode(wallet)) as! [String:Any]
        var home = json["housing"] as! [String:Any]; home.removeValue(forKey:"itemStates"); json["housing"] = home
        let decoded = try JSONDecoder().decode(FlightEconomy.self,from:JSONSerialization.data(withJSONObject:json))
        XCTAssertEqual(decoded.housing?.layout(in:.aurora),layout); XCTAssertEqual(decoded.quarterCredits,wallet.quarterCredits)
    }
    func testWallCeilingAndOutdoorPlacementUseIndependentLayersAndWalking() {
        let items:Set<InteriorItem> = [.readingChair,.pendant,.patioLounge,.nebulaPainting]
        let layout:[InteriorItem:RoomPlacement] = [.readingChair:RoomPlacement(x:0,z:0),.pendant:RoomPlacement(x:0,z:0),.patioLounge:RoomPlacement(x:0,z:0)]
        for item in [InteriorItem.readingChair,.pendant,.patioLounge] { XCTAssertTrue(HomeRoomLayout.canPlace(item,at:layout[item]!,items:items,layout:layout)) }
        let art = InteriorItem.nebulaPainting.placing(RoomPlacement(x:5,z:3.26,turns:2),snap:true)
        XCTAssertEqual(art,RoomPlacement(x:-19.75,z:3.5))
        XCTAssertTrue(HomeRoomLayout.canPlace(.nebulaPainting,at:art,items:items,layout:layout))
        XCTAssertFalse(HomeRoomLayout.canPlace(.nebulaPainting,at:RoomPlacement(x:0,z:0),items:items,layout:layout))
        var walk = HomeRoomWalk(); walk.items = [.pendant]; walk.layout = layout
        XCTAssertFalse(walk.blocked(.zero))
        walk.items = [.patioLounge]; XCTAssertFalse(walk.blocked(.zero))
        walk.area = .terrace; XCTAssertTrue(walk.blocked(.zero))
        let target = HomeInteraction.nearest(from:[0,2],area:.room,items:items,layout:layout)
        XCTAssertEqual(target,.readingChair)
        XCTAssertNil(HomeInteraction.nearest(from:[18,14],area:.terrace,items:items,layout:layout))
    }
    func testInteractionsPersistWithoutRewardsAndStoredItemsKeepTheirState() throws {
        var wallet = FlightEconomy(); wallet.earn(lowFlightPoints:40000)
        XCTAssertTrue(wallet.buyHome(.aurora)); XCTAssertTrue(wallet.buyHome(.obsidian))
        for item in [InteriorItem.floorLamp,.cabinet,.holotable,.planter,.fountain,.jukebox] { XCTAssertTrue(wallet.buyInterior(item,in:.aurora)) }
        let balance = wallet.quarterCredits
        XCTAssertFalse(wallet.housing!.state(.cabinet,in:.aurora).enabled)
        XCTAssertTrue(wallet.interactInterior(.cabinet,in:.aurora)); XCTAssertTrue(wallet.housing!.state(.cabinet,in:.aurora).enabled)
        XCTAssertTrue(wallet.interactInterior(.floorLamp,in:.aurora)); XCTAssertFalse(wallet.housing!.state(.floorLamp,in:.aurora).enabled)
        XCTAssertTrue(wallet.interactInterior(.fountain,in:.aurora)); XCTAssertFalse(wallet.housing!.state(.fountain,in:.aurora).enabled)
        for _ in 0..<3 { XCTAssertTrue(wallet.interactInterior(.holotable,in:.aurora)) }
        XCTAssertEqual(wallet.housing!.state(.holotable,in:.aurora).variant,0)
        for _ in 0..<5 { XCTAssertTrue(wallet.interactInterior(.planter,in:.aurora)) }
        XCTAssertEqual(wallet.housing!.state(.planter,in:.aurora).variant,1)
        XCTAssertTrue(wallet.toggleInterior(.floorLamp,in:.aurora)); XCTAssertFalse(wallet.interactInterior(.floorLamp,in:.aurora))
        XCTAssertTrue(wallet.toggleInterior(.floorLamp,in:.aurora)); XCTAssertFalse(wallet.housing!.state(.floorLamp,in:.aurora).enabled)
        XCTAssertFalse(wallet.interactInterior(.floorLamp,in:.obsidian))
        XCTAssertEqual(wallet.quarterCredits,balance)
        let loaded = try JSONDecoder().decode(FlightEconomy.self,from:JSONEncoder().encode(wallet)); XCTAssertEqual(loaded,wallet)
        XCTAssertTrue(loaded.housing!.state(.floorLamp,in:.obsidian).enabled)
    }
    func testOutdoorMeshesMatchLayoutKeepLandingTerraceClearAndCoverFootprints() {
        for item in InteriorItem.allCases where item.index>=8 {
            for enabled in [false,true] {
                let parts = HomeFurnitureDesign.parts(item,state:HomeItemState(enabled:enabled,variant:1))
                XCTAssertFalse(parts.isEmpty,item.name)
                for part in parts {
                    XCTAssertLessThanOrEqual(abs(part.center.x)+part.size.x/2,item.roomHalfSize.x+0.01,item.name)
                    XCTAssertLessThanOrEqual(abs(part.center.z)+part.size.z/2,item.roomHalfSize.y+0.01,item.name)
                }
            }
        }
        let on = HomeFurnitureDesign.parts(.fountain,state:HomeItemState())
        let off = HomeFurnitureDesign.parts(.fountain,state:HomeItemState(enabled:false))
        XCTAssertGreaterThan(on.count,off.count)
        let rotated = HomeFurniturePart(center:[1,2,3],size:[2,4,6],tint:.gold).placed(at:RoomPlacement(x:5,z:6,turns:1))
        XCTAssertEqual(rotated.center.x,8,accuracy:0.001); XCTAssertEqual(rotated.center.z,5,accuracy:0.001); XCTAssertEqual(rotated.size,SIMD3<Float>(6,4,2))
        let items = Set(InteriorItem.allCases.filter { $0.area == .terrace })
        let parts = HomeFurnitureDesign.terraceParts(items:items,layout:[:],states:[:])
        for part in parts {
            let world = part.placed(at:RoomPlacement(x:0,z:0),origin:HomeArea.terraceOrigin,scale:HomeArea.terraceScale)
            XCTAssertLessThan(world.center.x+world.size.x/2,-90)
        }
    }
    @MainActor
    func testNewSceneArtworkLightsCabinetAndSeatingUseSavedPlacement() {
        let on = HomeFurnishingScene.furniture(.floorLamp,state:HomeItemState())
        let off = HomeFurnishingScene.furniture(.floorLamp,state:HomeItemState(enabled:false))
        XCTAssertTrue(on.childNodes.contains { $0.light != nil }); XCTAssertFalse(off.childNodes.contains { $0.light != nil })
        XCTAssertEqual(HomePaintingArt.image(.nebulaPainting).size,CGSize(width:600,height:420))
        let room = HomeRoomController()
        let chair = RoomPlacement(x:4,z:10)
        room.configure(plot:.aurora,items:[.readingChair,.patioLounge],layout:[.readingChair:chair,.patioLounge:chair],reduceMotion:true,sound:false)
        let position = room.walk.position
        room.sit(.patioLounge); XCTAssertNil(room.seatedItem)
        room.sit(.readingChair); XCTAssertEqual(room.seatedItem,.readingChair); XCTAssertEqual(room.walk.position,position)
        room.stand(); XCTAssertNil(room.seatedItem); XCTAssertEqual(room.walk.position,position)
        room.visit(.terrace); XCTAssertEqual(room.area,.terrace); XCTAssertNil(room.seatedItem)
        room.configure(plot:.aurora,items:[.patioLounge],layout:[.patioLounge:chair],reduceMotion:true,sound:false)
        room.sit(.patioLounge); XCTAssertEqual(room.seatedItem,.patioLounge)
        room.stop()
    }
    func testArrangementUndoRedoBranchesAndKeepsOnlyFortyEdits() {
        var history = HomeArrangementHistory()
        let a:[InteriorItem:RoomPlacement] = [.holotable:RoomPlacement(x:0,z:0)]
        let b:[InteriorItem:RoomPlacement] = [.holotable:RoomPlacement(x:1,z:0)]
        let c:[InteriorItem:RoomPlacement] = [.holotable:RoomPlacement(x:2,z:0)]
        history.record(before:a,after:a); XCTAssertNil(history.undoTarget)
        history.record(before:a,after:b); XCTAssertEqual(history.undoTarget,a)
        history.didUndo(current:b); XCTAssertEqual(history.redoTarget,b); XCTAssertNil(history.undoTarget)
        history.didRedo(current:a); XCTAssertEqual(history.undoTarget,a); XCTAssertNil(history.redoTarget)
        history.didUndo(current:b)
        history.record(before:a,after:c); XCTAssertNil(history.redoTarget)
        history = HomeArrangementHistory()
        for i in 0..<50 {
            history.record(before:[.holotable:RoomPlacement(x:Float(i),z:0)],after:[.holotable:RoomPlacement(x:Float(i+1),z:0)])
        }
        var count = 0
        while history.undoTarget != nil { history.didUndo(current:c); count += 1 }
        XCTAssertEqual(count,40)
    }
    func testRestoreArrangementIsAtomicPreservesWalletAndRejectsChangedOwnership() throws {
        var wallet = FlightEconomy(); wallet.earn(lowFlightPoints:40000)
        XCTAssertTrue(wallet.buyHome(.aurora)); XCTAssertTrue(wallet.buyInterior(.holotable,in:.aurora))
        XCTAssertTrue(wallet.buyInterior(.aquarium,in:.aurora))
        let original = wallet.housing!.layout(in:.aurora), balance = wallet.quarterCredits
        var changed = original
        // Swap sets atomically. Neither intermediate single-item placement would fit.
        changed[.holotable] = original[.aquarium]; changed[.aquarium] = original[.holotable]
        XCTAssertTrue(wallet.restoreInteriorLayout(changed,in:.aurora))
        XCTAssertEqual(wallet.housing!.layout(in:.aurora),changed)
        XCTAssertEqual(wallet.quarterCredits,balance)
        let committed = wallet
        var invalid = changed; invalid[.holotable] = invalid[.aquarium]
        XCTAssertFalse(wallet.restoreInteriorLayout(invalid,in:.aurora)); XCTAssertEqual(wallet,committed)
        invalid = changed; invalid[.holotable] = RoomPlacement(x:100,z:0)
        XCTAssertFalse(wallet.restoreInteriorLayout(invalid,in:.aurora)); XCTAssertEqual(wallet,committed)
        XCTAssertFalse(wallet.restoreInteriorLayout(original,in:.obsidian)); XCTAssertEqual(wallet,committed)
        XCTAssertTrue(wallet.toggleInterior(.aquarium,in:.aurora))
        let stored = wallet
        XCTAssertFalse(wallet.restoreInteriorLayout(original,in:.aurora)); XCTAssertEqual(wallet,stored)
        let reduced = wallet.housing!.layout(in:.aurora)
        XCTAssertTrue(wallet.restoreInteriorLayout(reduced,in:.aurora))
        XCTAssertTrue(wallet.toggleInterior(.aquarium,in:.aurora))
        XCTAssertEqual(wallet.housing!.layout(in:.aurora)[.aquarium],changed[.aquarium])
        let reloaded = try JSONDecoder().decode(FlightEconomy.self,from:JSONEncoder().encode(wallet))
        XCTAssertEqual(reloaded,wallet); XCTAssertEqual(wallet.quarterCredits,balance)
    }
    func testPlacementGridAndExplanationsDistinguishWallsEntranceAndFurniture() {
        XCTAssertEqual(RoomPlacement(x:2.26,z:-3.24,turns:3).snapped,RoomPlacement(x:2.5,z:-3,turns:3))
        let items:Set<InteriorItem> = [.holotable,.aquarium]
        XCTAssertTrue(HomeRoomLayout.placementIssue(.holotable,at:RoomPlacement(x:30,z:0),items:items,layout:[:])!.contains("wall"))
        let door = HomeRoomGeometry.entrance
        XCTAssertTrue(HomeRoomLayout.placementIssue(.holotable,at:RoomPlacement(x:door.x,z:door.y),items:items,layout:[:])!.contains("entrance"))
        XCTAssertTrue(HomeRoomLayout.placementIssue(.holotable,at:InteriorItem.aquarium.defaultPlacement,items:items,layout:[:])!.contains(InteriorItem.aquarium.name))
        XCTAssertNil(HomeRoomLayout.placementIssue(.holotable,at:RoomPlacement(x:12,z:8),items:items,layout:[:]))
    }
    func testWalkingAcceleratesBrakesAndBriskMovementDoesNotSkipFurniture() {
        var walk = HomeRoomWalk(); walk.position = [0,12]
        walk.move([0,1],dt:1/60)
        XCTAssertGreaterThan(simd_length(walk.velocity),0); XCTAssertLessThan(simd_length(walk.velocity),3)
        for _ in 0..<60 { walk.move([0,1],dt:1/60) }
        let released = walk.position
        for _ in 0..<30 { walk.move(.zero,dt:1/60) }
        XCTAssertLessThan(simd_distance(released,walk.position),0.2)
        XCTAssertEqual(walk.velocity,.zero)
        var normal = HomeRoomWalk(), brisk = HomeRoomWalk(), sixty = HomeRoomWalk()
        for _ in 0..<30 { normal.move([0,1],dt:1/30); brisk.move([0,1],dt:1/30,brisk:true) }
        for _ in 0..<60 { sixty.move([0,1],dt:1/60) }
        XCTAssertGreaterThan(simd_distance(brisk.position,HomeRoomGeometry.walkingStart),simd_distance(normal.position,HomeRoomGeometry.walkingStart)*1.6)
        XCTAssertEqual(normal.position.y,sixty.position.y,accuracy:0.04)
        brisk.position = [0,3]; brisk.stop(); brisk.items = [.jukebox]; brisk.layout = [.jukebox:RoomPlacement(x:0,z:0)]
        for _ in 0..<100 { brisk.move([0,1],dt:0.1,brisk:true) }
        XCTAssertGreaterThanOrEqual(brisk.position.y,0.95); XCTAssertFalse(brisk.blocked(brisk.position))
        brisk.stop(); XCTAssertEqual(brisk.velocity,.zero)
    }
    func testEveryShipCanLandParkAndDepartEveryHomeWithoutCrossingSolidGeometry() {
        for plot in CityPlot.allCases {
            var housing = CityHousing(); housing.build(plot)
            let city = PlanetExploration(planet:.coruscant)
            for aircraft in AircraftType.allCases {
                var landing = HomeDocking(), state = FlightState()
                state.position = plot.arrival; state.velocity = [0,0,-100]; state.airspeed = 100
                XCTAssertTrue(landing.begin(plot,state:&state,aircraft:aircraft,housing:housing),plot.name+aircraft.name)
                var touchdowns = 0
                for tick in 0..<3600 {
                    let old = state.position
                    if landing.advance(state:&state,dt:1/120) { touchdowns += 1 }
                    XCTAssertLessThanOrEqual(simd_distance(old,state.position),0.401)
                    if tick.isMultiple(of:12) {
                        for probe in aircraft.collisionProbes {
                            let p = state.position+state.orientation.act(probe)
                            XCTAssertFalse(housing.hits(p,radius:aircraft.bodyRadius),aircraft.name)
                            XCTAssertFalse(city.hitsObstacle(at:p,radius:aircraft.bodyRadius),aircraft.name)
                        }
                    }
                    if landing.landed { break }
                }
                XCTAssertTrue(landing.landed,aircraft.name); XCTAssertEqual(touchdowns,1)
                let parked = state.position
                for _ in 0..<60 { XCTAssertFalse(landing.advance(state:&state,dt:1/30)); XCTAssertEqual(state.position,parked) }
                XCTAssertEqual(state.airspeed,0); XCTAssertEqual(state.velocity,.zero)
                XCTAssertFalse(landing.begin(plot,state:&state,aircraft:aircraft,housing:housing))
                XCTAssertTrue(landing.depart(state:&state,aircraft:aircraft,housing:housing))
                for _ in 0..<3000 {
                    _ = landing.advance(state:&state,dt:1/120)
                    XCTAssertFalse(housing.hits(state.position,radius:aircraft.bodyRadius))
                    if landing.plot == nil { break }
                }
                XCTAssertNil(landing.plot); XCTAssertEqual(state.airspeed,45)
                XCTAssertGreaterThan(state.velocity.z,40)
            }
        }
    }
    func testHomeApproachAssistOnlySlowsInboundFlight() {
        var state = FlightState(); state.position = CityPlot.aurora.arrival; state.velocity = [0,0,-80]
        XCTAssertEqual(HomeDocking.approachSpeedLimit(state:state,plot:.aurora,aircraft:.kestrel),35)
        state.velocity = [0,0,80]
        XCTAssertNil(HomeDocking.approachSpeedLimit(state:state,plot:.aurora,aircraft:.kestrel))
        state.position.z += 2000; state.velocity = [0,0,-80]
        XCTAssertNil(HomeDocking.approachSpeedLimit(state:state,plot:.aurora,aircraft:.kestrel))
    }
    func testHomeLandingRejectsUnownedDistantAndBlockedApproachesAndInvalidTime() {
        var dock = HomeDocking(), housing = CityHousing(), state = FlightState()
        state.position = CityPlot.aurora.arrival
        XCTAssertFalse(dock.begin(.aurora,state:&state,aircraft:.kestrel,housing:housing))
        housing.build(.aurora); state.position = [0,400,0]
        XCTAssertFalse(dock.begin(.aurora,state:&state,aircraft:.kestrel,housing:housing))
        let body = CityPlot.aurora.parts.first { $0.material == 1 }!
        state.position = CityPlot.aurora.position+body.center
        XCTAssertFalse(dock.begin(.aurora,state:&state,aircraft:.kestrel,housing:housing))
        state.position = CityPlot.aurora.arrival
        XCTAssertTrue(dock.begin(.aurora,state:&state,aircraft:.kestrel,housing:housing))
        let old = state.position
        for dt:Float in [0,-1,.nan,.infinity,1] { XCTAssertFalse(dock.advance(state:&state,dt:dt)); XCTAssertEqual(state.position,old) }
        XCTAssertFalse(dock.depart(state:&state,aircraft:.kestrel,housing:housing))
        dock.reset(); XCTAssertNil(dock.plot); XCTAssertFalse(dock.landed)
    }
    func testFurniturePlacementRotationBoundariesDoorAndSaveCompatibility() throws {
        var wallet = FlightEconomy(); wallet.earn(lowFlightPoints:40000)
        XCTAssertTrue(wallet.buyHome(.aurora)); XCTAssertTrue(wallet.buyHome(.obsidian))
        for item in InteriorItem.allCases { XCTAssertTrue(wallet.buyInterior(item,in:.aurora)) }
        let balance = wallet.quarterCredits
        let moved = RoomPlacement(x:-3,z:2,turns:1)
        XCTAssertTrue(wallet.placeInterior(.lounge,in:.aurora,at:moved))
        XCTAssertEqual(wallet.housing!.layout(in:.aurora)[.lounge],moved)
        XCTAssertFalse(wallet.placeInterior(.lounge,in:.obsidian,at:moved))
        XCTAssertFalse(wallet.placeInterior(.holotable,in:.aurora,at:RoomPlacement(x:HomeRoomGeometry.entrance.x,z:HomeRoomGeometry.entrance.y)))
        XCTAssertFalse(wallet.placeInterior(.holotable,in:.aurora,at:RoomPlacement(x:50,z:0)))
        XCTAssertFalse(wallet.placeInterior(.holotable,in:.aurora,at:RoomPlacement(x:-3,z:2)))
        XCTAssertFalse(wallet.placeInterior(.holotable,in:.aurora,at:RoomPlacement(x:.nan,z:0)))
        XCTAssertFalse(wallet.placeInterior(.lights,in:.aurora,at:RoomPlacement(x:0,z:0)))
        XCTAssertEqual(wallet.quarterCredits,balance)
        let loaded = try JSONDecoder().decode(FlightEconomy.self,from:JSONEncoder().encode(wallet))
        XCTAssertEqual(loaded.housing,wallet.housing)
        var object = try JSONSerialization.jsonObject(with:JSONEncoder().encode(wallet)) as! [String:Any]
        var home = object["housing"] as! [String:Any]; home.removeValue(forKey:"layouts"); object["housing"] = home
        let old = try JSONDecoder().decode(FlightEconomy.self,from:JSONSerialization.data(withJSONObject:object))
        XCTAssertTrue(old.housing!.owned.contains(.aurora)); XCTAssertEqual(old.housing!.layout(in:.aurora)[.lounge],InteriorItem.lounge.defaultPlacement)
        wallet.resetInteriorLayout(in:.aurora)
        XCTAssertEqual(wallet.housing!.layout(in:.aurora)[.lounge],InteriorItem.lounge.defaultPlacement)
        XCTAssertEqual(wallet.quarterCredits,balance)
    }
    func testReinstallFindsClearSpaceAfterTheOldPositionIsOccupied() {
        var wallet = FlightEconomy(); wallet.earn(lowFlightPoints:20000)
        XCTAssertTrue(wallet.buyHome(.aurora)); XCTAssertTrue(wallet.buyInterior(.holotable,in:.aurora))
        XCTAssertTrue(wallet.buyInterior(.aquarium,in:.aurora))
        XCTAssertTrue(wallet.toggleInterior(.aquarium,in:.aurora))
        XCTAssertTrue(wallet.placeInterior(.holotable,in:.aurora,at:RoomPlacement(x:6,z:-3)))
        XCTAssertTrue(wallet.toggleInterior(.aquarium,in:.aurora))
        let housing = wallet.housing!, placement = housing.layout(in:.aurora)[.aquarium]!
        XCTAssertTrue(HomeRoomLayout.canPlace(.aquarium,at:placement,items:housing.items(in:.aurora),layout:housing.layout(in:.aurora)))
    }
    func testRoomWalkingFollowsMovedFurnitureAndCannotCrossWallsOrRunFasterDiagonally() {
        var walk = HomeRoomWalk(); walk.items = [.holotable]
        for _ in 0..<40 { walk.move([0,1],dt:0.1) }
        XCTAssertGreaterThan(walk.position.y,1.5)
        walk.layout = [.holotable:RoomPlacement(x:-3,z:-3)]
        for _ in 0..<40 { walk.move([0,1],dt:0.1) }
        XCTAssertLessThan(walk.position.y,0); XCTAssertGreaterThanOrEqual(walk.position.y,-HomeRoomGeometry.walkingLimit.y)
        let old = walk.position
        walk.move([.nan,0],dt:0.1); walk.move([1,0],dt:.infinity)
        XCTAssertEqual(walk.position,old)
        walk.look(dx:.nan,dy:2); XCTAssertEqual(walk.pitch,0)
        walk.look(dx:0,dy:-10000); XCTAssertEqual(walk.pitch,1.1)
        var direct = HomeRoomWalk(), diagonal = HomeRoomWalk()
        direct.move([0,1],dt:0.1); diagonal.move([1,1],dt:0.1)
        XCTAssertEqual(simd_distance(direct.position,HomeRoomGeometry.walkingStart),simd_distance(diagonal.position,HomeRoomGeometry.walkingStart),accuracy:0.001)
    }
    func testExpandedRoomAllowsFurnitureAndWalkingBeyondTheOldWalls() throws {
        var housing = CityHousing()
        for plot in CityPlot.allCases {
            housing.build(plot)
            XCTAssertTrue(housing.furnish(.holotable,in:plot))
            let placement = RoomPlacement(x:15,z:10,turns:1)
            XCTAssertTrue(housing.place(.holotable,in:plot,at:placement))
            var walk = HomeRoomWalk()
            walk.items = housing.items(in:plot); walk.layout = housing.layout(in:plot)
            XCTAssertFalse(walk.blocked(walk.position))
            XCTAssertFalse(walk.blocked([15,-10]))
            XCTAssertTrue(walk.blocked(placement.point))
            XCTAssertTrue(walk.blocked([HomeRoomGeometry.halfSize.x,0]))
            XCTAssertTrue(walk.blocked([0,HomeRoomGeometry.halfSize.y]))
            // Reach the new perimeter through empty space; no invisible wall remains at 10 × 8 m.
            walk.position = [0,-10]
            for _ in 0..<200 { walk.move([1,0],dt:0.1) }
            XCTAssertGreaterThan(walk.position.x,18)
            XCTAssertLessThanOrEqual(walk.position.x,HomeRoomGeometry.walkingLimit.x)
            walk.position = [0,0]
            for _ in 0..<200 { walk.move([0,1],dt:0.1) }
            XCTAssertLessThan(walk.position.y,-14)
            XCTAssertGreaterThanOrEqual(walk.position.y,-HomeRoomGeometry.walkingLimit.y)
            XCTAssertFalse(HomeRoomLayout.canPlace(.holotable,at:RoomPlacement(x:19,z:0),items:walk.items,layout:walk.layout))
        }
        let loaded = try JSONDecoder().decode(CityHousing.self,from:JSONEncoder().encode(housing))
        XCTAssertEqual(loaded,housing)
        let free = HomeRoomLayout.freePlacement(.holotable,preferred:RoomPlacement(x:100,z:0),items:[.holotable],layout:[:])
        XCTAssertNotNil(free); XCTAssertGreaterThan(free!.x,9)
    }
    func testExistingRoomLayoutAndFurnitureSizesStayUnchangedInLargerRoom() throws {
        var housing = CityHousing(); housing.build(.aurora)
        for item in InteriorItem.allCases { XCTAssertTrue(housing.furnish(item,in:.aurora)) }
        let saved = housing.layout(in:.aurora)
        let restored = try JSONDecoder().decode(CityHousing.self,from:JSONEncoder().encode(housing))
        XCTAssertEqual(restored.layout(in:.aurora),saved)
        for item in InteriorItem.allCases where item.movable {
            XCTAssertTrue(HomeRoomLayout.canPlace(item,at:saved[item]!,items:housing.items(in:.aurora),layout:saved))
        }
        XCTAssertEqual(InteriorItem.holotable.roomHalfSize,SIMD2<Float>(2,1.5))
        XCTAssertEqual(InteriorItem.lounge.defaultPlacement,RoomPlacement(x:-3,z:2.5))
        var walk = HomeRoomWalk(); walk.items = housing.items(in:.aurora); walk.layout = saved
        XCTAssertFalse(walk.blocked(HomeRoomGeometry.walkingStart))
    }
    @MainActor
    func testRoomSceneUsesSavedGroupPositionAndRotation() {
        let layout:[InteriorItem:RoomPlacement] = [.holotable:RoomPlacement(x:-3,z:-3,turns:1)]
        let scene = ResidencePreviewScene(plot:.aurora,interior:true,items:[.holotable],reduceMotion:true,layout:layout)
        let table = scene.scene.rootNode.childNode(withName:"Furniture holotable",recursively:false)!
        XCTAssertEqual(table.simdPosition,SIMD3<Float>(-3,0,-3))
        XCTAssertEqual(table.eulerAngles.y,Float.pi/2,accuracy:0.001)
        let floor = scene.scene.rootNode.childNode(withName:"Room floor",recursively:false)!.geometry as! SCNBox
        XCTAssertEqual(floor.width,40); XCTAssertEqual(floor.length,32)
        XCTAssertEqual(floor.width*floor.length,20*16*4)
        let window = scene.scene.rootNode.childNode(withName:"Panoramic window",recursively:false)!
        XCTAssertEqual(window.simdPosition.z,-HomeRoomGeometry.halfSize.y)
        let door = scene.scene.rootNode.childNode(withName:"Room entrance",recursively:false)!
        XCTAssertEqual(door.simdPosition.x,HomeRoomGeometry.entrance.x)
        XCTAssertEqual(door.simdPosition.z,HomeRoomGeometry.halfSize.y)
        XCTAssertNil(scene.scene.rootNode.childNode(withName:"Room ceiling",recursively:false))
        let inside = ResidencePreviewScene(plot:.aurora,interior:true,items:[.holotable],reduceMotion:true,layout:layout,walkthrough:true)
        let roof = inside.scene.rootNode.childNode(withName:"Room ceiling",recursively:false)!
        XCTAssertGreaterThan(roof.simdPosition.y,HomeRoomGeometry.height)
        XCTAssertEqual((roof.geometry as! SCNBox).width,CGFloat(HomeRoomGeometry.width))
        XCTAssertEqual(inside.scene.rootNode.childNode(withName:"Furniture holotable",recursively:false)!.simdPosition,table.simdPosition)
    }

    func testFourPlotsAreClearedInVisibleAndPhysicalCityAndArrivalsAreSafe() {
        let city = PlanetExploration(planet:.coruscant)
        XCTAssertEqual(CityPlot.allCases.count,4)
        for plot in CityPlot.allCases {
            for x:Float in stride(from:-650,through:650,by:130) {
                for z:Float in stride(from:-650,through:650,by:130) {
                    XCTAssertFalse(city.hitsObstacle(at:plot.position+[x,60,z],radius:10),plot.name)
                }
            }
            XCTAssertFalse(city.hitsObstacle(at:plot.arrival,radius:30))
            for ship in AircraftType.allCases { XCTAssertGreaterThan(city.clearance(at:plot.arrival),ship.bodyRadius) }
        }
    }
    func testHomeAndFurnitureSpendExactlyOnceAndPersist() throws {
        let suite = "housing-"+UUID().uuidString
        let defaults = UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        var wallet = FlightEconomy(); wallet.earn(lowFlightPoints:20000)
        XCTAssertFalse(wallet.buyInterior(.aquarium,in:.aurora))
        XCTAssertTrue(wallet.buyHome(.aurora))
        XCTAssertEqual(wallet.quarterCredits,20000-CityPlot.aurora.price*4)
        XCTAssertFalse(wallet.buyHome(.aurora))
        XCTAssertTrue(wallet.buyInterior(.aquarium,in:.aurora))
        let spent = wallet.quarterCredits
        XCTAssertFalse(wallet.buyInterior(.aquarium,in:.aurora))
        XCTAssertFalse(wallet.buyHome(.senate))
        wallet.toggleInterior(.aquarium,in:.aurora)
        XCTAssertFalse(wallet.housing!.items(in:.aurora).contains(.aquarium))
        XCTAssertTrue(wallet.housing!.owns(.aquarium,in:.aurora))
        wallet.toggleInterior(.aquarium,in:.aurora)
        XCTAssertEqual(wallet.quarterCredits,spent)
        wallet.save(to:defaults)
        let loaded = FlightEconomy.load(from:defaults)
        XCTAssertEqual(loaded,wallet)
        XCTAssertTrue(loaded.housing!.items(in:.aurora).contains(.aquarium))
        XCTAssertFalse(loaded.housing!.owns(.aquarium,in:.obsidian))
        let legacy = try JSONSerialization.jsonObject(with:JSONEncoder().encode(wallet)) as! [String:Any]
        var old = legacy; old.removeValue(forKey:"housing"); old.removeValue(forKey:"factions")
        let restored = try JSONDecoder().decode(FlightEconomy.self,from:JSONSerialization.data(withJSONObject:old))
        XCTAssertEqual(restored.quarterCredits,wallet.quarterCredits)
        XCTAssertNil(restored.housing)
    }
    func testResidenceCollisionExistsOnlyAfterBuildingAndSweepsThinRoofs() {
        for plot in CityPlot.allCases {
            var housing = CityHousing()
            let body = plot.parts.first { $0.material == 1 }!
            let point = plot.position+body.center
            XCTAssertFalse(housing.hits(point,radius:1))
            housing.build(plot)
            XCTAssertTrue(housing.hits(point,radius:1))
            XCTAssertFalse(housing.hits(plot.arrival,radius:30))
            let from = point+SIMD3<Float>(0,body.size.y+20,0)
            let to = point-SIMD3<Float>(0,body.size.y+20,0)
            XCTAssertTrue(housing.impact(from:from,to:to,radius:1))
        }
    }
    func testFactionContractsCompleteAndOnlyCreditTheirOwnStandingOnce() {
        for contract in CityContract.allCases.filter({$0.faction != nil}) {
            var jobs = CoruscantJobs(); jobs.accept(contract)
            var report:CityJobReport?
            for station in contract.stops {
                XCTAssertTrue(jobs.beginService(at:station.position))
                _ = jobs.advance(dt:jobs.serviceDuration)
                report = jobs.lastCompletion
            }
            XCTAssertNotNil(report)
            var wallet = FlightEconomy()
            XCTAssertTrue(wallet.claimCityJob(id:report!.id,credits:report!.credits,report:report))
            XCTAssertFalse(wallet.claimCityJob(id:report!.id,credits:report!.credits,report:report))
            for faction in CityFaction.allCases { XCTAssertEqual(wallet.factions?.points(faction) ?? 0,faction == contract.faction ? 10:0) }
        }
    }
    func testBountyFastShotsDisableTargetsThenRewardIsIdempotent() {
        for contract in BountyContract.allCases {
            var hunt = CityBountyHunt(), ship = FlightState()
            ship.position = [0,1000,7200]
            hunt.start(contract,near:ship)
            XCTAssertEqual(hunt.remaining,contract.count)
            let receipt = hunt.receipt!
            for _ in 0..<contract.count {
                let target = hunt.targets.first!.position
                let bolt = PlayerBolt(position:target+[0,0,-30],velocity:[0,0,-7200],age:1/120,damage:1000)
                let result = hunt.advance(ship:ship,playerBolts:[bolt],dt:1/120)
                XCTAssertTrue(result.consumed.contains(0))
            }
            XCTAssertEqual(hunt.remaining,0)
            var wallet = FlightEconomy()
            XCTAssertTrue(wallet.claimBounty(receipt,contract:contract))
            XCTAssertFalse(wallet.claimBounty(receipt,contract:contract))
            XCTAssertEqual(wallet.quarterCredits,contract.reward*4)
            XCTAssertEqual(wallet.factions!.points(.hunters),10)
            XCTAssertEqual(wallet.completedCityJobs,0)
            hunt.reset(); XCTAssertNil(hunt.contract); XCTAssertTrue(hunt.targets.isEmpty)
        }
    }
    func testBountyTargetsStayAboveCityAndFireSlowLowDamageBolts() {
        var hunt = CityBountyHunt(), ship = FlightState(); ship.position = [0,1000,7200]
        hunt.start(.runaway,near:ship)
        for _ in 0..<1200 {
            let result = hunt.advance(ship:ship,playerBolts:[],dt:1/120)
            XCTAssertLessThanOrEqual(result.damage,3)
            for target in hunt.targets { XCTAssertGreaterThan(target.position.y,970) }
            for bolt in hunt.bolts { XCTAssertEqual(simd_length(bolt.velocity),110,accuracy:0.01) }
        }
        XCTAssertLessThanOrEqual(hunt.bolts.count,2)
    }
    func testCometsOnlyLiveOnPlanetsResetAndHaveBoundedCount() {
        var field = PlanetCometField(), ship = FlightState(); ship.position = [0,700,0]; ship.velocity = [0,0,-80]
        _ = field.advance(planet:nil,from:ship,to:ship,radius:2,dt:1/120)
        XCTAssertTrue(field.comets.isEmpty)
        var warned = false
        for _ in 0..<120*75 {
            let previous = ship; ship.position += ship.velocity/120
            let damage = field.advance(planet:.hoth,from:previous,to:ship,radius:2,dt:1/120)
            XCTAssertLessThanOrEqual(damage,12)
            XCTAssertLessThanOrEqual(field.comets.count,3)
            warned = warned || field.warning != nil
        }
        XCTAssertTrue(warned)
        _ = field.advance(planet:nil,from:ship,to:ship,radius:2,dt:1/120)
        XCTAssertTrue(field.comets.isEmpty); XCTAssertNil(field.warning)
        _ = field.advance(planet:.endor,from:ship,to:ship,radius:2,dt:1/120)
        XCTAssertEqual(field.comets.count,1); XCTAssertFalse(field.comets[0].hazardous)
    }
    func testCometCrossingCanDamageMovingShipOnceWithoutInstantDeath() {
        var field = PlanetCometField(), ship = FlightState()
        ship.position = [0,800,0]; ship.velocity = [0,0,-80]; ship.airspeed = 80
        var total:Float = 0
        for _ in 0..<120*80 {
            let previous = ship; ship.position += ship.velocity/120
            total += field.advance(planet:.coruscant,from:previous,to:ship,radius:3,dt:1/120)
        }
        XCTAssertEqual(total,12)
    }
    @MainActor
    func testResidencePoolOnlyShowsOwnedArchitecture() {
        let renderer = CityResidenceRenderer()
        var housing = CityHousing()
        XCTAssertFalse(renderer.root.children.first { $0.name == CityPlot.aurora.name }!.isEnabled)
        housing.build(.aurora); renderer.update(housing)
        XCTAssertTrue(renderer.root.children.first { $0.name == CityPlot.aurora.name }!.isEnabled)
        XCTAssertFalse(renderer.root.children.first { $0.name == CityPlot.senate.name }!.isEnabled)
        let ids = renderer.root.children.map(\.id)
        renderer.update(housing); XCTAssertEqual(renderer.root.children.map(\.id),ids)
    }
}
