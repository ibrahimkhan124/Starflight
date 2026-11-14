import SwiftUI
import UniformTypeIdentifiers

struct WorkshopView: View {
    @ObservedObject var engine: GameEngine
    @ObservedObject var library: CustomContentStore
    @Environment(\.dismiss) private var dismiss
    @State private var showRoomFlight = false
    @State private var handling: AircraftType = .xwing
    @State private var draft = CustomLevelDefinition()
    @State private var importing = false
    @State private var showImporter = false
    @State private var importShip = true
    @State private var showExporter = false
    @State private var exportDocument = LevelRecipeDocument(definition: CustomLevelDefinition())
    @State private var message: String?
    @State private var failure: String?
    @State private var levelResult: String?
    @State private var savedLevelName: String?
    @State private var showLevelSaved = false

    init(engine: GameEngine) {
        self.engine = engine
        library = engine.creations
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Bring in your own ship model, or build a new mountain route from a terrain recipe. Your creations stay in this app’s local library.")
                        .font(.subheadline)
                    if let error = library.loadError { Text(error).foregroundStyle(.white).font(.caption) }
                    if let message { Text(message).foregroundStyle(.white).font(.caption) }
                    if let failure { Text(failure).foregroundStyle(.white).font(.caption).accessibilityIdentifier("Import error") }
                    if importing { ProgressView("Checking ship model…") }
                }
                Section("Fly in your room") {
#if os(iOS) && !targetEnvironment(macCatalyst)
                    Button("Open room flight") { showRoomFlight = true }.flightButtonGlass().accessibilityIdentifier("Open room flight")
                    Text("Scan a floor or table, place your selected ship, and build a miniature course with gates, towers and asteroids. Uses the rear camera on supported devices.").font(.caption)
#else
                    Text("Room flight is available on supported iPhones and iPads.").font(.caption)
#endif
                }
                Section("Import a ship") {
                    Picker("Handling preset", selection: $handling) {
                        ForEach(AircraftType.allCases.filter { engine.economy.unlocked($0) }) { type in Text(type.name).tag(type) }
                    }.flightButtonGlass()
                    Button("Choose USDZ blender model…") { importShip = true; showImporter = true }
                        .padding(10)
                        .flightButtonGlass()
                        .accessibilityIdentifier("Import ship")
                    Text("The preset supplies speed, guns, and a collision envelope. Your model is fitted into that envelope. Export with the nose facing −Z, up +Y, and textures packed inside. Maximum file size: 20 MB.")
                        .font(.caption).foregroundStyle(.white)
                }
                Section("My ships") {
                    if library.ships.isEmpty { Text("Your imported ships will appear here.").foregroundStyle(.white).font(.caption) }
                    ForEach(library.ships) { ship in
                        Button { engine.selectCustomShip(ship); message = "Selected \(ship.name)" } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(ship.name).font(FlightStyle.displayFont(12)).textCase(.lowercase)
                                    Text("Handling: \(ship.handling.name)").font(.caption).foregroundStyle(.white)
                                }
                                Spacer()
                                if engine.customShip?.id == ship.id { Image(systemName: "checkmark.circle.fill") }
                            }
                        }.flightButtonGlass()
                    }
                }
                Section("Create a mountain level") {
                    TextField("Level name", text: $draft.name).accessibilityIdentifier("Custom level name")
                    // A stepped slider over a million seeds creates huge numbers of
                    // native tick views. Round in the binding and keep it continuous.
                    Slider(value:Binding<Double>(get:{ Double(draft.seed) },set:{ value in
                        guard value.isFinite else { return }
                        draft.seed = UInt32(min(999999,max(1,value.rounded())))
                    }),in:1...999999) { Text("Landscape variation: \(draft.seed)") }.flightButtonGlass()
                    Text("Choose a different number for a different landscape. The same number recreates the same terrain.").font(.caption).foregroundStyle(.white)
                    parameter("Mountain height", value: $draft.mountainScale, range: CustomLevelDefinition.mountainRange)
                    parameter("Valley width", value: $draft.valleyWidth, range: CustomLevelDefinition.valleyRange)
                    parameter("Bend strength", value: $draft.bends, range: CustomLevelDefinition.bendRange)
                    parameter("Saddle height", value: $draft.saddles, range: CustomLevelDefinition.saddleRange)
                    Button("Save and select level") {
                        do {
                            let level = try library.addLevel(draft)
                            let selected = engine.selectCustomLevel(level)
                            failure = nil
                            levelResult = selected
                                ? "Saved and selected \(level.name). Tap Done, then Take flight when preparation finishes."
                                : "Saved \(level.name). Return to base to select it from My levels."
                            savedLevelName = level.name
                            showLevelSaved = true
                        } catch {
                            levelResult = error.localizedDescription
                        }
                    }.padding(10)
                    .flightButtonGlass().accessibilityIdentifier("Save custom level")
                    if let levelResult {
                        Text(levelResult).font(.callout)
                            .accessibilityIdentifier("Level save result")
                    }
                    Text("This first creator makes a complete mountain region with the beginner route’s checkpoints. The sliders change both the visible ground and collisions. Full Blender landscapes and custom pod circuits are not imported yet.")
                        .font(.caption).foregroundStyle(.white)
                    Button("Import level recipe…") { importShip = false; showImporter = true }
                        .padding(10)
                        .flightButtonGlass()
                }
                Section("My levels") {
                    if library.levels.isEmpty { Text("Saved and imported levels will appear here.").foregroundStyle(.white).font(.caption) }
                    ForEach(library.levels) { level in
                        HStack {
                            Button { message = engine.selectCustomLevel(level) ? "Selected \(level.name)" : "Return to base before selecting a level." } label: {
                                HStack {
                                    Text(level.name).font(FlightStyle.displayFont(12)).textCase(.lowercase)
                                    if engine.customLevel?.id == level.id { Image(systemName: "checkmark.circle.fill") }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                    
                            }.padding(10)
                            .flightButtonGlass()
                            Button {
                                exportDocument = LevelRecipeDocument(definition: level)
                                showExporter = true
                            } label: { Image(systemName: "square.and.arrow.up") }.flightButtonGlass()
                                .accessibilityLabel("Export \(level.name) recipe")
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showRoomFlight) { RoomFlightView(aircraft: engine.settings.aircraft, customURL: engine.customShipURL) }
            .disabled(importing)
            .navigationTitle("My creations")
#if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.flightButtonGlass().disabled(importing) } }
            .alert("Level saved", isPresented: $showLevelSaved) {
                Button("Keep editing", role: .cancel) { }.flightButtonGlass()
                Button("Back to hangar") { dismiss() }.flightButtonGlass()
            } message: {
                Text(levelResult ?? "Saved \(savedLevelName ?? "level") to My levels.")
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: importShip ? [UTType(filenameExtension: "usdz") ?? .data] : [.json]) { result in
                switch result {
                case .success(let url):
                    failure = nil; message = nil
                    if importShip {
                        importing = true
                        Task { @MainActor in
                            defer { importing = false }
                            do {
                                let ship = try await library.importShip(from: url, handling: handling)
                                engine.selectCustomShip(ship)
                                message = "Imported and selected \(ship.name)"
                            } catch { failure = error.localizedDescription }
                        }
                    } else {
                        do {
                            let level = try library.importLevel(from: url)
                            message = engine.selectCustomLevel(level)
                                ? "Imported and selected \(level.name)"
                                : "Imported \(level.name). Return to base to select it."
                        } catch { failure = error.localizedDescription }
                    }
                case .failure(let error): failure = error.localizedDescription
                }
            }
            .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: .json, defaultFilename: "MountainLevel") { result in
                if case .failure(let error) = result { failure = error.localizedDescription }
            }
        }.preferredColorScheme(.dark).tint(.white)
    }

    private func parameter(_ title: String, value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        VStack(alignment: .leading) {
            Text("\(title): \(value.wrappedValue, specifier: "%.2f")×")
            Slider(value: value, in: range, step: 0.05).flightButtonGlass().accessibilityLabel(title)
        }
    }
}

struct LevelRecipeDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var definition: CustomLevelDefinition
    init(definition: CustomLevelDefinition) { self.definition = definition }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CustomContentError.invalid("Empty level recipe.") }
        definition = try JSONDecoder().decode(CustomLevelDefinition.self, from: data).validated()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(definition.validated()))
    }
}
