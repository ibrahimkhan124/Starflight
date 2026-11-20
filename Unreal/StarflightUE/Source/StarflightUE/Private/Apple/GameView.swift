import SwiftUI

struct GameView: View {
    private let destinations = [
        ("Hoth", "Ice lakes, glacier passes and frozen wreckage", "snowflake", Color.cyan),
        ("Tatooine", "Sandstone mesas and branching canyons", "sun.max.fill", Color.orange),
        ("Endor", "Forest lakes and old-growth canopy", "tree.fill", Color.green),
        ("Coruscant", "Neon towers, roadways and shuttle lanes", "building.2.fill", Color.purple)
    ]

    let current: Int32
    let ships: [String]
    let onSelect: (Int32, Int32) -> Void
    @State private var ship: Int32

    init(current: Int32, ships: [String], activeShip: Int32,
         onSelect: @escaping (Int32, Int32) -> Void) {
        self.current = current
        self.ships = ships
        self.onSelect = onSelect
        _ship = State(initialValue: activeShip)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Flight Planner")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                HStack {
                    Picker("Ship", selection: $ship) {
                        ForEach(ships.indices, id: \.self) { index in
                            Text(ships[index]).tag(Int32(index))
                        }
                    }
                    Button("Use ship") { onSelect(current, ship) }
                        .buttonStyle(.borderedProminent)
                }
                .padding(10)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                ForEach(destinations.indices, id: \.self) { index in
                    let (name, description, symbol, color) = destinations[index]
                    let isCurrent = current == index
                    Button {
                        onSelect(Int32(index), ship)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: symbol)
                                .foregroundStyle(color)
                                .frame(width: 28)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name).font(.headline)
                                Text(description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isCurrent {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(color)
                                    .accessibilityLabel("Current planet")
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(10)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(Color(red: 0.025, green: 0.049, blue: 0.09))
        .preferredColorScheme(.dark)
    }
}
