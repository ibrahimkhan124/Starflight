import Foundation
import simd

func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T { min(max(value, lower), upper) }

@main struct ExportLevelSurfaces {
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for level in FlightLevel.allCases {
            let generator = TerrainGenerator(seed: level.seed, level: level)
            let minZ = level.isFreeRoam ? -4 : Int(floor(-level.routeLength / 600)) - 3
            let maxZ = level.isFreeRoam ? 3 : 3
            var tiles: [[String: Any]] = []
            for z in minZ...maxZ {
                for x in -4...3 {
                    var heights: [Float] = []
                    for row in 0...24 {
                        for col in 0...24 {
                            heights.append(generator.height(x: Float(x * 600 + col * 25), z: Float(z * 600 + row * 25)))
                        }
                    }
                    tiles.append(["x": x, "z": z, "heights": heights])
                }
            }
            let centers = (minZ * 24...(maxZ + 1) * 24).map { generator.valleyCenter(at: Float($0 * 25)) }
            let record: [String: Any] = ["level": level.rawValue, "tiles": tiles, "minZ": minZ, "maxZ": maxZ,
                "centers": centers, "width": level.valleyWidth, "race": level.isPodRace,
                "snowLine": level.snowLine, "palette": level.palette.map { [$0.x, $0.y, $0.z] }]
            try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]).write(to: directory.appendingPathComponent("\(level.rawValue).json"))
            print("Sampled \(level.rawValue): \(tiles.count) tiles")
        }
    }
}
