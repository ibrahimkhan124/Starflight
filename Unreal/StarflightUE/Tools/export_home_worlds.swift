// Compiled with the native Starflight world definitions by export_home_worlds.sh.
@main struct ExportHomeWorlds {
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for planet in SpacePlanet.allCases {
            let world = PlanetExploration(planet: planet)
            let cells = planet == .coruscant ? 1 : PlanetExploration.grid * 2
            let extent = PlanetExploration.extent
            let step = 2 * extent / Float(cells)
            var data = Data("SFW1".utf8)
            func word(_ value: UInt32) {
                var little = value.littleEndian
                withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
            }
            func float(_ value: Float) { word(value.bitPattern) }
            func vector(_ value: SIMD3<Float>) {
                float(value.x); float(value.y); float(value.z)
            }
            word(UInt32(cells))
            word(UInt32(world.obstacles.count))
            float(extent)
            vector(world.arrival)
            for row in 0...cells {
                for col in 0...cells {
                    float(world.vertexHeight(x: Float(col) * step - extent, z: Float(row) * step - extent))
                }
            }
            for obstacle in world.obstacles {
                vector(obstacle.center)
                vector(obstacle.size)
                float(obstacle.yaw)
                word(UInt32(obstacle.style))
            }
            try data.write(to: directory.appendingPathComponent(planet.rawValue + ".sfworld"), options: .atomic)
            print("\(planet.name): \(cells) × \(cells) cells, \(world.obstacles.count) obstacles.")
        }
    }
}
