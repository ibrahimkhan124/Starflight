import SwiftUI
import SceneKit

enum AvatarAccessory: String, CaseIterable, Codable, Identifiable {
    case flightGoggles, headset, scarf, starCrown, jetpack, moonCompanion
    var id: String { rawValue }
    var title: String { switch self { case .flightGoggles: return "Flight goggles"; case .headset: return "Comms headset"; case .scarf: return "Nebula scarf"; case .starCrown: return "Starlight crown"; case .jetpack: return "Explorer jetpack"; case .moonCompanion: return "Moon companion" } }
    var symbol: String { switch self { case .flightGoggles: return "eyeglasses"; case .headset: return "headphones"; case .scarf: return "wind"; case .starCrown: return "crown.fill"; case .jetpack: return "flame.fill"; case .moonCompanion: return "moon.stars.fill" } }
    var price: Int { switch self { case .flightGoggles: return 150; case .headset: return 250; case .scarf: return 350; case .starCrown: return 900; case .jetpack: return 1200; case .moonCompanion: return 600 } }
}
struct PilotProfile: Codable, Equatable {
    var name = "Star pilot"
    var suit = "Cyan"
    var species: String?
    var owned: Set<AvatarAccessory> = []
    var equipped: AvatarAccessory?
    static let colors = ["Cyan", "Violet", "Gold", "Coral"]
    var valid: Bool { name.count <= 24 && (species == nil || ["Human", "Droid", "Alien"].contains(species!)) && Self.colors.contains(suit) && (equipped == nil || owned.contains(equipped!)) }
    var tint: Color { switch suit { case "Violet": return .purple; case "Gold": return .yellow; case "Coral": return .orange; default: return .cyan } }
}

struct PilotAvatarPortrait: View {
    let profile: PilotProfile
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [profile.tint.opacity(0.4), .black], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().stroke(profile.tint.opacity(0.6), lineWidth: 2).padding(5)
            Image(systemName: "person.fill").resizable().scaledToFit().foregroundStyle(profile.tint).padding(28).offset(y: 14)
            Circle().fill(profile.species == "Alien" ? Color.green : profile.species == "Droid" ? Color.gray : Color(red: 0.82, green: 0.62, blue: 0.46)).frame(width: 54, height: 54).offset(y: -17)
            Capsule().fill(.black.opacity(0.75)).frame(width: 45, height: 19).overlay(Capsule().stroke(.white.opacity(0.7))).offset(y: -19)
            if let item = profile.equipped {
                Image(systemName: item.symbol).font(.system(size: 28, weight: .bold)).foregroundStyle(.yellow)
                    .offset(x: item == .moonCompanion ? 57 : item == .jetpack ? 47 : 0,
                            y: item == .starCrown ? -53 : item == .scarf ? 18 : item == .jetpack ? 30 : item == .moonCompanion ? -48 : -18)
            }
        }.frame(width: 200, height: 200).clipShape(Circle()).accessibilityElement(children: .ignore)
            .accessibilityLabel("\(profile.name), \(profile.suit) suit, \(profile.equipped?.title ?? "no accessory")")
    }
}
struct PilotProfileView: View {
    @ObservedObject var engine: GameEngine
    @State private var name = ""
    @State private var notice = ""
    private var profile: PilotProfile { engine.economy.profile ?? PilotProfile() }
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                PilotAvatarPortrait(profile: profile)
                Text(profile.name).font(.title.bold())
                Text("\(engine.economy.creditsLabel) credits").foregroundStyle(FlightPalette.gold)
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Pilot name", text: $name).textFieldStyle(.roundedBorder).accessibilityIdentifier("Avatar pilot name")
                    Button("Save pilot name") { engine.editPilotProfile(name: String(name.prefix(24)), suit: profile.suit); notice = "Profile saved" }.flightButtonGlass()
                    Picker("Avatar type", selection: Binding(get: { profile.species ?? "Human" }, set: { engine.editPilotProfile(name: profile.name, suit: profile.suit, species: $0) })) {
                        ForEach(["Human", "Droid", "Alien"], id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Flight suit", selection: Binding(get: { profile.suit }, set: { engine.editPilotProfile(name: profile.name, suit: $0) })) {
                        ForEach(PilotProfile.colors, id: \.self) { Text($0).tag($0) }
                    }
                    Text("Your avatar and accessories are saved with your game wallet. Profile names are limited to 24 characters.").font(.caption).foregroundStyle(.secondary)
                }.padding().background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
                if !notice.isEmpty { Text(notice).accessibilityIdentifier("Avatar purchase result") }
                Text("Avatar outfitter").font(.title2.bold())
                Text("Buy an accessory here or win one in the daily wheel. Equip one accessory at a time.").font(.subheadline).foregroundStyle(.secondary)
                Button("Remove accessory") { engine.equipAvatarAccessory(nil) }.flightButtonGlass().disabled(profile.equipped == nil)
                ForEach(AvatarAccessory.allCases) { item in
                    HStack(spacing: 16) {
                        Image(systemName: item.symbol).font(.largeTitle).foregroundStyle(FlightPalette.gold).frame(width: 50)
                        VStack(alignment: .leading) { Text(item.title).font(.headline); Text(profile.owned.contains(item) ? "Owned" : "\(item.price) credits").font(.caption) }
                        Spacer()
                        Button(profile.equipped == item ? "Equipped" : profile.owned.contains(item) ? "Equip" : "Buy") {
                            if profile.owned.contains(item) { engine.equipAvatarAccessory(item); notice = "Equipped \(item.title)" }
                            else { notice = engine.buyAvatarAccessory(item) ? "Bought \(item.title)" : "Not enough credits" }
                        }.flightButtonGlass().disabled(profile.equipped == item).accessibilityIdentifier("Avatar accessory \(item.rawValue)")
                    }.padding().background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                }
            }.padding(20).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.background(FlightStyle.ink).navigationTitle("Pilot profile").onAppear { name = profile.name }
    }
}

struct AchievementBadgeArt: View {
    let achievement: PilotAchievement
    let unlocked: Bool
    private var symbol: String {
        switch achievement {
        case .km20,.km100,.km1000,.km10000,.km20000: return "airplane.circle.fill"
        case .flights10,.flights30,.flights100: return "star.circle.fill"
        case .closeShaves10: return "mountain.2.fill"
        case .turns50: return "arrow.triangle.2.circlepath"
        case .soars25: return "cloud.sun.fill"
        case .hothReturn: return "snowflake"
        case .worlds4: return "globe.americas.fill"
        case .safe10: return "shield.lefthalf.filled"
        }
    }
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color.cyan.opacity(unlocked ? 0.8 : 0.12), .indigo, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
            ForEach(0..<24, id: \.self) { index in
                Capsule().fill(unlocked ? Color.yellow.opacity(0.85) : Color.gray)
                    .frame(width: 2, height: index.isMultiple(of: 3) ? 7 : 3)
                    .offset(y: -37).rotationEffect(.degrees(Double(index)*15))
            }
            Circle().stroke(.white.opacity(0.3), lineWidth: 1).padding(17)
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: "star.fill").font(.system(size: 5)).foregroundStyle(unlocked ? .yellow : .gray)
                    .offset(x: CGFloat(index-2)*9, y: 25)
            }
            Circle().stroke(unlocked ? Color.yellow : Color.gray, lineWidth: 3).padding(9)
            Image(systemName: symbol).font(.system(size: 32)).foregroundStyle(unlocked ? .yellow : .gray)
            if !unlocked { Image(systemName: "lock.fill").font(.caption).padding(4).background(.black, in: Circle()).offset(x: 25, y: 25) }
        }.frame(width: 88, height: 88).accessibilityLabel("\(achievement.title) badge, \(unlocked ? "earned" : "locked")")
    }
}

/// The medallion has a real rim and two faces. Only yaw is changed by the drag.
struct AchievementBadgeInspector: View {
    let achievement: PilotAchievement
    let unlocked: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var angle: Double = 0
    @State private var dragStart: Double = 0
    @State private var scene: SCNScene?
    @State private var medal: SCNNode?
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let scene {
                    SceneView(scene: scene, options: [], preferredFramesPerSecond: 30, antialiasingMode: .multisampling4X)
                        .frame(height: 300).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                            angle = dragStart + value.translation.width * 0.012
                            medal?.eulerAngles.y = Float(angle)
                        }.onEnded { _ in dragStart = angle })
                        .accessibilityLabel("3D \(achievement.title) medal. Swipe horizontally to turn.")
                        .accessibilityAdjustableAction { direction in
                            angle += direction == .increment ? 0.4 : -0.4
                            dragStart = angle; medal?.eulerAngles.y = Float(angle)
                        }.accessibilityIdentifier("Rotating achievement badge")
                }
                Text(achievement.title).font(.title2.bold())
                Text(achievement.detail).multilineTextAlignment(.center)
                Label(unlocked ? "Earned" : "Keep flying to earn this badge", systemImage: unlocked ? "checkmark.seal.fill" : "lock.fill").foregroundStyle(.cyan)
                Text("Drag left or right for a full 360° view.").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }.padding().background(FlightStyle.ink).foregroundStyle(.white)
                .navigationTitle("Flight award")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .task { prepareMedal() }
        }
    }
    @MainActor private func prepareMedal() {
        let scene = SCNScene(); scene.background.contents = UIColor(FlightStyle.ink)
        let medal = SCNNode()
        let rim = SCNCylinder(radius: 1.05, height: 0.16); rim.radialSegmentCount = 96
        let metal = SCNMaterial(); metal.diffuse.contents = unlocked ? UIColor.systemYellow : UIColor.darkGray
        metal.metalness.contents = 0.85; metal.roughness.contents = 0.25; rim.materials = [metal]
        let edge = SCNNode(geometry: rim); edge.eulerAngles.x = .pi/2; medal.addChildNode(edge)
        let renderer = ImageRenderer(content: AchievementBadgeArt(achievement: achievement, unlocked: unlocked).scaleEffect(3).frame(width: 264, height: 264))
        renderer.scale = 2
        for side: Float in [1, -1] {
            let face = SCNPlane(width: 2, height: 2)
            let paint = SCNMaterial(); paint.diffuse.contents = renderer.uiImage; paint.lightingModel = .constant
            face.materials = [paint]
            let node = SCNNode(geometry: face); node.position.z = side*0.085
            if side < 0 { node.eulerAngles.y = .pi }
            medal.addChildNode(node)
        }
        scene.rootNode.addChildNode(medal)
        let camera = SCNNode(); camera.camera = SCNCamera(); camera.position.z = 4.6; scene.rootNode.addChildNode(camera)
        let light = SCNNode(); light.light = SCNLight(); light.light?.type = .omni; light.light?.intensity = 900; light.position = SCNVector3(-2,3,4); scene.rootNode.addChildNode(light)
        self.medal = medal; self.scene = scene
    }
}
