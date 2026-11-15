import XCTest

final class FlightUITests: XCTestCase {
    @MainActor
    func testAvatarProfilePurchaseAndRoomFlightEntry() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-introStyle", "canva"]
        app.launchEnvironment["STARFLIGHT_ECONOMY_FIXTURE"] = "funded"
        app.launch(); settleStoryLaunch(app)
        tapHomeAction("Shop", in: app); app.buttons["Shop avatar outfitter"].tap()
        if !app.navigationBars["Pilot profile"].waitForExistence(timeout: 5), app.buttons["Shop avatar outfitter"].isHittable { app.buttons["Shop avatar outfitter"].tap() }
        XCTAssertTrue(app.navigationBars["Pilot profile"].waitForExistence(timeout: 10))
        capture(app, name: "Larger circular pilot portrait with fitted accessories")
        let buy = app.buttons["Avatar accessory flightGoggles"]
        revealStoryControl(buy, in: app); XCTAssertTrue(buy.isHittable); buy.tap()
        XCTAssertTrue(app.staticTexts["Avatar purchase result"].label.contains("Bought"))
        capture(app, name: "Avatar outfitter with purchased flight goggles")
        app.terminate(); app.launchEnvironment.removeValue(forKey: "STARFLIGHT_ECONOMY_FIXTURE")
        app.launch(); settleStoryLaunch(app); tapHomeAction("Shop", in: app); app.buttons["Shop avatar outfitter"].tap()
        if !app.navigationBars["Pilot profile"].waitForExistence(timeout: 5), app.buttons["Shop avatar outfitter"].isHittable { app.buttons["Shop avatar outfitter"].tap() }
        XCTAssertTrue(app.navigationBars["Pilot profile"].waitForExistence(timeout: 10))
        revealStoryControl(app.buttons["Avatar accessory flightGoggles"], in: app)
        XCTAssertEqual(app.buttons["Avatar accessory flightGoggles"].label, "Equipped")
        app.terminate(); app.launch(); settleStoryLaunch(app); tapHomeAction("My creations", in: app)
        let room = app.buttons["Open room flight"]; XCTAssertTrue(room.waitForExistence(timeout: 10)); room.tap()
        XCTAssertTrue(app.staticTexts["AR room tracking is unavailable on this device."].waitForExistence(timeout: 10))
        capture(app, name: "Room flight unsupported-device explanation and safe exit")
        app.buttons["Close room flight"].tap()
    }

    @MainActor
    func testDetailedBadgeTurnsHorizontally() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(); app.launchArguments = ["-introStyle","canva"]
        app.launch(); settleStoryLaunch(app)
        let logbook = app.buttons["Pilot logbook"]
        revealStoryControl(logbook,in:app); logbook.tap()
        let badge = app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","Inspect badge ")).firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout:10)); revealStoryControl(badge,in:app); badge.tap()
        let medal = app.otherElements["Rotating achievement badge"]
        XCTAssertTrue(medal.waitForExistence(timeout:10))
        medal.swipeLeft(); medal.swipeRight()
        capture(app,name:"Detailed medal with horizontal full rotation")
        app.buttons["Done"].tap()
    }

    @MainActor
    func testAetherReachEntryFlightAndReturnWithBaseline() {
        for enhanced in [false,true] {
            let app = XCUIApplication()
            startUniverseFlight(app,extraArguments:["-aetherPlanetEnabled","YES","-aetherSurfaceEnabled",enhanced ? "YES":"NO"])
            app.buttons["Hyperspace"].tap()
            let enter = app.buttons["Explore Aether Reach"]
            revealStoryControl(enter,in:app)
            expectation(for:NSPredicate(format:"isEnabled == true"),evaluatedWith:enter)
            waitForExpectations(timeout:60)
            capture(app,name:"Aether Reach exploration entry")
            enter.tap(); waitForUniverseArrival(app)
            XCTAssertTrue(app.buttons["Return solar orbit"].waitForExistence(timeout:10))
            Thread.sleep(forTimeInterval:2)
            capture(app,name:enhanced ? "Aether Reach enhanced surface":"Aether Reach baseline same geometry")
            let throttle = app.sliders["Throttle"]
            throttle.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).press(forDuration:0.1,
                thenDragTo:throttle.coordinate(withNormalizedOffset:CGVector(dx:0.64,dy:0.5)))
            Thread.sleep(forTimeInterval:8)
            XCTAssertTrue(app.buttons["Pause flight"].exists)
            capture(app,name:enhanced ? "Aether Reach moving flight":"Aether Reach baseline flight")
            app.buttons["Return solar orbit"].tap(); waitForUniverseArrival(app)
            XCTAssertTrue(app.buttons["Enter selected solar planet"].waitForExistence(timeout:10))
            app.terminate()
        }
    }

    @MainActor
    func testHothAetherTerrainPilotComparison() {
        for enhanced in [false,true] {
            let app = XCUIApplication()
            startUniverseFlight(app,extraArguments:["-aetherHothTerrainEnabled",enhanced ? "YES":"NO"])
            app.buttons["Flight tools"].tap()
            let entry = app.buttons["Enter Hoth"]; revealStoryControl(entry,in:app); entry.tap()
            XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout:15))
            Thread.sleep(forTimeInterval:2)
            capture(app,name:enhanced ? "Hoth Aether terrain enhanced":"Hoth legacy terrain baseline")
            let throttle = app.sliders["Throttle"]
            throttle.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).press(forDuration:0.1,
                thenDragTo:throttle.coordinate(withNormalizedOffset:CGVector(dx:0.64,dy:0.5)))
            Thread.sleep(forTimeInterval:8)
            XCTAssertTrue(app.buttons["Pause flight"].exists)
            capture(app,name:enhanced ? "Hoth Aether moving flight":"Hoth legacy moving flight")
            app.buttons["Flight tools"].tap()
            let orbit = app.buttons["Return to orbit"]; revealStoryControl(orbit,in:app); orbit.tap()
            XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout:10))
            app.terminate()
        }
    }

    @MainActor
    func testSelectiveAetherWorldFlights() {
        for pilot in [false,true] {
            let app=XCUIApplication()
            startUniverseFlight(app,extraArguments:["-aetherTatooineTerrainEnabled",pilot ? "YES":"NO","-aetherEndorTerrainEnabled",pilot ? "YES":"NO"])
            for name in ["Tatooine","Endor"] {
                app.buttons["Flight tools"].tap()
                let enter=app.buttons["Enter "+name];revealStoryControl(enter,in:app);enter.tap()
                XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout:15))
                Thread.sleep(forTimeInterval:2)
                capture(app,name:name+(pilot ? " Aether terrain":" legacy terrain"))
                let throttle=app.sliders["Throttle"]
                throttle.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).press(forDuration:0.1,thenDragTo:throttle.coordinate(withNormalizedOffset:CGVector(dx:0.62,dy:0.5)))
                Thread.sleep(forTimeInterval:6)
                XCTAssertTrue(app.buttons["Pause flight"].exists)
                capture(app,name:name+(pilot ? " Aether flight":" legacy flight"))
                app.buttons["Flight tools"].tap()
                let orbit=app.buttons["Return to orbit"];revealStoryControl(orbit,in:app);orbit.tap()
            }
            app.terminate()
        }
    }

    /// Exercises normal travel and captures the nine scenery destinations accepted for this update.
    @MainActor
    func testScenicExpeditionTravelAndCaptures() { captureScenicExpeditions(includeHomePlanets: true) }

    @MainActor
    func testSolarExpeditionVisualFollowUp() { captureScenicExpeditions(includeHomePlanets: false) }

    @MainActor
    func testEndorFoliageVisualFollowUp() { captureScenicExpeditions(includeHomePlanets: true, onlyEndor: true) }

    @MainActor
    func testJupiterCloudVisualFollowUp() { captureScenicExpeditions(includeHomePlanets: false, onlySolar: "Jupiter") }

    @MainActor
    private func captureScenicExpeditions(includeHomePlanets: Bool, onlyEndor: Bool = false, onlySolar: String? = nil) {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        startUniverseFlight(app)
        func film(_ name: String) {
            XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout: 15), name)
            let throttle = app.sliders["Throttle"]
            XCTAssertTrue(throttle.isHittable)
            // Exercise the actual thumb drag, including the neutral detent. The
            // recording must show flight rather than nine stationary arrivals.
            throttle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: throttle.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5)))
            print("SCENIC_THROTTLE \(name) \(String(describing: throttle.value))")
            Thread.sleep(forTimeInterval: 3)
            let speed = app.descendants(matching: .any).matching(identifier: "Airspeed").firstMatch
            XCTAssertTrue(speed.exists)
            XCTAssertNotEqual(speed.value as? String, "0 kt", "Capture must exercise moving flight: " + name)
            print("SCENIC_VIDEO_START \(name) \(Date().timeIntervalSince1970)")
            capture(app, name: "Expedition " + name)
            Thread.sleep(forTimeInterval: 10)
            XCTAssertTrue(app.buttons["Pause flight"].exists, "Scenic arrival must remain safe: " + name)
            capture(app, name: "Expedition " + name + " in flight")
            print("SCENIC_VIDEO_END \(name) \(Date().timeIntervalSince1970)")
            if app.buttons["Neutral throttle"].exists { app.buttons["Neutral throttle"].tap() }
        }
        for name in onlyEndor ? ["Endor"] : includeHomePlanets ? ["Coruscant", "Tatooine", "Hoth", "Endor"] : [] {
            app.buttons["Flight tools"].tap()
            let entry = app.buttons["Enter " + name]
            revealStoryControl(entry, in: app); entry.tap()
            film(name)
            app.buttons["Flight tools"].tap()
            let orbit = app.buttons["Return to orbit"]
            revealStoryControl(orbit, in: app); orbit.tap()
        }
        if onlyEndor { app.buttons["Pause flight"].tap(); return }
        app.buttons["Hyperspace"].tap()
        app.segmentedControls["Universe sections"].buttons["Solar System"].tap()
        let travel = app.buttons["Engage Solar System jump"]
        revealStoryControl(travel, in: app); travel.tap(); waitForUniverseArrival(app)
        for name in onlySolar.map({ [$0] }) ?? ["Mercury", "Venus", "Earth", "Mars", "Jupiter"] {
            app.buttons["Hyperspace"].tap()
            app.segmentedControls["Universe sections"].buttons["Solar System"].tap()
            let entry = app.buttons["Enter solar " + name]
            revealStoryControl(entry, in: app); entry.tap(); waitForUniverseArrival(app)
            XCTAssertTrue(app.buttons["Return solar orbit"].waitForExistence(timeout: 10), name)
            film(name)
            app.buttons["Return solar orbit"].tap(); waitForUniverseArrival(app)
        }
        app.buttons["Pause flight"].tap()
    }

    @MainActor
    func testSolarSurfaceEntryAndOrbitReturn() {
        let app = XCUIApplication(); startUniverseFlight(app)
        app.buttons["Hyperspace"].tap(); app.segmentedControls["Universe sections"].buttons["Solar System"].tap()
        let jump = app.buttons["Engage Solar System jump"]; revealStoryControl(jump,in:app); jump.tap(); waitForUniverseArrival(app)
        XCTAssertTrue(app.buttons["Enter selected solar planet"].waitForExistence(timeout:10))
        capture(app,name:"Solar System entry control and detailed planets")
        app.buttons["Enter selected solar planet"].tap(); waitForUniverseArrival(app)
        XCTAssertTrue(app.buttons["Return solar orbit"].waitForExistence(timeout:10))
        capture(app,name:"Earth surface expedition with land sea and mountains")
        app.buttons["Return solar orbit"].tap(); waitForUniverseArrival(app)
        XCTAssertTrue(app.buttons["Enter selected solar planet"].waitForExistence(timeout:10))
        app.buttons["Pause flight"].tap()
    }

    @MainActor
    func testHangarSceneryPreferenceCanBeChanged() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication(); app.launchArguments = ["-introStyle","canva","-hangarPreview","hangar"]
        app.launch(); settleStoryLaunch(app)
        tapHomeAction("Settings", in: app); app.buttons["Settings quick jump"].tap(); app.buttons["Hangar preview"].tap()
        let picker = app.buttons["Hangar scenery style"]
        XCTAssertTrue(picker.waitForExistence(timeout:10)); picker.tap()
        app.buttons["Selected level"].tap()
        capture(app,name:"Settings choice between hangar showroom and selected level")
        app.buttons["Done"].tap()
        capture(app,name:"Selected level menu preview")
        tapHomeAction("Settings", in: app); app.buttons["Settings quick jump"].tap(); app.buttons["Hangar preview"].tap()
        picker.tap(); app.buttons["Hangar showroom"].tap(); app.buttons["Done"].tap()
        XCTAssertTrue(app.otherElements["Hangar preview"].waitForExistence(timeout:10))
    }

    @MainActor
    func testSettingsAlphabeticalQuickJump() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-introStyle", "canva"]
        app.launch(); settleStoryLaunch(app)
        tapHomeAction("Settings", in: app)
        let jump = app.buttons["Settings quick jump"]
        XCTAssertTrue(jump.waitForExistence(timeout: 10)); jump.tap()
        app.buttons["Flight controls"].tap()
        let sound = app.switches["Device tilt"]
        XCTAssertTrue(sound.waitForExistence(timeout: 5)); XCTAssertTrue(sound.isHittable)
        jump.tap(); app.buttons["About Starflight"].tap()
        let version = app.descendants(matching: .any)["App version"].firstMatch
        XCTAssertTrue(version.waitForExistence(timeout: 5)); XCTAssertTrue(version.isHittable)
        capture(app, name: "Alphabetical settings with quick jump and solid panel")
        app.buttons["Done"].tap()
    }

    @MainActor
    func testBannerEditorLongPressHidesAndRestoresReadout() {
        let app = XCUIApplication(); startUniverseFlight(app)
        app.descendants(matching: .any)["Height above ground"].firstMatch.press(forDuration: 0.8)
        let toggle = app.switches["Airspeed"]
        if !toggle.waitForExistence(timeout: 3), app.buttons["Edit instruments"].exists { app.buttons["Edit instruments"].tap() }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        print("BANNER TOGGLE BEFORE", String(describing: toggle.value))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap(); print("BANNER TOGGLE AFTER", String(describing: toggle.value)); app.buttons["Done"].tap()
        capture(app,name:"Banner after edit")
        XCTAssertTrue(app.buttons["Hyperspace"].waitForExistence(timeout: 5))
        let speed = app.descendants(matching: .any)["Airspeed"].firstMatch
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: speed); waitForExpectations(timeout: 5)
        app.descendants(matching: .any)["Height above ground"].firstMatch.press(forDuration: 0.8)
        if !app.switches["Airspeed"].waitForExistence(timeout: 3), app.buttons["Edit instruments"].exists { app.buttons["Edit instruments"].tap() }
        XCTAssertTrue(app.switches["Airspeed"].waitForExistence(timeout: 5))
        app.switches["Airspeed"].coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap(); app.buttons["Done"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["Airspeed"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Pause flight"].tap()
    }

    @MainActor
    func testFlightControlsStayOnScreenAndHyperspaceHasLargeLabelledTarget() {
        let app = XCUIApplication(); startUniverseFlight(app)
        func checkControls(_ stage: String) {
            let bounds = app.frame.insetBy(dx: 6, dy: 6)
            for id in ["Flight joystick", "Throttle", "Fire weapons", "Switch camera", "Pause flight", "Hyperspace"] {
                let control = app.descendants(matching: .any).matching(identifier: id).firstMatch
                XCTAssertTrue(control.waitForExistence(timeout: 10), "Missing \(id) during \(stage)")
                XCTAssertTrue(control.isHittable, "Hidden \(id) during \(stage)")
                XCTAssertTrue(bounds.contains(control.frame), "Clipped \(id) during \(stage): \(control.frame), screen \(bounds)")
            }
            let jump = app.buttons["Hyperspace"]
            XCTAssertGreaterThanOrEqual(jump.frame.height, 44)
            XCTAssertGreaterThanOrEqual(jump.frame.width, 120)
        }
        for orientation: UIDeviceOrientation in [.landscapeLeft, .landscapeRight] {
            XCUIDevice.shared.orientation = orientation
            checkControls("orientation \(orientation.rawValue)")
            capture(app, name: "Fully visible flight controls and labelled hyperspace \(orientation.rawValue)")
        }
        app.buttons["Switch camera"].tap()
        checkControls("cockpit")
        capture(app, name: "Cockpit controls anchored above safe area")
        app.buttons["Hyperspace"].coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["Close universe map"].waitForExistence(timeout: 10))
        app.buttons["Close universe map"].tap()
        checkControls("return from hyperspace menu")
        app.buttons["Fire weapons"].tap()
        XCTAssertEqual(app.buttons["Fire weapons"].value as? String, "Firing")
        app.buttons["Fire weapons"].tap()
        app.sliders["Throttle"].adjust(toNormalizedSliderPosition: 0)
        app.buttons["Neutral throttle"].tap()
        XCTAssertEqual(Float(app.sliders["Throttle"].value as? String ?? "nan"), 0)
        app.buttons["Pause flight"].tap()
    }

    @MainActor
    private func assertCoreControlsInsideScreen(_ app: XCUIApplication) {
        let bounds = app.frame.insetBy(dx: 6, dy: 6)
        for id in ["Flight joystick", "Throttle", "Fire weapons", "Switch camera", "Pause flight"] {
            let control = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(control.isHittable, "Hidden control: \(id)")
            XCTAssertTrue(bounds.contains(control.frame), "Clipped control: \(id), \(control.frame)")
        }
    }

    @MainActor
    func testGalaxyChartRendersAndOrbits() {
        let app = XCUIApplication(); startUniverseFlight(app); app.buttons["Hyperspace"].tap()
        let chart = app.otherElements["3D galaxy map"]
        XCTAssertTrue(chart.waitForExistence(timeout:10)); chart.swipeLeft()
        capture(app,name:"Rendered galaxy chart with spiral markers after orbit gesture")
        app.buttons["Close universe map"].tap(); app.buttons["Pause flight"].tap()
    }
    @MainActor
    private func startUniverseFlight(_ app:XCUIApplication, extraArguments:[String] = []) {
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launchArguments = ["-aircraft","xwing","-level","freeRoam","-spaceFreeRoam","YES","-introStyle","canva","-flightWeather","clear","-performanceMode","NO","-tiltEnabled","NO","-handControlEnabled","NO"] + extraArguments
        app.launchEnvironment["STARFLIGHT_ECONOMY_FIXTURE"] = "funded"; app.launch(); settleStoryLaunch(app)
        let start = app.buttons["Take flight"]
        expectation(for:NSPredicate(format:"isEnabled == true"),evaluatedWith:start); waitForExpectations(timeout:120); start.tap()
        XCTAssertTrue(app.buttons["Hyperspace"].waitForExistence(timeout:15))
    }
    @MainActor
    private func waitForUniverseArrival(_ app:XCUIApplication) {
        let jump = app.descendants(matching:.any)["Galaxy jump status"].firstMatch
        XCTAssertTrue(jump.waitForExistence(timeout:8))
        capture(app,name:"Five second hyperspace streak tunnel")
        expectation(for:NSPredicate(format:"exists == false"),evaluatedWith:jump); waitForExpectations(timeout:20)
        XCTAssertTrue(app.buttons["Hyperspace"].waitForExistence(timeout:10))
    }
    @MainActor
    func testGalaxyMapTravelCancelAndReturnHome() {
        let app = XCUIApplication(); startUniverseFlight(app); app.buttons["Hyperspace"].tap()
        XCTAssertTrue(app.otherElements["3D galaxy map"].waitForExistence(timeout:10))
        app.otherElements["3D galaxy map"].swipeLeft()
        capture(app,name:"Starflight 2.0 three dimensional Local Group galaxy map")
        let galaxy = app.buttons["Galaxy andromeda"]; revealStoryControl(galaxy,in:app); galaxy.tap()
        let engage = app.buttons["Engage galaxy jump"]; revealStoryControl(engage,in:app); engage.tap()
        waitForUniverseArrival(app)
        app.buttons["Hyperspace"].tap(); XCTAssertTrue(app.staticTexts["Current galaxy"].label.contains("Andromeda"))
        capture(app,name:"Arrived in Andromeda galaxy with the Milky Way return route")
        let home = app.buttons["Galaxy milkyWay"]; revealStoryControl(home,in:app); home.tap()
        revealStoryControl(app.buttons["Engage galaxy jump"],in:app); app.buttons["Engage galaxy jump"].tap()
        waitForUniverseArrival(app)
        app.buttons["Hyperspace"].tap(); XCTAssertTrue(app.staticTexts["Current galaxy"].label.contains("Milky Way"))
        let destination = app.buttons["Galaxy triangulum"]; revealStoryControl(destination,in:app); destination.tap()
        revealStoryControl(app.buttons["Engage galaxy jump"],in:app); app.buttons["Engage galaxy jump"].tap()
        XCTAssertTrue(app.buttons["Cancel galaxy jump"].waitForExistence(timeout:8)); app.buttons["Cancel galaxy jump"].firstMatch.tap()
        app.buttons["Hyperspace"].tap(); XCTAssertTrue(app.staticTexts["Current galaxy"].label.contains("Milky Way"))
        app.buttons["Close universe map"].tap(); app.buttons["Pause flight"].tap()
    }
    @MainActor
    func testRealStarSearchJumpAndSolarSystemFlyby() {
        let app = XCUIApplication(); startUniverseFlight(app); app.buttons["Hyperspace"].tap()
        app.segmentedControls["Universe sections"].buttons["Astronomy"].tap()
        XCTAssertTrue(app.staticTexts["Star catalogue count"].label.contains("3,000"))
        let search = app.textFields["Star catalogue search"]; revealStoryControl(search,in:app); search.tap(); search.typeText("Sirius")
        app.keyboards.buttons["Search"].tap()
        let star = app.buttons["Star 32349"]; revealStoryControl(star,in:app); star.tap()
        let jump = app.buttons["Engage star jump"]; revealStoryControl(jump,in:app)
        capture(app,name:"Sirius catalogue position distance and hyperspace destination")
        jump.tap(); waitForUniverseArrival(app)
        XCTAssertTrue(app.staticTexts["Astronomy flight readout"].waitForExistence(timeout:10))
        XCTAssertTrue(app.staticTexts["Astronomy flight readout"].label.contains("Sirius"))
        capture(app,name:"Near Sirius with the shifted real star sky")
        app.buttons["Open star facts"].tap()
        XCTAssertTrue(app.buttons["Close star facts"].waitForExistence(timeout:5))
        capture(app,name:"Paused star fact callout pointing to Sirius")
        app.buttons["Close star facts"].tap()
        XCTAssertTrue(app.buttons["Hyperspace"].waitForExistence(timeout:5))
        app.buttons["Hyperspace"].tap(); app.segmentedControls["Universe sections"].buttons["Solar System"].tap()
        let solar = app.buttons["Engage Solar System jump"]; revealStoryControl(solar,in:app); solar.tap(); waitForUniverseArrival(app)
        capture(app,name:"Solar System flyby scene with the Sun and planets")
        app.buttons["Hyperspace"].tap(); app.segmentedControls["Universe sections"].buttons["Solar System"].tap()
        let earth = app.buttons["Solar body Earth"]; revealStoryControl(earth,in:app); earth.tap()
        app.buttons["Close universe map"].tap(); app.buttons["Pause flight"].tap()
    }
    @MainActor
    func testReverseNeutralAndBlackHoleHorizonCrash() {
        let app = XCUIApplication(); startUniverseFlight(app)
        let throttle = app.sliders["Throttle"]; throttle.adjust(toNormalizedSliderPosition:0)
        XCTAssertEqual(Float(throttle.value as? String ?? "nan"),-1)
        capture(app,name:"Negative one hundred percent reverse throttle in space")
        app.buttons["Neutral throttle"].tap(); XCTAssertEqual(Float(throttle.value as? String ?? "nan"),0)
        app.buttons["Hyperspace"].tap()
        let approach = app.buttons["Visit black hole"]; revealStoryControl(approach,in:app); approach.tap(); waitForUniverseArrival(app)
        capture(app,name:"Black hole approach with accretion disc and photon ring")
        app.sliders["Throttle"].adjust(toNormalizedSliderPosition:1)
        let crash = app.staticTexts["Beyond the event horizon."]
        XCTAssertTrue(crash.waitForExistence(timeout:110))
        capture(app,name:"Event horizon crash with black hole specific recovery advice")
        app.buttons["Back to base"].tap()
    }

    @MainActor
    func testSettingsSoundPreviewReportsPlaybackAndOutput() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft","kestrel","-level","freeRoam","-introStyle","canva","-sound","YES","-soundVolume","0.8"]
        app.launch(); settleStoryLaunch(app); tapHomeAction("Settings", in: app)
        let test = app.buttons["Test game sound"]
        for _ in 0..<12 {
            if test.isHittable { break }
            app.coordinate(withNormalizedOffset:CGVector(dx:0.55,dy:0.75)).press(forDuration:0.05,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.55,dy:0.30)))
        }
        XCTAssertTrue(test.isHittable); test.tap()
        let status = app.staticTexts["Game sound test status"]
        XCTAssertTrue(status.waitForExistence(timeout:5)); XCTAssertTrue(status.label.hasPrefix("Test sound playing"),status.label)
        capture(app,name:"Settings sound preview and selected device audio output")
    }

    @MainActor
    func testCompletedStoryCanCancelThenReplayAndLaunchWithNewPlan() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft","kestrel","-level","freeRoam","-introStyle","canva"]
        app.launchEnvironment["STARFLIGHT_ECONOMY_FIXTURE"] = "funded"
        app.launchEnvironment["STARFLIGHT_STORY_FIXTURE"] = "ending"; app.launch(); settleStoryLaunch(app)
        tapHomeAction("Story campaign", in: app)
        let replay = app.buttons["Replay story"]
        revealStoryControl(replay,in:app); replay.tap()
        XCTAssertTrue(app.buttons["Keep current story"].waitForExistence(timeout:5)); app.buttons["Keep current story"].tap()
        XCTAssertTrue(app.staticTexts["Story campaign progress"].label.contains("7 / 7"))
        replay.tap(); app.alerts.buttons["Confirm story replay"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Story campaign progress"].label.contains("0 / 7"))
        XCTAssertEqual(app.staticTexts["Story chapter title"].label,"A Voice in the Traffic")
        let covert = app.buttons["Story approach covert"]; revealStoryControl(covert,in:app); covert.tap()
        XCTAssertEqual(covert.value as? String,"Selected")
        capture(app,name:"Replayed story with a fresh opening plan")
        app.terminate(); app.launchEnvironment.removeValue(forKey:"STARFLIGHT_STORY_FIXTURE"); app.launchEnvironment.removeValue(forKey:"STARFLIGHT_ECONOMY_FIXTURE")
        app.launch(); settleStoryLaunch(app); tapHomeAction("Story campaign", in: app)
        XCTAssertTrue(app.staticTexts["Story campaign progress"].label.contains("0 / 7"))
        revealStoryControl(app.buttons["Story approach covert"],in:app)
        XCTAssertEqual(app.buttons["Story approach covert"].value as? String,"Selected")
        app.buttons["Launch story chapter"].tap()
        let objective = app.descendants(matching:.any)["Story flight objective"].firstMatch
        XCTAssertTrue(objective.waitForExistence(timeout:120)); XCTAssertTrue(objective.label.contains("Spaceport Connection"))
        app.buttons["Pause flight"].tap()
    }

    @MainActor
    private func tapHomeAction(_ identifier: String, in app: XCUIApplication) {
        revealHomeAction(identifier, in: app).tap()
    }
    @MainActor @discardableResult
    private func revealHomeAction(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let slider = app.scrollViews["Home action segments"]
        let target = app.buttons[identifier]
        if slider.exists {
            if !slider.isHittable { app.swipeUp() }
            for _ in 0..<12 {
                if target.exists && target.isHittable { return target }
                if target.exists && target.frame.midX < slider.frame.minX { slider.swipeRight() }
                else { slider.swipeLeft() }
            }
        }
        XCTAssertTrue(target.waitForExistence(timeout:5)); return target
    }

    @MainActor
    func testHomeMenuSliderPreservesActionsAndLaunch() {
        let app = XCUIApplication(); startUniverseFlightForMenu(app)
        let dock = app.descendants(matching: .any)["Home action slider"].firstMatch
        let identifiers = ["Take flight", "Choose Flight planner", "Choose Free roam", "Choose Space free roam", "Story campaign", "Arena duels", "My creations", "Shop", "Pilot logbook", "Inspect hangar", "Settings"]
        XCTAssertTrue(dock.waitForExistence(timeout:10))
        for orientation in [UIDeviceOrientation.landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            for identifier in identifiers {
                let button = app.buttons[identifier]
                XCTAssertTrue(button.waitForExistence(timeout:5), identifier)
                XCTAssertTrue(button.isHittable, identifier + " must be visible without scrolling")
                XCTAssertGreaterThanOrEqual(button.frame.width, 44)
                XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            }
            let rows = identifiers.map { app.buttons[$0].frame.midY }
            XCTAssertLessThan((rows.max() ?? 0)-(rows.min() ?? 0),2,"Phone navigation must remain a single row")
            capture(app,name:"Single-row glass navigation on iPhone landscape")
        }
        app.buttons["Choose Space free roam"].tap()
        XCTAssertTrue(app.staticTexts["Current flight selection"].label.contains("Space"))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Flight settings"].waitForExistence(timeout:10))
        XCTAssertTrue(dock.exists)
        for identifier in identifiers { XCTAssertTrue(app.buttons[identifier].isHittable, identifier + " in Settings") }
        capture(app,name:"Persistent Liquid Glass navigation in Settings")
        // Switch sections directly, without closing the workspace or losing the dock.
        app.buttons["Choose Flight planner"].tap()
        XCTAssertTrue(app.buttons["Planner done"].waitForExistence(timeout:10)); XCTAssertTrue(dock.exists)
        app.buttons["Shop"].tap()
        XCTAssertTrue(app.navigationBars["Supply shop"].waitForExistence(timeout:10)); XCTAssertTrue(dock.exists)
        capture(app,name:"Shared glass navigation in the shop")
        let launch = app.buttons["Take flight"]
        expectation(for:NSPredicate(format:"isEnabled == true"),evaluatedWith:launch); waitForExpectations(timeout:120)
        launch.tap()
        XCTAssertTrue(app.buttons["Hyperspace"].waitForExistence(timeout:15))
        XCTAssertFalse(dock.exists)
        app.buttons["Pause flight"].tap()
    }
    @MainActor
    private func startUniverseFlightForMenu(_ app: XCUIApplication) {
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launchArguments = ["-aircraft","xwing","-level","freeRoam","-spaceFreeRoam","NO","-introStyle","canva"]
        app.launch(); settleStoryLaunch(app)
    }

    @MainActor
    private func settleStoryLaunch(_ app:XCUIApplication) {
        let skip = app.buttons["Skip intro"]
        if skip.waitForExistence(timeout:5), skip.isHittable { skip.tap() }
        app.open(URL(string:"starflight://hangar")!)
        expectation(for:NSPredicate(format:"exists == false"),evaluatedWith:app.buttons["Skip intro"])
        waitForExpectations(timeout:15)
        XCTAssertTrue(app.buttons["Take flight"].waitForExistence(timeout:15))
    }
    @MainActor
    private func revealStoryControl(_ control:XCUIElement,in app:XCUIApplication) {
        for _ in 0..<14 {
            let middle = control.frame.midY, viewport = app.frame
            // A partially visible cell can be hittable while its centre is behind the pinned launch button.
            if control.isHittable && middle > viewport.minY+75 && middle < viewport.maxY-120 { return }
            let downward = control.exists && middle < viewport.minY+75
            app.coordinate(withNormalizedOffset:CGVector(dx:0.55,dy:downward ? 0.30:0.64)).press(forDuration:0.05,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.55,dy:downward ? 0.64:0.30)))
        }
    }
    @MainActor
    func testStoryFlightPlanChoicePersistsAndShowsBothConsequences() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft","kestrel","-level","freeRoam","-introStyle","canva"]
        app.launchEnvironment["STARFLIGHT_ECONOMY_FIXTURE"] = "funded"; app.launch()
        settleStoryLaunch(app)
        tapHomeAction("Story campaign", in: app)
        let covert = app.buttons["Story approach covert"]
        revealStoryControl(covert,in:app); XCTAssertTrue(covert.isHittable)
        capture(app,name:"Choose rescue or covert story plan with different mission requirements")
        covert.tap(); app.terminate(); app.launchEnvironment.removeValue(forKey:"STARFLIGHT_ECONOMY_FIXTURE"); app.launch()
        settleStoryLaunch(app)
        tapHomeAction("Story campaign", in: app); revealStoryControl(app.buttons["Story approach covert"],in:app)
        XCTAssertEqual(app.buttons["Story approach covert"].value as? String,"Selected")
        app.buttons["Close story campaign"].tap()
    }
    @MainActor
    func testCovertHothChapterUsesMistAndRealFlightObjective() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft","kestrel","-level","freeRoam","-introStyle","canva","-soundEnabled","YES"]
        app.launchEnvironment["STARFLIGHT_ECONOMY_FIXTURE"] = "funded"
        app.launchEnvironment["STARFLIGHT_STORY_FIXTURE"] = "hoth"; app.launch()
        settleStoryLaunch(app)
        tapHomeAction("Story campaign", in: app); XCTAssertEqual(app.staticTexts["Story chapter title"].label,"The White Silence")
        revealStoryControl(app.staticTexts["Story transmission"],in:app)
        capture(app,name:"Hoth mystery transmission and branching campaign briefing")
        app.buttons["Launch story chapter"].tap()
        let objective = app.descendants(matching:.any)["Story flight objective"].firstMatch
        XCTAssertTrue(objective.waitForExistence(timeout:120)); XCTAssertTrue(objective.label.contains("0/2"))
        assertCoreControlsInsideScreen(app)
        capture(app,name:"Flying through drifting mist on Hoth")
        app.buttons["Pause flight"].tap()
    }
    @MainActor
    func testEndorRelayDecisionAndEvidenceJournal() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft","kestrel","-level","freeRoam","-introStyle","canva"]
        app.launchEnvironment["STARFLIGHT_ECONOMY_FIXTURE"] = "funded"
        app.launchEnvironment["STARFLIGHT_STORY_FIXTURE"] = "endor"; app.launch()
        settleStoryLaunch(app)
        tapHomeAction("Story campaign", in: app)
        let silent = app.buttons["Story relay silent"]; revealStoryControl(silent,in:app)
        XCTAssertTrue(silent.isHittable); silent.tap()
        XCTAssertEqual(silent.value as? String,"Selected")
        capture(app,name:"Endor broadcast or encrypted transmission story decision")
        app.buttons["Launch story chapter"].tap()
        let objective = app.descendants(matching:.any)["Story flight objective"].firstMatch
        XCTAssertTrue(objective.waitForExistence(timeout:120)); XCTAssertTrue(objective.label.contains("0/3"))
        capture(app,name:"Endor forest mist with encrypted-route objective")
        app.buttons["Pause flight"].tap(); app.buttons["Back to base"].tap(); tapHomeAction("Story campaign", in: app)
        let evidence = app.descendants(matching:.any)["Story evidence journal"].firstMatch
        revealStoryControl(evidence,in:app); XCTAssertTrue(evidence.isHittable); evidence.tap()
        capture(app,name:"Recovered evidence journal with Mira and Voss clues")
        app.buttons["Close story campaign"].tap()
    }

    @MainActor
    func testStoryChapterBriefingLaunchAndJournal() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft","kestrel","-level","freeRoam","-introStyle","canva"]
        app.launchEnvironment["STARFLIGHT_ECONOMY_FIXTURE"] = "funded"
        app.launch()
        settleStoryLaunch(app)
        XCTAssertTrue(app.buttons["Story campaign"].waitForExistence(timeout:30)); tapHomeAction("Story campaign", in: app)
        XCTAssertTrue(app.staticTexts["Story chapter title"].waitForExistence(timeout:10))
        XCTAssertEqual(app.staticTexts["Story chapter title"].label,"A Voice in the Traffic")
        capture(app,name:"The Last Beacon campaign and chapter one briefing")
        app.scrollViews.firstMatch.swipeUp()
        capture(app,name:"Droid dialogue and playable story objective")
        app.buttons["Launch story chapter"].tap()
        let objective = app.descendants(matching:.any)["Story flight objective"].firstMatch
        XCTAssertTrue(objective.waitForExistence(timeout:120))
        XCTAssertTrue(objective.label.contains("Spaceport Connection"))
        capture(app,name:"Chapter one flying over Coruscant with a story objective")
        app.buttons["Pause flight"].tap(); app.buttons["Back to base"].tap()
        tapHomeAction("Story campaign", in: app)
        XCTAssertTrue(app.staticTexts["Story campaign progress"].label.contains("0 / 7"))
        XCTAssertTrue(app.buttons["Launch story chapter"].label.contains("Restart"))
        app.buttons["Close story campaign"].tap()
    }

    @MainActor
    func testStoryRepairChapterCompletesDebriefsAndPersists() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft","xwing","-level","freeRoam","-introStyle","canva","-flightWeather","clear"]
        app.launchEnvironment["STARFLIGHT_ECONOMY_FIXTURE"] = "funded"
        app.launchEnvironment["STARFLIGHT_STORY_FIXTURE"] = "lifeline"
        app.launch()
        settleStoryLaunch(app)
        tapHomeAction("Story campaign", in: app)
        XCTAssertEqual(app.staticTexts["Story chapter title"].label,"One Engine, One Chance")
        capture(app,name:"Chapter six repair mission briefing")
        app.buttons["Launch story chapter"].tap()
        XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout:120))
        app.buttons["Flight tools"].tap(); app.buttons["Navigation and missions"].tap()
        app.segmentedControls["Adventure sections"].buttons["Routes"].tap()
        let assist = app.buttons["Navigation assist route"], form = app.collectionViews.firstMatch
        for _ in 0..<7 { if assist.isHittable { break }; form.swipeUp() }
        XCTAssertTrue(assist.isHittable); assist.tap()
        app.navigationBars.buttons["Flight tools"].tap(); app.buttons["Resume"].tap()
        let dock = app.buttons["Dock for emergency repair"]
        XCTAssertTrue(dock.waitForExistence(timeout:35)); capture(app,name:"Flying the story repair approach")
        dock.tap()
        let progress = app.staticTexts["Story campaign progress"]
        XCTAssertTrue(progress.waitForExistence(timeout:60))
        XCTAssertTrue(progress.label.contains("6 / 7"))
        XCTAssertEqual(app.staticTexts["Story chapter title"].label,"The Last Beacon")
        capture(app,name:"Chapter complete transmission reward and final mission unlocked")
        app.terminate()
        app.launchEnvironment.removeValue(forKey:"STARFLIGHT_STORY_FIXTURE")
        app.launchEnvironment.removeValue(forKey:"STARFLIGHT_ECONOMY_FIXTURE")
        app.launch()
        settleStoryLaunch(app)
        tapHomeAction("Story campaign", in: app)
        XCTAssertTrue(app.staticTexts["Story campaign progress"].label.contains("6 / 7"))
        XCTAssertEqual(app.staticTexts["Story chapter title"].label,"The Last Beacon")
        app.buttons["Close story campaign"].tap()
    }

    @MainActor
    func testStoryEndingChoicePersistsAfterReopening() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft","xwing","-level","freeRoam","-introStyle","canva"]
        app.launchEnvironment["STARFLIGHT_ECONOMY_FIXTURE"] = "funded"
        app.launchEnvironment["STARFLIGHT_STORY_FIXTURE"] = "ending"
        app.launch()
        settleStoryLaunch(app)
        tapHomeAction("Story campaign", in: app)
        let choice = app.buttons["Story ending guardian"]
        for _ in 0..<5 { if choice.isHittable { break }; app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(choice.isHittable); capture(app,name:"Campaign ending choices")
        choice.tap()
        XCTAssertTrue(app.staticTexts["Keeper of the Lights"].waitForExistence(timeout:5))
        capture(app,name:"Keeper of the Lights saved story epilogue")
        app.terminate()
        app.launchEnvironment.removeValue(forKey:"STARFLIGHT_STORY_FIXTURE")
        app.launchEnvironment.removeValue(forKey:"STARFLIGHT_ECONOMY_FIXTURE")
        app.launch()
        settleStoryLaunch(app)
        tapHomeAction("Story campaign", in: app)
        XCTAssertTrue(app.staticTexts["Keeper of the Lights"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["Story ending independent"].exists)
        app.buttons["Close story campaign"].tap()
    }

    @MainActor
    func testBankingReplayMissionsAndConfirmationReturnLink() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft","xwing","-level","freeRoam","-spaceFreeRoam","YES","-introStyle","canva","-invertPitch","NO"]
        app.launchEnvironment["STARFLIGHT_ECONOMY_FIXTURE"] = "funded"
        app.launch()
        if app.buttons["Skip intro"].waitForExistence(timeout:4) { app.buttons["Skip intro"].tap() }
        app.open(URL(string:"starflight://hangar")!)
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout:30))
        expectation(for:NSPredicate(format:"isEnabled == true"),evaluatedWith:start); waitForExpectations(timeout:120)
        start.tap()
        let joystick = app.descendants(matching:.any)["Flight joystick"].firstMatch
        XCTAssertTrue(joystick.waitForExistence(timeout:10))
        joystick.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
            .press(forDuration:0.1,thenDragTo:joystick.coordinate(withNormalizedOffset:CGVector(dx:0.98,dy:0.5)),withVelocity:.fast,thenHoldForDuration:16)
        XCTAssertTrue(app.buttons["Pause flight"].exists)
        capture(app,name:"Flight after sustained bounded banking")
        app.buttons["Pause flight"].tap()
        let replay = app.buttons["Watch last 15 seconds"]
        XCTAssertTrue(replay.waitForExistence(timeout:5)); replay.tap()
        XCTAssertTrue(app.sliders["Replay timeline"].waitForExistence(timeout:5))
        app.sliders["Replay timeline"].adjust(toNormalizedSliderPosition:0.25)
        capture(app,name:"Flight path replay with timeline and paused gameplay")
        app.buttons["Close replay"].tap()
        XCTAssertTrue(app.buttons["Resume flight"].waitForExistence(timeout:5))
        app.buttons["Resume flight"].tap()
        app.buttons["Flight tools"].tap()
        app.buttons["Navigation and missions"].tap()
        XCTAssertTrue(app.buttons["Accept emergency engine"].waitForExistence(timeout:5))
        capture(app,name:"Optional emergency contracts and career unlocks")
        app.buttons["Accept emergency engine"].tap()
        XCTAssertTrue(app.buttons["Cancel emergency contract"].waitForExistence(timeout:5))
        capture(app,name:"Accepted repair challenge with approach guidance")
        app.buttons["Cancel emergency contract"].tap()
        XCTAssertTrue(app.buttons["Accept emergency engine"].waitForExistence(timeout:5))
        app.segmentedControls["Adventure sections"].buttons["Routes"].tap()
        let form = app.collectionViews.firstMatch
        let save = app.buttons["Create saved route"]
        for _ in 0..<7 { if save.isHittable { break }; form.swipeUp() }
        XCTAssertTrue(save.isHittable); save.tap()
        app.textFields["Saved route name"].tap(); app.textFields["Saved route name"].typeText("Test Outer Rim")
        app.buttons["Add stop"].tap(); app.buttons["Save route"].tap()
        let follow = app.buttons["Follow Test Outer Rim"]
        for _ in 0..<5 { if follow.isHittable { break }; form.swipeUp() }
        XCTAssertTrue(follow.isHittable); follow.tap()
        XCTAssertTrue(app.staticTexts["Adventure status"].label.contains("next"))
        capture(app,name:"Saved planetary route ready to follow")
    }

    @MainActor
    func testEmergencyContractApproachCompletesThroughNormalFlight() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft","xwing","-level","freeRoam","-spaceFreeRoam","YES","-flightWeather","clear","-introStyle","canva","-invertPitch","NO"]
        app.launchEnvironment["STARFLIGHT_ECONOMY_FIXTURE"] = "funded"
        app.launch()
        if app.buttons["Skip intro"].waitForExistence(timeout:4) { app.buttons["Skip intro"].tap() }
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout:30))
        expectation(for:NSPredicate(format:"isEnabled == true"),evaluatedWith:start); waitForExpectations(timeout:120)
        start.tap()
        app.buttons["Flight tools"].tap(); app.buttons["Navigation and missions"].tap()
        app.buttons["Accept emergency engine"].tap()
        app.segmentedControls["Adventure sections"].buttons["Routes"].tap()
        let follow = app.buttons["Navigation assist route"], form = app.collectionViews.firstMatch
        for _ in 0..<7 { if follow.isHittable { break }; form.swipeUp() }
        XCTAssertTrue(follow.isHittable); follow.tap()
        app.navigationBars.buttons["Flight tools"].tap()
        app.buttons["Resume"].tap()
        let dock = app.buttons["Dock for emergency repair"]
        XCTAssertTrue(dock.waitForExistence(timeout:30))
        capture(app,name:"Real flight approach to the repair platform")
        dock.tap()
        let active = app.descendants(matching:.any)["Emergency contract HUD"].firstMatch
        expectation(for:NSPredicate(format:"exists == false"),evaluatedWith:active); waitForExpectations(timeout:50)
        app.buttons["Flight tools"].tap(); app.buttons["Navigation and missions"].tap()
        XCTAssertTrue(app.staticTexts["Adventure status"].label.contains("Contract complete"))
        XCTAssertTrue(app.staticTexts["Adventure status"].label.contains("120"))
        capture(app,name:"Safe repair touchdown completes and pays the contract")
    }

    @MainActor
    func testNavigationMapLayersAndSavedRouteDisplay() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft","xwing","-level","freeRoam","-spaceFreeRoam","YES","-introStyle","canva"]
        app.launch()
        if app.buttons["Skip intro"].waitForExistence(timeout:4) { app.buttons["Skip intro"].tap() }
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout:30))
        expectation(for:NSPredicate(format:"isEnabled == true"),evaluatedWith:start); waitForExpectations(timeout:120)
        start.tap(); app.buttons["Space map"].tap()
        let layers = app.buttons["Space map layers"]
        XCTAssertTrue(layers.waitForExistence(timeout:10)); layers.tap()
        let grid = app.descendants(matching:.any).matching(NSPredicate(format:"label == %@","Grid")).firstMatch
        XCTAssertTrue(grid.waitForExistence(timeout:5))
        capture(app,name:"Navigation map grid trade and saved-route layers")
        grid.tap()
        capture(app,name:"Orbital navigation with map layers available")
        app.buttons["Space map done"].tap()
        XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout:5))
        app.buttons["Pause flight"].tap()
    }

    @MainActor
    func testWeatherBriefingAndPlanetFlight() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft","kestrel","-level","alpine","-spaceFreeRoam","NO","-flightWeather","whiteout","-introStyle","canva"]
        app.launch()
        if app.buttons["Skip intro"].waitForExistence(timeout:4) { app.buttons["Skip intro"].tap() }
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout:30))
        expectation(for:NSPredicate(format:"isEnabled == true"),evaluatedWith:start); waitForExpectations(timeout:120)
        start.tap()
        XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout:10))
        capture(app,name:"Hoth snow squall with bounded weather particles")
        app.buttons["Pause flight"].tap()
    }

    @MainActor
    func testOreScannerCopilotLoopAndPasswordRecoveryForm() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft", "xwing", "-level", "freeRoam", "-spaceFreeRoam", "YES", "-introStyle", "canva", "-invertPitch", "NO"]
        app.launchEnvironment["STARFLIGHT_ECONOMY_FIXTURE"] = "funded"
        app.launch()
        if app.buttons["Skip intro"].waitForExistence(timeout: 4) { app.buttons["Skip intro"].tap() }
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout: 30))
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: start); waitForExpectations(timeout: 120)
        start.tap()
        let scan = app.buttons["Scan asteroid ore"]
        XCTAssertTrue(scan.waitForExistence(timeout: 15)); scan.tap()
        XCTAssertTrue(app.descendants(matching: .any)["Ore scan result"].firstMatch.waitForExistence(timeout: 10))
        capture(app, name: "Forward ore scanner with material rarity and hazard")
        app.buttons["Flight tools"].tap()
        let level = app.buttons["Droid assist level"]
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<8 {
            if level.isHittable { break }
            scroll.swipeUp()
        }
        XCTAssertTrue(level.isHittable); level.tap()
        XCTAssertTrue(app.staticTexts["Droid assist status"].label.contains("Level ship"))
        capture(app, name: "Droid copilot assistance and manual takeover guidance")
        app.buttons["Resume"].tap()
        let joystick = app.descendants(matching: .any)["Flight joystick"].firstMatch
        XCTAssertTrue(joystick.waitForExistence(timeout: 10))
        joystick.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: joystick.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)), withVelocity: .fast, thenHoldForDuration: 6.7)
        XCTAssertTrue(app.buttons["Pause flight"].exists)
        capture(app, name: "Space flight after full loop and manual copilot override")
        app.buttons["Pause flight"].tap()
        app.buttons["Back to base"].tap()
        tapHomeAction("Settings", in: app)
        app.buttons["Starflight account"].tap()
        app.buttons["Forgot password?"].tap()
        XCTAssertTrue(app.textFields["Starflight recovery link"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Send password reset email"].exists)
        capture(app, name: "Default Supabase email link recovery form")
        app.buttons["Back to sign in"].tap()
        XCTAssertTrue(app.buttons["Submit Starflight account"].exists)
        app.buttons["Close Starflight account"].tap()
    }

    @MainActor
    func testHangarArrowsAccountWizardAndIntroSettings() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft", "kestrel", "-level", "freeRoam", "-spaceFreeRoam", "YES", "-introStyle", "canva"]
        app.launch()
        if app.buttons["Skip intro"].waitForExistence(timeout: 4) { app.buttons["Skip intro"].tap() }
        XCTAssertTrue(app.buttons["Next hangar ship"].waitForExistence(timeout: 30))
        let selection = app.staticTexts["Current flight selection"].label
        app.buttons["Next hangar ship"].tap()
        XCTAssertNotEqual(app.staticTexts["Current flight selection"].label, selection)
        app.buttons["Previous hangar ship"].tap()
        XCTAssertEqual(app.staticTexts["Current flight selection"].label, selection)
        capture(app, name: "Hangar ship selection arrows")
        tapHomeAction("Settings", in: app)
        app.buttons["Starflight account"].tap()
        let create = app.segmentedControls["Account action"].buttons["Create account"]
        XCTAssertTrue(create.waitForExistence(timeout: 10)); create.tap()
        let submit = app.buttons["Submit Starflight account"]
        for _ in 0..<3 { if submit.exists && submit.isHittable { break }; app.collectionViews.element(boundBy: max(0, app.collectionViews.count - 1)).swipeUp() }
        XCTAssertTrue(submit.exists)
        XCTAssertFalse(submit.isEnabled)
        capture(app, name: "Guided account creation without a code wall")
        app.buttons["Close Starflight account"].tap()
        let intro = app.buttons["Preview selected intro"]
        for _ in 0..<7 { if intro.exists && intro.isHittable { break }; app.collectionViews.element(boundBy: max(0, app.collectionViews.count - 1)).swipeUp() }
        XCTAssertTrue(intro.isHittable)
        capture(app, name: "Choose Canva or Star Wars opening intro")
        intro.tap()
        XCTAssertTrue(app.descendants(matching: .any)["Intro video"].firstMatch.waitForExistence(timeout: 10))
        capture(app, name: "Canva intro preview")
        app.buttons["Skip intro"].tap()
        app.buttons["Done"].tap()
    }

    @MainActor
    func testMiningColourKeyAndStableFlightViewport() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft", "kestrel", "-level", "freeRoam", "-spaceFreeRoam", "YES", "-introStyle", "starWars"]
        app.launchEnvironment["STARFLIGHT_ECONOMY_FIXTURE"] = "funded"
        app.launch()
        if app.buttons["Skip intro"].waitForExistence(timeout: 4) {
            capture(app, name: "Original yellow Star Wars intro")
            app.buttons["Skip intro"].tap()
        }
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout: 30))
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: start); waitForExpectations(timeout: 120)
        start.tap()
        XCTAssertTrue(app.buttons["Mining & Trade"].waitForExistence(timeout: 10))
        let joystick = app.descendants(matching: .any)["Flight joystick"].firstMatch
        let frame = joystick.frame
        app.buttons["Mining & Trade"].tap()
        let mode = app.descendants(matching: .any)["Mining mode"].firstMatch
        XCTAssertTrue(mode.waitForExistence(timeout: 10))
        if mode.value as? String != "1" { mode.tap() }
        app.buttons["Show mineral rarity key"].tap()
        XCTAssertTrue(app.buttons["Close mineral rarity key"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Common"].exists)
        XCTAssertTrue(app.staticTexts["Impossible"].exists)
        capture(app, name: "Mining and trade eight tier rarity colour key")
        app.buttons["Close mineral rarity key"].tap()
        app.buttons["Trade console done"].tap()
        XCTAssertTrue(app.buttons["Fire weapons"].waitForExistence(timeout: 10))
        XCTAssertEqual(joystick.frame.minY, frame.minY, accuracy: 1)
        capture(app, name: "Fixed flight viewport after opening and closing panels")
        app.buttons["Fire weapons"].tap()
        let cargo = app.descendants(matching: .any)["Mining cargo"].firstMatch
        expectation(for: NSPredicate(format: "value != %@", "0/120"), evaluatedWith: cargo); waitForExpectations(timeout: 30)
        capture(app, name: "Minerals collected with rarity coloured messages")
        app.buttons["Fire weapons"].tap()
        app.buttons["Pause flight"].tap()
        app.buttons["Back to base"].tap()
    }

    @MainActor
    func testFocusedHothCockpitAndClearCrashCamera() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft", "kestrel", "-level", "alpine", "-spaceFreeRoam", "NO", "-invertPitch", "NO"]
        app.launch()
        let skip = app.buttons["Skip intro"]
        if skip.waitForExistence(timeout: 3) { skip.tap() }
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout: 30))
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: start)
        waitForExpectations(timeout: 90)
        start.tap()
        XCTAssertTrue(app.buttons["Switch camera"].waitForExistence(timeout: 10))
        app.buttons["Switch camera"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["Height above ground"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["Airspeed"].firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any)["Climb or descent rate"].firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any)["Credits balance"].firstMatch.exists)
        capture(app, name: "Focused Hoth cockpit and snow finish")
        let joystick = app.descendants(matching: .any)["Flight joystick"].firstMatch
        XCTAssertTrue(joystick.exists)
        joystick.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: joystick.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.08)), withVelocity: .slow, thenHoldForDuration: 22)
        XCTAssertTrue(app.buttons["Fly again"].waitForExistence(timeout: 15))
        capture(app, name: "Hoth crash camera above the scenery")
        app.buttons["Fly again"].tap()
        XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout: 10))
        app.buttons["Pause flight"].tap()
        app.buttons["Back to base"].tap()
    }

    @MainActor
    func testLockedMarketOffersItsFreeConnectionBesideSale() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft", "kestrel", "-level", "freeRoam", "-spaceFreeRoam", "YES"]
        app.launchEnvironment["STARFLIGHT_ECONOMY_FIXTURE"] = "funded"
        app.launch()
        let skip = app.buttons["Skip intro"]
        if skip.waitForExistence(timeout: 3) { skip.tap() }
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout: 30))
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: start)
        waitForExpectations(timeout: 90)
        start.tap()
        XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout: 15))
        app.buttons["Flight tools"].tap()
        app.buttons["Navigate to Tatooine"].tap()
        app.buttons["Enter Tatooine"].tap()
        XCTAssertTrue(app.buttons["Mining & Trade"].waitForExistence(timeout: 90))
        app.buttons["Mining & Trade"].tap()
        let connection = app.buttons["Open required trade route"]
        XCTAssertTrue(connection.waitForExistence(timeout: 10))
        XCTAssertTrue(connection.isHittable)
        XCTAssertTrue(connection.label.contains("Free"))
        capture(app, name: "Required free route beside the locked sale")
        connection.tap()
        XCTAssertTrue(app.staticTexts["Market trade receipt"].label.contains("Opened Coruscant"))
        XCTAssertFalse(connection.exists)
        capture(app, name: "Connected market ready for cargo sales")
        app.buttons["Trade console done"].tap()
        XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout: 10))
        app.buttons["Pause flight"].tap()
        app.buttons["Back to base"].tap()
    }

    @MainActor
    func testOpeningVideoCompletesNaturally() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()
        let video = app.descendants(matching: .any)["Intro video"].firstMatch
        XCTAssertTrue(video.waitForExistence(timeout: 5))
        capture(app, name: "Canva opening video before natural completion")
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: video)
        waitForExpectations(timeout: 35)
        XCTAssertFalse(app.buttons["Skip intro"].exists)
        XCTAssertTrue(app.buttons["Take flight"].waitForExistence(timeout: 10))
        capture(app, name: "Hangar after opening video completes")
    }

    @MainActor
    func testOpeningVideoFitsLandscapeAndCanBeSkipped() {
        let app = XCUIApplication()
        for orientation: UIDeviceOrientation in [.landscapeLeft, .landscapeRight] {
            XCUIDevice.shared.orientation = orientation
            app.launch()
            let video = app.descendants(matching: .any)["Intro video"].firstMatch
            let skip = app.buttons["Skip intro"]
            XCTAssertTrue(video.waitForExistence(timeout: 5))
            XCTAssertTrue(skip.waitForExistence(timeout: 5))
            let bounds = app.windows.firstMatch.frame
            XCTAssertGreaterThan(video.frame.width, 0)
            XCTAssertGreaterThan(video.frame.height, 0)
            XCTAssertGreaterThanOrEqual(video.frame.minX, bounds.minX)
            XCTAssertLessThanOrEqual(video.frame.maxX, bounds.maxX)
            XCTAssertGreaterThanOrEqual(video.frame.minY, bounds.minY)
            XCTAssertLessThanOrEqual(video.frame.maxY, skip.frame.minY)
            XCTAssertGreaterThanOrEqual(skip.frame.height, 44)
            XCTAssertLessThanOrEqual(skip.frame.maxY, bounds.maxY)
            XCTAssertTrue(skip.isHittable)
            capture(app, name: "Canva opening video safe area \(orientation.rawValue)")
            skip.tap()
            XCTAssertTrue(app.buttons["Take flight"].waitForExistence(timeout: 10))
        }
    }

    @MainActor
    func testDirectHUDMiningAndTradePausesAndResumes() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft", "kestrel", "-level", "freeRoam", "-spaceFreeRoam", "YES"]
        app.launch()
        let skip = app.buttons["Skip intro"]
        if skip.waitForExistence(timeout: 3) { skip.tap() }
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout: 30))
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: start)
        waitForExpectations(timeout: 90)
        if !start.isHittable { app.swipeUp() }
        start.tap()
        let trade = app.buttons["Mining & Trade"]
        XCTAssertTrue(trade.waitForExistence(timeout: 15))
        for visit in 1...2 {
            XCTAssertTrue(trade.isHittable)
            XCTAssertGreaterThanOrEqual(trade.frame.height, 44)
            trade.tap()
            let done = app.buttons["Trade console done"]
            XCTAssertTrue(done.waitForExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts["Mining cargo balance"].exists)
            XCTAssertTrue(app.switches["Mining mode"].exists)
            XCTAssertFalse(trade.isHittable)
            capture(app, name: "Direct HUD trade console visit \(visit)")
            done.tap()
            XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout: 10))
            XCTAssertTrue(trade.waitForExistence(timeout: 5))
            XCTAssertTrue(trade.isHittable)
            XCTAssertFalse(app.buttons["Resume flight"].exists)
        }
        let fire = app.buttons["Fire weapons"]
        XCTAssertTrue(fire.waitForExistence(timeout: 5))
        fire.tap()
        XCTAssertEqual(fire.value as? String, "Firing")
        fire.tap()
        XCTAssertEqual(fire.value as? String, "Off")
        capture(app, name: "Flight resumed after direct HUD trading")
        app.buttons["Pause flight"].tap()
        XCTAssertTrue(app.buttons["Resume flight"].waitForExistence(timeout: 5))
        app.buttons["Back to base"].tap()
    }

    @MainActor
    func testMiningAsteroidsAndSellingAtConnectedMarket() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft","kestrel","-level","freeRoam","-spaceFreeRoam","YES"]
        app.launch()
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout:30))
        expectation(for:NSPredicate(format:"isEnabled == true"),evaluatedWith:start)
        waitForExpectations(timeout:90); start.tap()
        XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout:10))
        app.buttons["Flight tools"].tap()
        app.buttons["Open mining and trade"].tap()
        let mode = app.switches["Mining mode"]
        XCTAssertTrue(mode.waitForExistence(timeout:5)); XCTAssertTrue(mode.isEnabled)
        mode.coordinate(withNormalizedOffset:CGVector(dx:0.95,dy:0.5)).tap()
        XCTAssertEqual(mode.value as? String,"1")
        let starter = app.buttons["Open starter trade route"]
        if starter.exists { starter.tap() }
        capture(app,name:"Mining console and cargo rules")
        app.buttons["Trade console done"].tap()
        app.buttons["Resume"].tap()
        XCTAssertTrue(app.buttons["Fire weapons"].waitForExistence(timeout:5))
        app.buttons["Fire weapons"].tap()
        let cargo = app.descendants(matching:.any)["Mining cargo"].firstMatch
        XCTAssertTrue(cargo.waitForExistence(timeout:5))
        expectation(for:NSPredicate(format:"value != %@", "0/120"),evaluatedWith:cargo)
        waitForExpectations(timeout:15)
        XCTAssertNotEqual(cargo.value as? String,"0/120")
        capture(app,name:"Mining asteroids with cargo on HUD")
        app.buttons["Fire weapons"].tap()
        app.buttons["Flight tools"].tap()
        app.buttons["Navigate to Tatooine"].tap()
        app.buttons["Enter Tatooine"].tap()
        XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout:10))
        app.buttons["Flight tools"].tap()
        app.buttons["Open mining and trade"].tap()
        let sell = app.buttons["Sell mining cargo"]
        for _ in 0..<5 { if sell.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(sell.isHittable); XCTAssertTrue(sell.isEnabled); sell.tap()
        let receipt = app.staticTexts["Market trade receipt"]
        XCTAssertTrue(receipt.waitForExistence(timeout:5))
        XCTAssertTrue(receipt.label.contains("Sold cargo"))
        XCTAssertFalse(sell.isEnabled)
        let balance = app.staticTexts["Mining cargo balance"]
        for _ in 0..<6 { if balance.exists { break }; app.swipeDown() }
        XCTAssertTrue(balance.waitForExistence(timeout:5))
        XCTAssertTrue(balance.label.hasPrefix("0 / 120"))
        capture(app,name:"Mining cargo sold at Tatooine")
    }

    @MainActor
    func testUnconfiguredAccountIsHonestAndOfflinePlayRemainsAvailable() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout:30)); tapHomeAction("Settings", in: app)
        let account = app.buttons["Starflight account"]
        XCTAssertTrue(account.waitForExistence(timeout:10)); account.tap()
        XCTAssertTrue(app.staticTexts["Account status"].waitForExistence(timeout:10))
        XCTAssertTrue(app.staticTexts["Account status"].label.contains("aren’t available"))
        XCTAssertFalse(app.secureTextFields["Starflight password"].exists)
        capture(app,name:"Starflight account – service setup still required")
    }

    @MainActor
    func testTrioBattleShowsRewardsAndTwoRivals() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication(); app.launchArguments = ["-aircraft","xwing"]; app.launch()
        XCTAssertTrue(app.buttons["Arena duels"].waitForExistence(timeout:30)); tapHomeAction("Arena duels", in: app)
        let format = app.segmentedControls["Arena battle format"]
        XCTAssertTrue(format.waitForExistence(timeout:5)); format.buttons["Trio"].tap()
        let prepare = app.buttons["Prepare arena duel"]
        for _ in 0..<10 {
            if prepare.exists && prepare.isHittable { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(prepare.isHittable); prepare.tap()
        let launch = app.buttons["Take flight"]
        XCTAssertTrue(launch.waitForExistence(timeout:10))
        let ready = XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == true"),object:launch)
        XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:120),.completed); launch.tap()
        XCTAssertTrue(app.staticTexts["Duel timer"].waitForExistence(timeout:10))
        for number in [1,2] {
            XCTAssertTrue(app.staticTexts.containing(NSPredicate(format:"label BEGINSWITH %@ AND label CONTAINS %@","RIVAL \(number) ·","SHIELDS")).firstMatch.exists)
        }
        capture(app,name:"Trio battle – both rivals and target tracking")
        app.buttons["Pause flight"].tap(); app.buttons["Back to base"].tap()
    }

    @MainActor
    func testArenaLaunchPauseFireAndReturnToBase() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft","xwing","-introStyle","canva"]
        app.launch(); settleStoryLaunch(app)
        XCTAssertTrue(app.buttons["Arena duels"].waitForExistence(timeout:30))
        tapHomeAction("Arena duels", in: app)
        let prepare = app.buttons["Prepare arena duel"]
        for _ in 0..<6 {
            if prepare.exists && prepare.isHittable { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(prepare.isHittable); prepare.tap()
        let launch = app.buttons["Take flight"]
        XCTAssertTrue(launch.waitForExistence(timeout:10))
        let ready = XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == true"),object:launch)
        XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:120),.completed)
        launch.tap()
        XCTAssertTrue(app.staticTexts["Duel timer"].waitForExistence(timeout:10))
        XCTAssertFalse(app.buttons["Space map"].exists)
        app.buttons["Fire weapons"].tap()
        XCTAssertEqual(app.buttons["Fire weapons"].value as? String,"Firing")
        assertCoreControlsInsideScreen(app)
        capture(app,name:"Arena duel – shields target and controls")
        app.buttons["Pause flight"].tap()
        XCTAssertTrue(app.buttons["Resume flight"].waitForExistence(timeout:5))
        app.buttons["Resume flight"].tap()
        XCTAssertTrue(app.staticTexts["Duel timer"].waitForExistence(timeout:5))
        app.buttons["Pause flight"].tap()
        app.buttons["Back to base"].tap()
        XCTAssertTrue(app.buttons["Arena duels"].waitForExistence(timeout:5))
    }

    @MainActor
    func testMountainCreatorSavesAtEditorLimits() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()
        let workshop = app.buttons["My creations"]
        XCTAssertTrue(workshop.waitForExistence(timeout: 30))
        workshop.tap()
        for title in ["Mountain height", "Valley width", "Bend strength", "Saddle height"] {
            let slider = app.sliders[title]
            for _ in 0..<8 {
                if slider.exists && slider.isHittable { break }
                app.collectionViews.firstMatch.swipeUp()
            }
            guard slider.exists && slider.isHittable else {
                XCTFail("Cannot reach \(title): \(app.debugDescription)")
                return
            }
            slider.adjust(toNormalizedSliderPosition: 1)
        }
        let save = app.buttons["Save custom level"]
        for _ in 0..<8 {
            if save.exists && save.isHittable { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(save.isHittable)
        save.tap()
        let confirmation = app.alerts["Level saved"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 10))
        XCTAssertTrue(confirmation.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Saved and selected")).firstMatch.exists)
        confirmation.buttons["Back to hangar"].tap()
        XCTAssertTrue(app.buttons["My creations"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSpaceCometPreview() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft","kestrel","-level","freeRoam","-spaceFreeRoam","YES"]
        app.launch()
        let launch = app.buttons["Take flight"]
        XCTAssertTrue(launch.waitForExistence(timeout:30))
        let ready = XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == true"),object:launch)
        XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:120),.completed)
        launch.tap()
        XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout:10))
        capture(app,name:"Orbit – comets absent")
        app.buttons["Flight tools"].tap(); app.buttons["Enter Coruscant"].tap()
        XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout:10))
        capture(app,name:"Planet sky – icy comet and fading blue tail")
        app.buttons["Pause flight"].tap()
    }

    @MainActor
    private func revealCityExpansion(_ element:XCUIElement,in app:XCUIApplication) {
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<20 {
            let viewport = scroll.frame.insetBy(dx:10,dy:35)
            if element.exists, element.isHittable, viewport.contains(element.frame) { return }
            let up = element.exists && element.frame.minY < viewport.minY
            scroll.coordinate(withNormalizedOffset:CGVector(dx:0.98,dy:up ? 0.35:0.78))
                .press(forDuration:0.05,thenDragTo:scroll.coordinate(withNormalizedOffset:CGVector(dx:0.98,dy:up ? 0.78:0.35)))
        }
        XCTAssertTrue(element.isHittable,element.identifier)
    }

    @MainActor
    func testEstatesBuyFurnishPreviewAndReload() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchEnvironment["STARFLIGHT_ECONOMY_FIXTURE"] = "funded"
        app.launchArguments = ["-aircraft","kestrel","-level","freeRoam","-spaceFreeRoam","YES"]
        app.launch()
        XCTAssertTrue(app.buttons["Shop"].waitForExistence(timeout:30)); tapHomeAction("Shop", in: app)
        XCTAssertTrue(app.buttons["Shop homes"].waitForExistence(timeout:5)); app.buttons["Shop homes"].tap()
        for id in ["aurora","obsidian","cloud","senate"] { XCTAssertTrue(app.buttons["Select estate "+id].exists) }
        let buy = app.buttons["Buy selected estate"]; revealCityExpansion(buy,in:app); buy.tap()
        let confirm = app.buttons["Buy for 900 credits"]
        XCTAssertTrue(confirm.waitForExistence(timeout:5)); confirm.tap()
        let aquarium = app.buttons["Estate item aquarium"]
        revealCityExpansion(aquarium,in:app); aquarium.tap()
        XCTAssertEqual(aquarium.label,"Remove from room")
        aquarium.tap(); XCTAssertEqual(aquarium.label,"Install in room")
        aquarium.tap(); XCTAssertEqual(aquarium.label,"Remove from room")
        let holo = app.buttons["Estate item holotable"]; revealCityExpansion(holo,in:app); holo.tap()
        XCTAssertEqual(holo.label,"Remove from room")
        XCTAssertEqual(app.staticTexts["Estate credits"].label,"3680.00 credits")
        let mode = app.segmentedControls["Estate preview mode"]; revealCityExpansion(mode,in:app)
        XCTAssertTrue(app.descendants(matching:.any).matching(identifier:"Residence 3D preview").firstMatch.exists)
        capture(app,name:"Aurora home interior – purchased aquarium and holo table")
        mode.buttons["Exterior"].tap()
        capture(app,name:"Aurora Garden Villa – exterior architecture")
        app.terminate(); app.launchEnvironment.removeValue(forKey:"STARFLIGHT_ECONOMY_FIXTURE"); app.launch()
        XCTAssertTrue(app.buttons["Shop"].waitForExistence(timeout:30)); tapHomeAction("Shop", in: app)
        app.buttons["Shop homes"].tap()
        XCTAssertEqual(app.staticTexts["Estate credits"].label,"3680.00 credits")
        revealCityExpansion(app.buttons["Estate item aquarium"],in:app)
        XCTAssertEqual(app.buttons["Estate item aquarium"].label,"Remove from room")
        XCTAssertEqual(app.buttons["Estate item holotable"].label,"Remove from room")
        app.navigationBars.buttons.element(boundBy:0).tap()
        app.buttons["Shop done"].tap()
        let launch = app.buttons["Take flight"]
        expectation(for:NSPredicate(format:"isEnabled == true"),evaluatedWith:launch); waitForExpectations(timeout:120)
        launch.tap(); XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout:10))
        app.buttons["Flight tools"].tap(); app.buttons["Enter Coruscant"].tap()
        XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout:10)); app.buttons["Flight tools"].tap()
        let homes = app.buttons["Coruscant homes"]; revealCityExpansion(homes,in:app); homes.tap()
        let visit = app.buttons["Visit selected estate"]; revealCityExpansion(visit,in:app); visit.tap()
        XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout:10))
        capture(app,name:"Built Aurora residence – safe clear avenue arrival")
        app.buttons["Pause flight"].tap()
    }

    @MainActor
    func testFactionWorkBountyHUDAndPlanetComets() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft","kestrel","-level","freeRoam","-spaceFreeRoam","YES"]
        app.launch()
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout:30))
        expectation(for:NSPredicate(format:"isEnabled == true"),evaluatedWith:start); waitForExpectations(timeout:120)
        start.tap(); XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout:10))
        app.buttons["Flight tools"].tap(); app.buttons["Enter Coruscant"].tap()
        XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout:10))
        capture(app,name:"Planet comet – fading tail above Coruscant")
        for (faction,contract) in [("republic","republicRelief"),("empire","imperialSurvey")] {
            app.buttons["Flight tools"].tap()
            let contacts = app.buttons["Coruscant factions"]; revealCityExpansion(contacts,in:app); contacts.tap()
            app.buttons["Faction "+faction].tap()
            let accept = app.buttons["Accept faction "+contract]; revealCityExpansion(accept,in:app)
            capture(app,name:faction+" faction contracts")
            accept.tap()
            XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout:10))
            XCTAssertTrue(app.descendants(matching:.any).matching(identifier:"City job objective").firstMatch.exists)
            app.buttons["Flight tools"].tap()
            let jobs = app.buttons["Coruscant jobs"]; revealCityExpansion(jobs,in:app); jobs.tap()
            let cancel = app.buttons["Cancel city job"]; revealCityExpansion(cancel,in:app); cancel.tap()
            app.buttons["City jobs done"].tap(); app.buttons["Resume"].tap()
        }
        app.buttons["Flight tools"].tap()
        let contacts = app.buttons["Coruscant factions"]; revealCityExpansion(contacts,in:app); contacts.tap()
        app.buttons["Faction hunters"].tap()
        let track = app.buttons["Accept bounty runaway"]; revealCityExpansion(track,in:app); track.tap()
        XCTAssertTrue(app.descendants(matching:.any).matching(identifier:"Active bounty HUD").firstMatch.waitForExistence(timeout:10))
        capture(app,name:"Bounty hunt – marked target navigation and shield feedback")
        app.buttons["Flight tools"].tap()
        revealCityExpansion(app.buttons["Coruscant factions"],in:app); app.buttons["Coruscant factions"].tap()
        let cancel = app.buttons["Cancel bounty"]; revealCityExpansion(cancel,in:app); cancel.tap()
        app.navigationBars.buttons.element(boundBy:0).tap()
        app.buttons["Resume"].tap(); app.buttons["Pause flight"].tap()
    }

    @MainActor
    func testLandEnterWalkArrangeAndDepartOwnedHome() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchEnvironment["STARFLIGHT_HOME_FIXTURE"] = "landing"
        app.launchArguments = ["-aircraft","kestrel","-level","freeRoam","-spaceFreeRoam","YES"]
        app.launch()
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout:30))
        expectation(for:NSPredicate(format:"isEnabled == true"),evaluatedWith:start); waitForExpectations(timeout:120)
        start.tap(); XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout:10))
        app.buttons["Flight tools"].tap(); app.buttons["Enter Coruscant"].tap()
        XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout:10)); app.buttons["Flight tools"].tap()
        revealCityExpansion(app.buttons["Coruscant homes"],in:app); app.buttons["Coruscant homes"].tap()
        let visit = app.buttons["Visit selected estate"]; revealCityExpansion(visit,in:app); visit.tap()
        let land = app.buttons["Land at home"]
        XCTAssertTrue(land.waitForExistence(timeout:10)); land.tap()
        let enter = app.buttons["Enter landed home"]
        XCTAssertTrue(enter.waitForExistence(timeout:40))
        capture(app,name:"Owned home – ship landed on the terrace")
        enter.tap()
        let room = app.descendants(matching:.any).matching(identifier:"Walkable home room").firstMatch
        XCTAssertTrue(room.waitForExistence(timeout:10))
        // Interiors fill the screen instead of being constrained to an iPad form sheet.
        XCTAssertGreaterThan(room.frame.width,app.windows.firstMatch.frame.width*0.8)
        let brisk = app.buttons["Home brisk walking"]
        XCTAssertTrue(brisk.exists); brisk.tap(); XCTAssertEqual(brisk.value as? String,"On")
        let positionReady = XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in (room.value as? String)?.hasPrefix("Room position") == true },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[positionReady],timeout:5),.completed)
        let before = room.value as? String
        let stick = app.descendants(matching:.any).matching(identifier:"Home walking joystick").firstMatch
        stick.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).press(forDuration:0.05,
            thenDragTo:stick.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.18)),withVelocity:.slow,thenHoldForDuration:1)
        let moved = XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in (room.value as? String) != before },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[moved],timeout:5),.completed)
        capture(app,name:"Inside the home – first person walking")
        app.buttons["Arrange entered home"].tap()
        XCTAssertTrue(app.staticTexts["Home room dimensions"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["Home room dimensions"].label.contains("40 × 32"))
        let table = app.buttons["Select furniture holotable"]; revealCityExpansion(table,in:app); table.tap()
        let left = app.buttons["Move furniture left"]; revealCityExpansion(left,in:app); left.tap()
        app.buttons["Rotate furniture"].tap()
        let placement = app.staticTexts["Furniture placement"]
        XCTAssertTrue(placement.label.contains("3.5")); XCTAssertTrue(placement.label.contains("90°"))
        XCTAssertTrue(app.staticTexts["Arrangement notice"].label.contains("saved"))
        let undo = app.buttons["Undo furniture edit"]
        revealCityExpansion(undo,in:app); undo.tap()
        revealCityExpansion(placement,in:app)
        XCTAssertTrue(placement.label.contains("rotation 0°"))
        let redo = app.buttons["Redo furniture edit"]
        revealCityExpansion(redo,in:app); redo.tap()
        revealCityExpansion(placement,in:app)
        XCTAssertTrue(placement.label.contains("90°"))
        capture(app,name:"Room arrangement – moved and rotated holo table")
        app.navigationBars.buttons.element(boundBy:0).tap()
        app.buttons["Leave entered home"].tap()
        XCTAssertTrue(enter.waitForExistence(timeout:10))
        // Returning to the ship must preserve the parked state rather than launching it.
        enter.tap(); XCTAssertTrue(room.waitForExistence(timeout:10))
        app.buttons["Arrange entered home"].tap()
        revealCityExpansion(app.buttons["Select furniture holotable"],in:app); app.buttons["Select furniture holotable"].tap()
        revealCityExpansion(app.staticTexts["Furniture placement"],in:app)
        XCTAssertTrue(app.staticTexts["Furniture placement"].label.contains("3.5"))
        XCTAssertTrue(app.staticTexts["Furniture placement"].label.contains("90°"))
        app.navigationBars.buttons.element(boundBy:0).tap(); app.buttons["Leave entered home"].tap()
        XCTAssertTrue(app.buttons["Depart home"].waitForExistence(timeout:10)); app.buttons["Depart home"].tap()
        let released = XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            !app.staticTexts["Home autopilot status"].exists && app.buttons["Pause flight"].exists
        },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[released],timeout:30),.completed)
        capture(app,name:"Home departure – airborne over the clear avenue")
        app.buttons["Pause flight"].tap()
    }

    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor
    func testFurnitureInteractionsTerraceEditorAndReload() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchEnvironment["STARFLIGHT_HOME_FIXTURE"] = "furnishings"
        app.launchArguments = ["-aircraft","kestrel","-level","freeRoam","-spaceFreeRoam","YES"]
        app.launch()
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout:30))
        expectation(for:NSPredicate(format:"isEnabled == true"),evaluatedWith:start); waitForExpectations(timeout:120)
        start.tap(); XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout:10))
        app.buttons["Flight tools"].tap(); app.buttons["Enter Coruscant"].tap()
        XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout:10)); app.buttons["Flight tools"].tap()
        revealCityExpansion(app.buttons["Coruscant homes"],in:app); app.buttons["Coruscant homes"].tap()
        let visit = app.buttons["Visit selected estate"]; revealCityExpansion(visit,in:app); visit.tap()
        XCTAssertTrue(app.buttons["Land at home"].waitForExistence(timeout:10)); app.buttons["Land at home"].tap()
        XCTAssertTrue(app.buttons["Enter landed home"].waitForExistence(timeout:40)); app.buttons["Enter landed home"].tap()
        let interact = app.buttons["Interact with furniture"]
        XCTAssertTrue(interact.waitForExistence(timeout:10)); XCTAssertEqual(interact.label,"Switch off")
        interact.tap(); XCTAssertEqual(interact.label,"Switch on")
        capture(app,name:"New lamp switched off in furnished room")
        app.buttons["Explore home areas"].tap(); app.buttons["Explore terrace"].tap()
        let seatReady = XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in interact.exists && interact.label == "Sit down" },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[seatReady],timeout:10),.completed)
        interact.tap(); XCTAssertTrue(app.buttons["Stand from furniture"].waitForExistence(timeout:5))
        capture(app,name:"Sitting on the editable skyline terrace")
        app.buttons["Stand from furniture"].tap()
        let stick = app.descendants(matching:.any).matching(identifier:"Home walking joystick").firstMatch
        stick.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).press(forDuration:0.05,
            thenDragTo:stick.coordinate(withNormalizedOffset:CGVector(dx:0.18,dy:0.5)),withVelocity:.slow,thenHoldForDuration:1)
        let lanternReady = XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in interact.exists && interact.label == "Switch off" },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[lanternReady],timeout:5),.completed)
        interact.tap(); XCTAssertEqual(interact.label,"Switch on")
        app.buttons["Arrange entered home"].tap()
        let lantern = app.buttons["Select furniture lantern"]; revealCityExpansion(lantern,in:app); lantern.tap()
        let left = app.buttons["Move furniture left"]; revealCityExpansion(left,in:app); left.tap()
        XCTAssertTrue(app.staticTexts["Furniture placement"].label.contains("10.5"))
        XCTAssertTrue(app.staticTexts["Arrangement notice"].label.contains("saved"))
        capture(app,name:"Outdoor furniture arrangement saved")
        app.navigationBars.buttons.element(boundBy:0).tap()
        app.buttons["Explore home areas"].tap(); app.buttons["Explore room"].tap()
        XCTAssertTrue(interact.waitForExistence(timeout:10)); XCTAssertEqual(interact.label,"Switch on")
        app.buttons["Leave entered home"].tap()
        XCTAssertTrue(app.buttons["Enter landed home"].waitForExistence(timeout:10)); app.buttons["Enter landed home"].tap()
        XCTAssertTrue(interact.waitForExistence(timeout:10)); XCTAssertEqual(interact.label,"Switch on")
        app.buttons["Leave entered home"].tap()
        app.buttons["Pause flight"].tap()
    }

    @MainActor
    func testIntroFitsPhoneSafeAreaInBothLandscapeDirections() {
        let app = XCUIApplication()
        app.launchEnvironment["STARFLIGHT_INTRO_LAYOUT_TEST"] = "1"
        app.launch()
        for orientation: UIDeviceOrientation in [.landscapeLeft, .landscapeRight] {
            XCUIDevice.shared.orientation = orientation
            let title = app.staticTexts["Intro title"]
            let skip = app.buttons["Skip intro"]
            XCTAssertTrue(title.waitForExistence(timeout: 30))
            XCTAssertTrue(skip.exists)
            let bounds = app.windows.firstMatch.frame
            XCTAssertGreaterThanOrEqual(title.frame.minX, bounds.minX + 12)
            XCTAssertLessThanOrEqual(title.frame.maxX, bounds.maxX - 12)
            XCTAssertGreaterThanOrEqual(title.frame.minY, bounds.minY + 8)
            XCTAssertLessThanOrEqual(title.frame.maxY, skip.frame.minY)
            XCTAssertLessThanOrEqual(skip.frame.maxY, bounds.maxY - 8)
            XCTAssertTrue(skip.isHittable)
            capture(app, name: "Phone intro safe area \(orientation.rawValue)")
        }
        app.buttons["Skip intro"].tap()
        XCTAssertTrue(app.buttons["Take flight"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testHandControlsUnavailableWithoutEligiblePhysicalPhone() throws {
#if !targetEnvironment(simulator)
        throw XCTSkip("This restriction check uses the simulator; eligible physical phones offer hand controls.")
#endif
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 30))
        tapHomeAction("Settings", in: app)
        let explanation = app.staticTexts["Hand control unavailable"]
        XCTAssertTrue(explanation.waitForExistence(timeout: 5))
        XCTAssertFalse(app.switches["Hand steering"].exists)
        XCTAssertFalse(app.buttons["Check camera permission"].exists)
        capture(app, name: "Hand control device restriction")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAlternateIconSelectionPersistsAndRestores() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 30))
        tapHomeAction("Settings", in: app)
        let gold = app.buttons["App icon gold"]
        XCTAssertTrue(gold.waitForExistence(timeout: 5))
        #if targetEnvironment(macCatalyst)
        guard gold.isEnabled else { throw XCTSkip("Alternate icons unavailable on Mac Catalyst") }
#else
        XCTAssertTrue(gold.isEnabled, "iPhone and iPad builds must bundle the alternate app icons")
        guard gold.isEnabled else { return }
#endif
        func dismissNotice() {
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            if springboard.alerts.firstMatch.waitForExistence(timeout: 3) {
                springboard.alerts.firstMatch.buttons.firstMatch.tap()
            } else if app.alerts.firstMatch.exists {
                app.alerts.firstMatch.buttons.firstMatch.tap()
            }
        }
        gold.tap()
        dismissNotice()
        let failure = app.staticTexts["App icon error"]
        expectation(for: NSPredicate { _, _ in
            (gold.value as? String)?.lowercased() == "selected" || failure.exists
        }, evaluatedWith: gold)
        waitForExpectations(timeout: 10)
        if failure.exists {
            capture(app, name: "Alternate icon platform error")
            print("Icon change error: \(failure.label)")
#if targetEnvironment(simulator)
            if failure.label.localizedCaseInsensitiveContains("temporarily unavailable") {
                throw XCTSkip("Simulator icon service unavailable: \(failure.label)")
            }
#endif
            XCTFail(failure.label)
            return
        }
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 30))
        tapHomeAction("Settings", in: app)
        XCTAssertEqual((app.buttons["App icon gold"].value as? String)?.lowercased(), "selected")
        let standard = app.buttons["App icon standard"]
        standard.tap()
        dismissNotice()
        expectation(for: NSPredicate { _, _ in
            (standard.value as? String)?.lowercased() == "selected" || failure.exists
        }, evaluatedWith: standard)
        waitForExpectations(timeout: 10)
        if failure.exists {
            capture(app, name: "Restore icon platform error")
            print("Restore icon error: \(failure.label)")
#if targetEnvironment(simulator)
            if failure.label.localizedCaseInsensitiveContains("temporarily unavailable") {
                throw XCTSkip("Simulator restore icon service unavailable: \(failure.label)")
            }
#endif
            XCTFail(failure.label)
        }
    }

    @MainActor
    func testIntensePodRaceControlsAndRestart() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft", "anakinPodracer", "-level", "boontaEve"]
        app.launch()
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout:30))
        expectation(for:NSPredicate(format:"isEnabled == true"),evaluatedWith:start)
        waitForExpectations(timeout:60)
        start.tap()
        let pause = app.buttons["Pause flight"]
        let boost = app.buttons["Hold to boost"]
        XCTAssertTrue(boost.waitForExistence(timeout:10))
        func boostCharge(_ value: String?) -> Int? {
            value?.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }.first
        }
        let initialCharge = boostCharge(boost.value as? String)
        XCTAssertNotNil(initialCharge)
        boost.press(forDuration:0.7)
        // Gates and pads can refill charge during this real hold at extreme speed.
        // Physics tests verify drain; this UI check verifies valid charge and release.
        let releasedValue = boost.value as? String
        let releasedCharge = boostCharge(releasedValue)
        print("Boost hold: \(initialCharge ?? -1)% -> \(releasedValue ?? "unavailable")")
        XCTAssertNotNil(releasedCharge)
        XCTAssertTrue((0...100).contains(releasedCharge ?? -1))
        XCTAssertTrue(releasedValue?.hasPrefix("Ready") == true)
        capture(app,name:"Extreme podrace – boost and speed lines")
        pause.tap()

        // Each control gets a fresh short run. At arcade race speed an unattended
        // racer reaches the first chicane before a long sequence of UI queries ends.
        app.buttons["Restart flight"].tap()
        let skid = app.buttons["Hold to skid"]
        XCTAssertTrue(skid.waitForExistence(timeout:5))
        skid.press(forDuration:0.35)
        XCTAssertEqual(skid.value as? String,"Ready")
        pause.tap()

        app.buttons["Restart flight"].tap()
        let fire = app.buttons["Fire weapons"]
        XCTAssertTrue(fire.waitForExistence(timeout:5))
        XCTAssertEqual(fire.value as? String,"Off")
        fire.tap()
        XCTAssertEqual(fire.value as? String,"Firing")
        capture(app,name:"Intense podrace – rival pack and boost")
        pause.tap()

        app.buttons["Restart flight"].tap()
        XCTAssertTrue(app.buttons["Switch camera"].waitForExistence(timeout:5))
        app.buttons["Switch camera"].tap()
        pause.tap()
        capture(app,name:"Intense podrace – cockpit paused")
        app.buttons["Restart flight"].tap()
        XCTAssertTrue(pause.waitForExistence(timeout:10))
        XCTAssertEqual(app.buttons["Fire weapons"].value as? String,"Off")
        pause.tap()
        capture(app,name:"Intense podrace – clean restart")
    }

    @MainActor
    func testBlenderFalconAndPodRaceScenes() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        for (ship, level) in [("razorCrest", "alpine"), ("millenniumFalcon", "deathStar"), ("voltwingPodracer", "boontaEve")] {
            app.launchArguments = ["-aircraft", ship, "-level", level]
            app.launch()
            let start = app.buttons["Take flight"]
            XCTAssertTrue(start.waitForExistence(timeout: 30))
            expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: start)
            waitForExpectations(timeout: 45)
            start.tap()
            XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout: 10))
            Thread.sleep(forTimeInterval: 2)
            capture(app, name: "Blender – \(ship) – \(level)")
            app.buttons["Pause flight"].tap()
            app.buttons["Restart flight"].tap()
            XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout: 10))
            app.terminate()
        }
    }

    @MainActor
    func testStartPauseSettingsCameraAndRestart() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft", "kestrel", "-level", "alpine"]
        app.launch()
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout: 30))
        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: start)
        waitForExpectations(timeout: 45)
        start.tap()
        XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout: 10))
        capture(app, name: "Alpine Flight – chase camera")
        let fire = app.buttons["Fire weapons"]
        fire.tap()
        XCTAssertEqual(fire.value as? String,"Firing")
        app.buttons["Switch camera"].tap()
        capture(app, name: "Alpine Flight – cockpit camera")
        app.buttons["Pause flight"].tap()
        XCTAssertTrue(app.buttons["Resume flight"].waitForExistence(timeout: 5))
        tapHomeAction("Settings", in: app)
        XCTAssertTrue(app.navigationBars["flight settings"].waitForExistence(timeout: 5))
        let volume = app.sliders["Effects volume"]
        for _ in 0..<6 where !volume.exists { app.swipeUp() }
        XCTAssertTrue(volume.exists)
        volume.adjust(toNormalizedSliderPosition:0.35)
        app.buttons["Done"].tap()
        app.buttons["Resume flight"].tap()
        XCTAssertEqual(app.buttons["Fire weapons"].value as? String,"Off")
        app.buttons["Pause flight"].tap()
        app.buttons["Restart flight"].tap()
        XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout: 5))
        app.buttons["Pause flight"].tap()
        app.buttons["Back to base"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Alpine Flight – start screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testScenicRouteAndFreeRoamPreviews() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        for level in ["canyon","glacier","endor","skylands","volcano","storm","narShaddaa","freeRoam"] {
            app.launchArguments = ["-aircraft","xwing","-level",level,"-spaceFreeRoam","NO"]
            app.launch()
            let start = app.buttons["Take flight"]
            XCTAssertTrue(start.waitForExistence(timeout:30))
            expectation(for:NSPredicate(format:"isEnabled == true"),evaluatedWith:start)
            waitForExpectations(timeout:90)
            start.tap()
            XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout:10))
            Thread.sleep(forTimeInterval:1)
            capture(app,name:"Scenic region – " + level)
            app.buttons["Pause flight"].tap()
            XCTAssertTrue(app.buttons["Resume flight"].waitForExistence(timeout:5))
            app.terminate()
        }
    }

    @MainActor
    func testFinalTerrainShadingAndSpaceBackdropPreviews() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        for level in ["freeRoam","canyon","deathStar","narShaddaa"] {
            app.launchArguments = ["-aircraft","millenniumFalcon","-level",level,"-spaceFreeRoam","NO"]
            app.launch()
            let start = app.buttons["Take flight"]
            XCTAssertTrue(start.waitForExistence(timeout:30))
            expectation(for:NSPredicate(format:"isEnabled == true"),evaluatedWith:start)
            waitForExpectations(timeout:90)
            start.tap()
            XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout:10))
            Thread.sleep(forTimeInterval:1)
            capture(app,name:"Final scenic shading – " + level)
            app.terminate()
        }
    }

    @MainActor
    func testPilotLogbookGraphsAndPauseResumeSaveOneSession() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchEnvironment["STARFLIGHT_PILOT_FIXTURE"] = "sample"
        app.launchArguments = ["-aircraft","kestrel","-level","freeRoam","-spaceFreeRoam","YES"]
        app.launch()
        XCTAssertTrue(app.buttons["Pilot logbook"].waitForExistence(timeout:30))
        tapHomeAction("Pilot logbook", in: app)
        XCTAssertTrue(app.staticTexts["Pilot career totals"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["Pilot career totals"].label.contains("120 review flights"))
        capture(app,name:"Pilot achievement collection")
        app.segmentedControls["Pilot section"].buttons["Pilot rank"].tap()
        XCTAssertTrue(app.staticTexts["Official pilot rank"].waitForExistence(timeout:5))
        XCTAssertEqual(app.staticTexts["Official pilot rank"].label,"Flight legend")
        app.segmentedControls["Pilot section"].buttons["Progress graph"].tap()
        for name in ["Last 30 days","Calendar month","Calendar year"] {
            app.segmentedControls["Pilot graph period"].buttons[name].tap()
            XCTAssertTrue(app.staticTexts["Pilot chart title"].exists)
            capture(app,name:"Pilot performance "+name)
        }
        app.buttons["Previous graph period"].tap()
        XCTAssertTrue(app.staticTexts["No flights in this period"].waitForExistence(timeout:5))
        app.buttons["Today"].tap()
        app.buttons["Pilot logbook done"].tap()
        let start = app.buttons["Take flight"]
        expectation(for:NSPredicate(format:"isEnabled == true"),evaluatedWith:start)
        waitForExpectations(timeout:90)
        start.tap()
        XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout:10))
        app.buttons["Pause flight"].tap()
        tapHomeAction("Pilot logbook", in: app)
        XCTAssertTrue(app.staticTexts["Pilot saved flights"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["Pilot saved flights"].label.contains("120 sessions"))
        app.buttons["Pilot logbook done"].tap()
        app.buttons["Resume flight"].tap()
        app.buttons["Pause flight"].tap()
        app.buttons["Back to base"].tap()
        tapHomeAction("Pilot logbook", in: app)
        XCTAssertTrue(app.staticTexts["Pilot saved flights"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["Pilot saved flights"].label.contains("121 sessions"))
        app.terminate(); app.launchEnvironment.removeValue(forKey:"STARFLIGHT_PILOT_FIXTURE")
        app.launch()
        XCTAssertTrue(app.buttons["Pilot logbook"].waitForExistence(timeout:30))
        tapHomeAction("Pilot logbook", in: app)
        XCTAssertTrue(app.staticTexts["Pilot saved flights"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["Pilot saved flights"].label.contains("121 sessions"))
        app.buttons["Pilot logbook done"].tap()
    }

    @MainActor
    func testSpaceMapSelectsPlanetAndResumesFlight() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft","kestrel","-level","freeRoam","-spaceFreeRoam","YES"]
        app.launch()
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout:30))
        expectation(for:NSPredicate(format:"isEnabled == true"),evaluatedWith:start)
        waitForExpectations(timeout:90)
        start.tap()
        XCTAssertTrue(app.buttons["Space map"].waitForExistence(timeout:10))
        app.buttons["Space map"].tap()
        XCTAssertTrue(app.buttons["Map Endor"].waitForExistence(timeout:5))
        for name in ["Tatooine","Hoth","Endor","Coruscant"] { XCTAssertTrue(app.buttons["Map "+name].exists) }
        app.buttons["Map Endor"].tap()
        XCTAssertEqual(app.buttons["Map Endor"].value as? String,"Selected")
        XCTAssertTrue(app.staticTexts["Map destination details"].exists)
        XCTAssertTrue(app.descendants(matching:.any).matching(identifier:"Map course guidance").firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Orbital map scale"].exists)
        revealCityExpansion(app.buttons["Follow map course"],in:app)
        capture(app,name:"Orbital map with planet locations")
        app.buttons["Follow map course"].tap()
        XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout:5))
        app.buttons["Flight tools"].tap()
        XCTAssertTrue((app.buttons["Navigate to Endor"].value as? String)?.contains("Selected") == true)
        app.buttons["Resume"].tap()
        app.buttons["Pause flight"].tap()
    }

    @MainActor
    func testCityCareerContractBrowsersAndMap() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft","kestrel","-level","freeRoam","-spaceFreeRoam","YES"]
        app.launch()
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout:30))
        expectation(for:NSPredicate(format:"isEnabled == true"),evaluatedWith:start)
        waitForExpectations(timeout:90); start.tap()
        let tools = app.buttons["Flight tools"]
        XCTAssertTrue(tools.waitForExistence(timeout:10)); tools.tap()
        app.buttons["Enter Coruscant"].tap()
        XCTAssertTrue(tools.waitForExistence(timeout:10)); tools.tap()
        let cityMap = app.buttons["Coruscant city map"]
        XCTAssertTrue(cityMap.waitForExistence(timeout:5)); cityMap.tap()
        XCTAssertTrue(app.buttons["City map station spaceport"].waitForExistence(timeout:10))
        for station in ["spaceport","market","senate","industrial","medical"] {
            XCTAssertTrue(app.buttons["City map station " + station].exists)
        }
        app.buttons["City map station medical"].tap()
        XCTAssertTrue(app.staticTexts["City map station details"].label.contains("180 m"))
        capture(app,name:"Coruscant career – map with real skyports and building footprints")
        app.buttons["City map done"].tap()
        app.buttons["Coruscant jobs"].tap()
        XCTAssertTrue(app.descendants(matching:.any)["City career summary"].firstMatch.waitForExistence(timeout:5))
        app.buttons["Open city career"].tap()
        XCTAssertTrue(app.staticTexts["Recent completed work"].waitForExistence(timeout:5))
        capture(app,name:"Coruscant career – saved licence and work history")
        app.navigationBars.buttons.element(boundBy:0).tap()
        let board = app.scrollViews["City jobs scroll"]
        func reveal(_ element:XCUIElement, in scroll:XCUIElement) {
            for _ in 0..<10 {
                if element.exists && scroll.frame.insetBy(dx:5,dy:20).contains(element.frame) { return }
                scroll.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.78)).press(forDuration:0.05,thenDragTo:scroll.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.32)))
            }
            XCTAssertTrue(element.exists)
        }
        let catalogs:[(String,[String])] = [
            ("shuttle",["shuttleShift","spaceportLink","senateCircuit"]),
            ("courier",["courierRun","fragileTechnology","medicalSupplies"]),
            ("rescue",["emergencyTransfer","clinicEvacuation","senateRescue"]),
            ("patrol",["districtPatrol","trafficSurvey","deepScan"])
        ]
        for (kind,contracts) in catalogs {
            let browse = app.buttons["Browse city contracts " + kind]
            reveal(browse,in:board); browse.tap()
            for contract in contracts { XCTAssertTrue(app.buttons["Preview city contract " + contract].exists,contract) }
            app.buttons["Preview city contract " + contracts[1]].tap()
            let scroll = app.scrollViews["City contracts scroll"]
            let accept = app.buttons["Accept selected city contract"]
            reveal(accept,in:scroll)
            if app.staticTexts["City contract locked"].exists { XCTAssertFalse(accept.isEnabled,kind) }
            else { XCTAssertTrue(accept.isEnabled,kind) }
            XCTAssertTrue(app.staticTexts["City contract route"].exists)
            capture(app,name:"Coruscant career – " + kind + " specialist route")
            app.navigationBars.buttons.element(boundBy:0).tap()
        }
        app.buttons["City jobs done"].tap()
        app.buttons["Resume"].tap(); app.buttons["Pause flight"].tap()
    }

    @MainActor
    func testSpecialistContractAcceptsAndFliesWithPassengerFeedback() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft","kestrel","-level","freeRoam","-spaceFreeRoam","YES"]
        app.launch()
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout:30))
        expectation(for:NSPredicate(format:"isEnabled == true"),evaluatedWith:start)
        waitForExpectations(timeout:90); start.tap()
        let tools = app.buttons["Flight tools"]
        XCTAssertTrue(tools.waitForExistence(timeout:10)); tools.tap()
        app.buttons["Enter Coruscant"].tap()
        XCTAssertTrue(tools.waitForExistence(timeout:10)); tools.tap()
        app.buttons["Coruscant jobs"].tap()
        let board = app.scrollViews["City jobs scroll"]
        let browse = app.buttons["Browse city contracts shuttle"]
        for _ in 0..<6 {
            if browse.isHittable && board.frame.contains(browse.frame) { break }
            board.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.68)).press(forDuration:0.05,thenDragTo:board.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.44)))
        }
        browse.tap()
        app.buttons["Preview city contract spaceportLink"].tap()
        let accept = app.buttons["Accept selected city contract"]
        let scroll = app.scrollViews["City contracts scroll"]
        for _ in 0..<8 {
            if accept.isHittable && scroll.frame.contains(accept.frame) { break }
            scroll.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.70)).press(forDuration:0.05,thenDragTo:scroll.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.40)))
        }
        XCTAssertTrue(accept.isEnabled); accept.tap()
        XCTAssertTrue(tools.waitForExistence(timeout:10),"Accept and fly must close the whole planner and resume")
        let dock = app.buttons["Dock at city skyport"]
        XCTAssertTrue(dock.waitForExistence(timeout:35)); dock.tap()
        let depart = app.buttons["Depart city skyport"]
        XCTAssertTrue(depart.waitForExistence(timeout:25))
        let condition = app.staticTexts["City flight condition"]
        XCTAssertTrue(condition.label.contains("Passenger comfort 100%"))
        capture(app,name:"Coruscant career – specialist passenger aboard and comfort feedback")
        tools.tap(); app.buttons["Coruscant city map"].tap()
        XCTAssertTrue(app.buttons["Show city job destination"].waitForExistence(timeout:5))
        app.buttons["Show city job destination"].tap()
        XCTAssertEqual(app.buttons["City map station market"].value as? String,"Next job stop")
        capture(app,name:"Coruscant career – active two-stop shuttle route")
        app.buttons["City map done"].tap()
        app.buttons["Coruscant jobs"].tap()
        app.buttons["Cancel city job"].tap()
        app.buttons["City jobs done"].tap(); app.buttons["Resume"].tap(); app.buttons["Pause flight"].tap()
    }

    @MainActor
    func testCoruscantJobsBoardDockingAndCancellation() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft", "kestrel", "-level", "freeRoam", "-spaceFreeRoam", "YES"]
        app.launch()
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout: 30))
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: start)
        waitForExpectations(timeout: 90)
        start.tap()

        let tools = app.buttons["Flight tools"]
        XCTAssertTrue(tools.waitForExistence(timeout: 10))
        tools.tap()
        let enter = app.buttons["Enter Coruscant"]
        XCTAssertTrue(enter.waitForExistence(timeout: 5))
        enter.tap()
        XCTAssertTrue(tools.waitForExistence(timeout: 15))
        tools.tap()
        let board = app.buttons["Coruscant jobs"]
        XCTAssertTrue(board.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Flight controls tutorial"].exists)
        board.tap()
        let jobScroll = app.scrollViews["City jobs scroll"]
        XCTAssertTrue(jobScroll.waitForExistence(timeout: 5))
        func revealJobButton(_ button: XCUIElement, towardTop: Bool = false) {
            for _ in 0..<10 {
                let viewport = jobScroll.frame.insetBy(dx: 8, dy: 24)
                if button.exists, button.isHittable, viewport.contains(button.frame) { return }
                // Whole-app swipes can begin on the modal navigation bar. Keep
                // both ends inside the actual board's scrolling content instead.
                let startY = towardTop ? 0.35 : 0.78
                let endY = towardTop ? 0.78 : 0.35
                jobScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                    .press(forDuration: 0.05, thenDragTo: jobScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY)))
            }
            XCTAssertTrue(button.isHittable, "Job button was not reachable: \(button.identifier)")
        }
        capture(app, name: "Coruscant jobs – shuttle and courier cards")

        for (kind, reward) in [("shuttle", 120), ("courier", 100), ("rescue", 150), ("patrol", 80)] {
            let accept = app.buttons["Accept city job " + kind]
            revealJobButton(accept)
            XCTAssertTrue(accept.exists, kind)
            XCTAssertTrue(accept.isEnabled, kind)
            XCTAssertTrue(app.staticTexts["\(reward) credits"].exists, kind)
        }
        capture(app, name: "Coruscant jobs – rescue and patrol cards")
        let shuttle = app.buttons["Accept city job shuttle"]
        revealJobButton(shuttle, towardTop: true)
        XCTAssertTrue(shuttle.isHittable)
        shuttle.tap()
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 5))
        app.buttons["Resume"].tap()

        // Fly the real approach from arrival to the first station, then let the
        // normal docking assist align the ship and complete passenger boarding.
        let dock = app.buttons["Dock at city skyport"]
        XCTAssertTrue(dock.waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["Flight attitude feedback"].exists)
        XCTAssertFalse(app.staticTexts["Altitude above sea level"].exists,"City jobs show essential instruments; full details remain in Flight tools")
        app.buttons["Fire weapons"].tap()
        let feedback = app.descendants(matching:.any)["Weapon feedback"].firstMatch
        XCTAssertTrue(feedback.waitForExistence(timeout:3))
        capture(app,name:"Coruscant approach – one objective, visible lasers and brighter city")
        app.buttons["Fire weapons"].tap()
        dock.tap()
        let depart = app.buttons["Depart city skyport"]
        XCTAssertTrue(depart.waitForExistence(timeout: 25))
        let notice = app.staticTexts["City job notice"]
        XCTAssertTrue(notice.exists)
        XCTAssertTrue(notice.label.contains("Stop complete"))
        capture(app, name: "Coruscant jobs – boarded passenger at neon skyport")
        depart.tap()
        tools.tap()
        board.tap()
        let target = app.staticTexts["City job target"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertTrue(target.label.contains("Neon Market"))
        XCTAssertFalse(app.buttons["Accept city job courier"].isEnabled)
        capture(app, name: "Coruscant jobs – passenger delivery destination")
        app.buttons["Cancel city job"].tap()
        let active = app.descendants(matching: .any)["Active city job"].firstMatch
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: active)
        waitForExpectations(timeout: 5)

        // Accepting returns to Flight tools without resuming: time must remain
        // frozen while the player reviews the board again.
        let courier = app.buttons["Accept city job courier"]
        revealJobButton(courier)
        XCTAssertTrue(courier.isEnabled)
        courier.tap()
        board.tap()
        let time = app.staticTexts["City job time remaining"]
        XCTAssertTrue(time.waitForExistence(timeout: 5))
        XCTAssertEqual(time.label, "Time left 5:00")
        Thread.sleep(forTimeInterval: 2)
        XCTAssertEqual(time.label, "Time left 5:00")
        capture(app, name: "Coruscant jobs – courier timer paused on board")
        app.buttons["Cancel city job"].tap()
        app.buttons["City jobs done"].tap()
        app.buttons["Resume"].tap()
        app.buttons["Pause flight"].tap()
    }

    @MainActor
    func testPlanetNeonAndMountainSurfacePreviews() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft", "kestrel", "-level", "freeRoam", "-spaceFreeRoam", "YES"]
        app.launch()
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout:30))
        expectation(for:NSPredicate(format:"isEnabled == true"),evaluatedWith:start)
        waitForExpectations(timeout:90)
        start.tap()
        XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout:10))
        capture(app,name:"Space free roam nebula and planets")
        for planet in ["Coruscant","Tatooine","Hoth","Endor"] {
            XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout:10))
            app.buttons["Flight tools"].tap()
            let enter = app.buttons["Enter " + planet]
            XCTAssertTrue(enter.waitForExistence(timeout:5))
            enter.tap()
            XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout:5))
            Thread.sleep(forTimeInterval:1)
            capture(app,name:planet + " neon and mountain surface")
            app.buttons["Flight tools"].tap()
            XCTAssertTrue(app.staticTexts[planet + " surface"].waitForExistence(timeout:5))
            app.buttons["Return to orbit"].tap()
        }
        app.buttons["Pause flight"].tap()
    }

    @MainActor
    func testSellingSpareBlueprintsAndVersion() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchEnvironment["STARFLIGHT_ECONOMY_FIXTURE"] = "spares"
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout:30))
        XCTAssertTrue(app.staticTexts["Home version"].exists)
        tapHomeAction("Settings", in: app)
        XCTAssertTrue(app.descendants(matching:.any)["App version"].firstMatch.waitForExistence(timeout:5))
        app.buttons["Done"].tap()
        tapHomeAction("Shop", in: app)
        app.segmentedControls["Shop section"].buttons["Blueprints"].tap()
        for (ship,balance) in [("bWing","100.00"),("imperialShuttle","400.00"),("tieDefender","2200.00")] {
            let sell = app.buttons["Sell extras " + ship]
            let scroll = app.scrollViews.firstMatch
            for _ in 0..<24 {
                let bounds = scroll.frame, frame = sell.frame
                if sell.isHittable && frame.minY > bounds.minY+40 && frame.maxY < bounds.maxY-40 { break }
                let down = frame.minY < bounds.minY+40
                scroll.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.55)).press(forDuration:0.05,thenDragTo:scroll.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:down ? 0.72 : 0.38)))
            }
            XCTAssertTrue(sell.isHittable)
            XCTAssertTrue(sell.isEnabled)
            sell.tap()
            expectation(for:NSPredicate(format:"isEnabled == false"),evaluatedWith:sell)
            waitForExpectations(timeout:5)
            app.buttons["Shop done"].tap()
            tapHomeAction("Shop", in: app)
            XCTAssertTrue(app.staticTexts["Shop credits"].label.contains(balance))
            app.segmentedControls["Shop section"].buttons["Blueprints"].tap()
        }
        capture(app,name:"Sold spare blueprints")
        app.terminate()
        app.launchEnvironment.removeValue(forKey:"STARFLIGHT_ECONOMY_FIXTURE")
        app.launch()
        XCTAssertTrue(app.buttons["Shop"].waitForExistence(timeout:30))
        tapHomeAction("Shop", in: app)
        XCTAssertTrue(app.staticTexts["Shop credits"].label.contains("2200.00"))
        app.segmentedControls["Shop section"].buttons["Blueprints"].tap()
        XCTAssertFalse(app.buttons["Sell extras bWing"].isEnabled)
        XCTAssertTrue(app.buttons["Fly B-wing"].exists)
    }

    @MainActor
    func testShopPurchasesDailyWheelAndSavedWallet() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchEnvironment["STARFLIGHT_ECONOMY_FIXTURE"] = "funded"
        app.launchArguments = ["-aircraft","kestrel","-level","freeRoam","-spaceFreeRoam","NO"]
        app.launch()
        XCTAssertTrue(app.buttons["Shop"].waitForExistence(timeout:30))
        tapHomeAction("Shop", in: app)
        XCTAssertTrue(app.buttons["Buy scout pack"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["Shop credits"].label.contains("5000.00"))
        app.buttons["Buy scout pack"].tap()
        let reveal = app.buttons["Reveal next blueprint"]
        XCTAssertTrue(reveal.waitForExistence(timeout:5))
        for card in 0..<3 {
            XCTAssertEqual(reveal.label,"Reveal blueprint")
            reveal.tap()
            XCTAssertTrue(app.descendants(matching:.any)["Blueprint ship preview"].firstMatch.waitForExistence(timeout:5))
            if card == 0 { capture(app,name:"Animated blueprint reveal and ship model") }
            reveal.tap()
        }
        XCTAssertTrue(app.staticTexts["Shop credits"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["Shop credits"].label.contains("4600.00"))
        app.segmentedControls["Shop section"].buttons["Blueprints"].tap()
        XCTAssertTrue(app.staticTexts["Blueprint collection"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["Fly TIE Defender"].exists)
        capture(app,name:"Blueprint collection and rarities")
        let preview = app.buttons["Preview B-wing"]
        if !preview.isHittable { app.swipeUp() }
        XCTAssertTrue(preview.waitForExistence(timeout:5)); preview.tap()
        XCTAssertTrue(app.descendants(matching:.any)["Blueprint ship preview"].firstMatch.waitForExistence(timeout:5))
        // Exercise the independent mesh viewer before capturing its rendered frame.
        app.descendants(matching:.any)["Blueprint ship preview"].firstMatch.swipeLeft()
        capture(app,name:"Locked ship 3D preview")
        app.buttons["Preview done"].tap()
        for name in ["Imperial Shuttle", "TIE Defender"] {
            let button = app.buttons["Preview " + name]
            for _ in 0..<5 { if button.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(button.isHittable,name); button.tap()
            let model = app.descendants(matching:.any)["Blueprint ship preview"].firstMatch
            XCTAssertTrue(model.waitForExistence(timeout:5))
            model.swipeLeft()
            capture(app,name:name + " Blender model preview")
            app.buttons["Preview done"].tap()
        }
        for _ in 0..<5 { if app.segmentedControls["Shop section"].isHittable { break }; app.swipeDown() }
        app.segmentedControls["Shop section"].buttons["Daily spin"].tap()
        let spin = app.buttons["Claim daily spin"]
        XCTAssertTrue(spin.waitForExistence(timeout:5)); XCTAssertTrue(spin.isEnabled)
        spin.tap()
        expectation(for:NSPredicate(format:"isEnabled == false"),evaluatedWith:spin)
        waitForExpectations(timeout:5)
        capture(app,name:"Daily supply wheel")
        app.terminate(); app.launchEnvironment.removeValue(forKey:"STARFLIGHT_ECONOMY_FIXTURE")
        app.launch(); XCTAssertTrue(app.buttons["Shop"].waitForExistence(timeout:30))
        tapHomeAction("Shop", in: app)
        app.segmentedControls["Shop section"].buttons["Daily spin"].tap()
        XCTAssertTrue(app.buttons["Claim daily spin"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["Claim daily spin"].isEnabled)
        XCTAssertTrue(app.staticTexts["Last daily prize"].exists)
        app.buttons["Shop done"].tap()
    }

    @MainActor
    func testMobileHUDToolsPauseTransferAndResume() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft", "kestrel", "-level", "freeRoam", "-spaceFreeRoam", "NO"]
        app.launch()
        let preview = app.otherElements["Hangar preview"]
        if preview.waitForExistence(timeout: 10) { preview.pinch(withScale: 1.4, velocity: 1) }
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout: 30))
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: start)
        waitForExpectations(timeout: 90)
        start.tap()
        XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["Flight instruments"].firstMatch.exists)
        for label in ["Height above ground", "Climb or descent rate", "Throttle"] {
            XCTAssertTrue(app.descendants(matching: .any)[label].firstMatch.exists, label)
        }
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "NAV COMPUTER")).firstMatch.exists)
        XCTAssertTrue(app.buttons["Fire weapons"].exists)
        XCTAssertTrue(app.buttons["Switch camera"].exists)
        capture(app, name: "Uncluttered iOS HUD – landscape")
        app.buttons["Flight tools"].tap()
        XCTAssertTrue(app.staticTexts["Flight paused while you use these tools."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Navigate landing"].exists)
        XCTAssertFalse(app.buttons["Navigate missions"].exists)
        app.buttons["Space free roam"].tap()
        app.buttons["Resume"].tap()
        XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any)["Height above ground"].firstMatch.value as? String, "—")
        let ground = app.descendants(matching: .any)["Height above ground"].firstMatch
        let speed = app.descendants(matching: .any)["Airspeed"].firstMatch
        XCTAssertEqual(ground.frame.midY, speed.frame.midY, accuracy: 2)
        app.buttons["Flight tools"].tap()
        XCTAssertTrue(app.buttons["Navigate to Hoth"].waitForExistence(timeout: 5))
        app.buttons["Navigate to Hoth"].tap()
        XCTAssertTrue((app.buttons["Navigate to Hoth"].value as? String)?.contains("Selected") == true)
        XCTAssertFalse((app.buttons["Navigate to Tatooine"].value as? String)?.contains("Selected") == true)
        XCTAssertTrue(app.buttons["Navigate to Coruscant"].exists)
        app.buttons["Navigate to Coruscant"].tap()
        XCTAssertTrue((app.buttons["Navigate to Coruscant"].value as? String)?.contains("Selected") == true)
        app.buttons["Enter Coruscant"].tap()
        XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout: 5))
        capture(app, name: "Coruscant expanded city and lights")
        app.buttons["Flight tools"].tap()
        XCTAssertTrue(app.staticTexts["Coruscant surface"].waitForExistence(timeout: 5))
        app.buttons["Return to orbit"].tap()
        XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Coruscant")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["Switch camera"].tap()
        XCTAssertTrue(app.buttons["Start droid voice control"].waitForExistence(timeout: 5))
        capture(app, name: "Uncluttered iOS cockpit – landscape")
        XCUIDevice.shared.orientation = .portrait
        capture(app, name: "Uncluttered iPad cockpit – portrait")
        app.buttons["Pause flight"].tap()
    }

    @MainActor
    func testFreeRoamTransferAndLabelledFireButton() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft", "kestrel", "-level", "freeRoam", "-spaceFreeRoam", "NO"]
        app.launch()
        XCTAssertTrue(app.otherElements["Hangar preview"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["Zoom in ship"].exists)
        XCTAssertFalse(app.buttons["Zoom out ship"].exists)
        let start = app.buttons["Take flight"]
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: start)
        waitForExpectations(timeout: 90)
        start.tap()
        let fire = app.buttons["Fire weapons"]
        XCTAssertTrue(fire.waitForExistence(timeout: 10))
        fire.tap()
        XCTAssertEqual(fire.value as? String, "Firing")
        fire.tap()
        XCTAssertEqual(fire.value as? String, "Off")
        app.buttons["Flight tools"].tap()
        XCTAssertTrue(app.buttons["Go to hyperspace portals"].waitForExistence(timeout: 5))
        app.buttons["Go to hyperspace portals"].tap()
        XCTAssertFalse(app.buttons["Navigate landing"].exists)
        XCTAssertFalse(app.buttons["Navigate missions"].exists)
        app.buttons["Resume"].tap()
        capture(app, name: "Portal transfer and labelled controls")
        app.buttons["Pause flight"].tap()
    }

    @MainActor
    func testWidgetLinksAndInteractiveHangar() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Choose Flight planner"].waitForExistence(timeout: 30))
        app.open(URL(string: "starflight://planner")!)
        XCTAssertTrue(app.buttons["Planner done"].waitForExistence(timeout: 10))
        app.buttons["Planner done"].tap()
        app.open(URL(string: "starflight://space")!)
        let selection = app.staticTexts["Current flight selection"]
        expectation(for: NSPredicate { _, _ in selection.exists && selection.label.localizedCaseInsensitiveContains("space") }, evaluatedWith: selection)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.buttons["Take flight"].exists)
        let inspect = app.buttons["Inspect hangar"]
        if !inspect.isHittable { app.swipeUp() }
        inspect.tap()
        XCTAssertTrue(app.buttons["Close interactive hangar"].waitForExistence(timeout: 10))
        let preview = app.otherElements["Hangar preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        func reading(_ key: String) -> Float {
            let text = preview.value as? String ?? ""
            let component = text.split(separator: ";").first { $0.hasPrefix(key + "=") }
            return component.flatMap { Float($0.dropFirst(key.count + 1)) } ?? .nan
        }
        expectation(for: NSPredicate { _, _ in reading("yaw").isFinite }, evaluatedWith: preview)
        waitForExpectations(timeout: 5)
        let yaw = reading("yaw")
        let middle = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        middle.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.55)))
        expectation(for: NSPredicate { _, _ in abs(reading("yaw") - yaw) > 0.2 }, evaluatedWith: preview)
        waitForExpectations(timeout: 5)
        let distance = reading("distance")
        preview.pinch(withScale: 1.5, velocity: 1)
        expectation(for: NSPredicate { _, _ in reading("distance") < distance - 1 }, evaluatedWith: preview)
        waitForExpectations(timeout: 5)
        capture(app, name: "Interactive ship hangar")
        app.buttons["Close interactive hangar"].tap()
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: start)
        waitForExpectations(timeout: 90)
        start.tap()
        XCTAssertTrue(app.buttons["Flight tools"].waitForExistence(timeout: 10))
        // XCUIApplication.open relaunches the app. Cold shortcut routing is tested above;
        // preserve this running session for a system-delivered URL check instead.
        app.buttons["Pause flight"].tap()
        XCTAssertTrue(app.buttons["Resume flight"].waitForExistence(timeout: 5))
        capture(app, name: "Flight session retained after hangar inspection")
    }

    @MainActor
    func testCompactHomeActionsRemainReachable() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()
        let skip = app.buttons["Skip intro"]
        if skip.waitForExistence(timeout: 3) { skip.tap() }
        XCTAssertTrue(app.buttons["Choose Flight planner"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["Choose Flight planner"].isHittable)
        for identifier in ["Choose Free roam", "Choose Space free roam"] {
            let mode = app.buttons[identifier]
            XCTAssertTrue(mode.isHittable)
            mode.tap()
        }
        let start = app.buttons["Take flight"]
        if !start.isHittable { app.swipeUp() }
        XCTAssertTrue(start.isHittable)
        let settings = app.buttons["Settings"]
        if !settings.isHittable { app.swipeUp() }
        XCTAssertTrue(settings.isHittable)
        capture(app, name: "Compact landscape labelled actions")
        settings.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        let invert = app.switches["Invert pitch"]
        XCTAssertTrue(invert.waitForExistence(timeout: 5))
        for _ in 0..<3 {
            if invert.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(invert.isHittable)
        capture(app, name: "Settings controls before switch interaction")
        let original = invert.value as? String
        invert.tap()
        expectation(for: NSPredicate(format: "value != %@", original ?? "0"), evaluatedWith: invert)
        waitForExpectations(timeout: 3)
        XCTAssertNotEqual(invert.value as? String, original)
        capture(app, name: "Settings coloured switch and readable controls")
        invert.tap()
        expectation(for: NSPredicate(format: "value == %@", original ?? "0"), evaluatedWith: invert)
        waitForExpectations(timeout: 3)
        XCTAssertEqual(invert.value as? String, original)
        app.buttons["Done"].tap()
    }

    @MainActor
    func testPlannerCategoriesAndSelectionWithoutSearch() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft", "kestrel", "-level", "freeRoam", "-spaceFreeRoam", "NO"]
        app.launch()
        let skip = app.buttons["Skip intro"]
        if skip.waitForExistence(timeout: 3) { skip.tap() }
        XCTAssertTrue(app.buttons["Choose Flight planner"].waitForExistence(timeout: 30))
        tapHomeAction("Choose Flight planner", in: app)
        XCTAssertFalse(app.searchFields.firstMatch.exists)
        func selectTab(_ title: String) {
            let button = app.segmentedControls.buttons.matching(NSPredicate(format: "label ==[c] %@", title)).firstMatch
            for _ in 0..<4 {
                if button.isHittable { break }
                app.swipeDown()
            }
            XCTAssertTrue(button.isHittable)
            button.tap()
            XCTAssertFalse(app.searchFields.firstMatch.exists)
        }
        selectTab("Droids")
        let chopper = app.buttons["droid-chopper"]
        for _ in 0..<6 {
            if chopper.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(chopper.isHittable)
        chopper.tap()
        expectation(for: NSPredicate(format: "value == %@", "Selected"), evaluatedWith: chopper)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.otherElements["Planner selection summary"].exists || app.staticTexts["Planner selection summary"].exists)
        capture(app, name: "Planner categories without search")
        selectTab("Levels")
        XCTAssertGreaterThan(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "level-")).count, 0)
        selectTab("Aircraft")
        XCTAssertGreaterThan(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "aircraft-")).count, 0)
        app.buttons["Planner done"].tap()
        XCTAssertTrue(app.buttons["Take flight"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testUnifiedPlannerAndFreeRoamConsole() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft", "kestrel", "-level", "freeRoam", "-spaceFreeRoam", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["Choose Flight planner"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["Choose Aircraft"].exists)
        XCTAssertFalse(app.buttons["Choose Droids"].exists)
        XCTAssertFalse(app.buttons["Choose Levels"].exists)
        tapHomeAction("Choose Flight planner", in: app)
        for tab in ["Droids", "Levels", "Aircraft"] {
            let button = app.segmentedControls.buttons.matching(NSPredicate(format: "label ==[c] %@", tab)).firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
            capture(app, name: "Text-only planner – \(tab)")
        }
        app.buttons["Planner done"].tap()
        let start = app.buttons["Take flight"]
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: start)
        waitForExpectations(timeout: 90)
        start.tap()
        XCTAssertTrue(app.staticTexts["FREE ROAM"].waitForExistence(timeout: 10))
        app.buttons["Flight tools"].tap()
        XCTAssertTrue(app.buttons["Go to hyperspace portals"].waitForExistence(timeout: 5))
        app.buttons["Go to hyperspace portals"].tap()
        app.buttons["Resume"].tap()
        app.buttons["Switch camera"].tap()
        XCTAssertTrue(app.buttons["Start droid voice control"].waitForExistence(timeout: 5))
        capture(app, name: "Free roam – navigation and cockpit systems")
        app.buttons["Pause flight"].tap()
        XCTAssertTrue(app.buttons["Back to base"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSelectDroidAndOpenCockpitOptic() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft", "kestrel", "-level", "alpine"]
        app.launch()
        XCTAssertTrue(app.buttons["Choose Flight planner"].waitForExistence(timeout: 30))
        tapHomeAction("Choose Flight planner", in: app)
        app.segmentedControls.buttons.matching(NSPredicate(format: "label ==[c] %@", "Droids")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Flight planner"].waitForExistence(timeout: 5))
        tapCard("droid-chopper", in: app)
        app.buttons["Planner done"].tap()
        XCTAssertTrue(app.staticTexts["DROID CREW · Chopper"].waitForExistence(timeout: 5))
        let start = app.buttons["Take flight"]
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: start)
        waitForExpectations(timeout: 60)
        start.tap()
        XCTAssertTrue(app.buttons["Switch camera"].waitForExistence(timeout: 10))
        app.buttons["Switch camera"].tap()
        XCTAssertTrue(app.buttons["Start droid voice control"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Start droid voice control"].exists)
        capture(app, name: "Chopper cockpit optic")
        let microphone = app.buttons["Start droid voice control"]
        XCTAssertTrue(microphone.isHittable)
        microphone.tap()
        let status = app.staticTexts["Droid voice status"]
        expectation(for: NSPredicate(format: "label != 'VOICE OFF'"), evaluatedWith: status)
        waitForExpectations(timeout: 5)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testTerrainCrashCanRestart() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft", "kestrel", "-level", "alpine"]
        app.launch()
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout: 30))
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: start)
        waitForExpectations(timeout: 45)
        start.tap()
        let joystick = app.descendants(matching: .any).matching(identifier: "Flight joystick").firstMatch
        XCTAssertTrue(joystick.waitForExistence(timeout: 10))
        let center = joystick.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let up = joystick.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
        center.press(forDuration: 0.1, thenDragTo: up, withVelocity: .slow, thenHoldForDuration: 22)
        XCTAssertTrue(app.buttons["Fly again"].waitForExistence(timeout: 10))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Alpine Flight – terrain impact"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["Fly again"].tap()
        XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSelectAndFlyEveryAircraftAndLevel() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft", "kestrel", "-level", "alpine"]
        app.launch()
        XCTAssertTrue(app.buttons["Choose Flight planner"].waitForExistence(timeout: 30))
        let selections = [("kestrel", "alpine", "T-47 Snowspeeder", "Hoth: Echo Ridge"),
                          ("meridian", "canyon", "Rebel U-wing", "Tatooine: Beggar’s Canyon"),
                          ("falcon", "glacier", "ARC-170 Starfighter", "Jakku: Wreckage Run"),
                          ("atlas", "storm", "LAAT/i Gunship", "Exegol: Sith Storm"),
                          ("xwing", "deathStar", "T-65 X-wing", "Death Star Trench Run"),
                          ("tieFighter", "deathStar", "TIE fighter", "Death Star Trench Run"),
                          ("millenniumFalcon", "deathStar", "Millennium Falcon", "Death Star Trench Run")]
        for (aircraft, level, name, route) in selections {
            tapHomeAction("Choose Flight planner", in: app)
            XCTAssertTrue(app.navigationBars["Flight planner"].waitForExistence(timeout: 5))
            tapCard("aircraft-\(aircraft)", in: app)
            capture(app, name: "Hangar – \(name)")
            app.buttons["Planner done"].tap()
            tapHomeAction("Choose Flight planner", in: app)
            app.segmentedControls.buttons.matching(NSPredicate(format: "label ==[c] %@", "Levels")).firstMatch.tap()
            tapCard("level-\(level)", in: app)
            capture(app, name: "Level selection – \(route)")
            app.buttons["Planner done"].tap()
            let selected = app.staticTexts["Current flight selection"]
            XCTAssertTrue(selected.label.contains(name))
            XCTAssertTrue(selected.label.contains(route))
            let start = app.buttons["Take flight"]
            expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: start)
            waitForExpectations(timeout: 45)
            start.tap()
            XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout: 10))
            capture(app, name: "Flight – \(name) – \(route)")
            app.buttons["Switch camera"].tap()
            XCTAssertTrue(app.buttons["Pause flight"].exists)
            app.buttons["Pause flight"].tap()
            app.buttons["Back to base"].tap()
        }
        // The final ship/trench choice survives a fresh process without launch overrides.
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.staticTexts["Current flight selection"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Current flight selection"].label.contains("Millennium Falcon"))
        XCTAssertTrue(app.staticTexts["Current flight selection"].label.contains("Death Star Trench Run"))
    }

    @MainActor
    func testEndorEnterpriseAndFreeRoam() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft", "kestrel", "-level", "alpine"]
        app.launch()
        XCTAssertTrue(app.buttons["Choose Flight planner"].waitForExistence(timeout: 30))
        for (aircraft, name) in [("aWing", "A-wing"), ("enterprise", "USS Enterprise")] {
            tapHomeAction("Choose Flight planner", in: app)
            tapCard("aircraft-\(aircraft)", in: app)
            app.buttons["Planner done"].tap()
            tapHomeAction("Choose Flight planner", in: app)
            app.segmentedControls.buttons.matching(NSPredicate(format: "label ==[c] %@", "Levels")).firstMatch.tap()
            tapCard("level-endor", in: app)
            app.buttons["Planner done"].tap()
            XCTAssertTrue(app.staticTexts["Current flight selection"].label.contains(name))
            XCTAssertTrue(app.staticTexts["Current flight selection"].label.contains("Endor Moon Run"))
            let start = app.buttons["Take flight"]
            expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: start)
            waitForExpectations(timeout: 45)
            start.tap()
            XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout: 10))
            capture(app, name: "Endor – \(name)")
            app.buttons["Pause flight"].tap()
            app.buttons["Back to base"].tap()
        }
        tapHomeAction("Choose Flight planner", in: app)
        tapCard("aircraft-voyager", in: app)
        app.buttons["Planner done"].tap()
        tapHomeAction("Choose Free roam", in: app)
        XCTAssertTrue(app.staticTexts["Current flight selection"].label.contains("Outer Rim Free Flight"))
        let start = app.buttons["Take flight"]
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: start)
        waitForExpectations(timeout: 45)
        start.tap()
        XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["FREE ROAM"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["0/0"].exists)
        capture(app, name: "Free roam – USS Voyager")
        app.buttons["Pause flight"].tap()
        XCTAssertTrue(app.buttons["Resume flight"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDeathStarTrenchLaunch() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-aircraft", "xwing", "-level", "deathStar"]
        app.launch()
        let start = app.buttons["Take flight"]
        XCTAssertTrue(start.waitForExistence(timeout: 30))
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: start)
        waitForExpectations(timeout: 45)
        start.tap()
        XCTAssertTrue(app.buttons["Pause flight"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["TRENCH ENTRY"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Death Star countdown"].exists)
        capture(app, name: "Death Star – recessed trench")
    }

    @MainActor
    private func tapVisibleCard(_ button: XCUIElement, in scroll: XCUIElement) -> Bool {
        guard button.exists else { return false }
        // Lazy-grid elements may exist with no onscreen activation point.
        let visible = button.frame.intersection(scroll.frame.insetBy(dx: 8, dy: 20))
        guard !visible.isNull, visible.width > 40, visible.height > 60 else { return false }
        scroll.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: visible.midX - scroll.frame.minX,
                                 dy: visible.midY - scroll.frame.minY)).tap()
        return true
    }

    @MainActor
    private func tapCard(_ identifier: String, in app: XCUIApplication) {
        let button = app.buttons[identifier]
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<12 {
            if tapVisibleCard(button, in: scroll) { return }
            scroll.swipeUp()
        }
        for _ in 0..<12 {
            if tapVisibleCard(button, in: scroll) { return }
            scroll.swipeDown()
        }
        XCTFail("Selection card was not reachable: \(identifier)")
    }
}
