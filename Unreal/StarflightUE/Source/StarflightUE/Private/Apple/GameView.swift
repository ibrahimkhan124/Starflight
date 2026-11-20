import SwiftUI

struct GameView: View {
    private let destinations = [
        ("Hoth", "Frozen ridges and glacier passes", "snowflake", Color.cyan),
        ("Tatooine", "Sandstone mesas and branching canyons", "sun.max.fill", Color.orange),
        ("Endor", "Woodland valleys and old-growth canopy", "tree.fill", Color.green),
        ("Coruscant", "Neon towers and winding tunnels", "building.2.fill", Color.purple)
    ]

    let current: Int32
    let onSelect: (Int32) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Flight Planner")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                ForEach(destinations.indices, id: \.self) { index in
                    let (name, description, symbol, color) = destinations[index]
                    let isCurrent = current == index
                    Button {
                        onSelect(Int32(index))
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
