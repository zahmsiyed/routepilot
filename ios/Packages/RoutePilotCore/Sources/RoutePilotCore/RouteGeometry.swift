import Foundation

public struct RoutePilotError: LocalizedError, Equatable, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public struct RoutePoint: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    public var isValid: Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}

public enum MovementMode: String, Codable, CaseIterable, Sendable {
    case stationary, running, driving
    public var title: String { rawValue.capitalized }
    public var defaultSpeedKPH: Double { self == .driving ? 50 : 10 }
}

public enum UnitSystem: String, Codable, CaseIterable, Sendable {
    case metric, imperial
    public var speedUnit: String { self == .metric ? "km/h" : "mph" }
    public var distanceUnit: String { self == .metric ? "km" : "mi" }
    public var lateralUnit: String { self == .metric ? "m" : "ft" }
    public var metersPerDistanceUnit: Double { self == .metric ? 1_000 : 1_609.344 }
    public func displaySpeed(_ kph: Double) -> Double { self == .metric ? kph : kph / 1.609344 }
    public func speedKPH(_ displayed: Double) -> Double { self == .metric ? displayed : displayed * 1.609344 }
    public func displayDistance(_ meters: Double) -> Double { meters / metersPerDistanceUnit }
    public func displayLateral(_ meters: Double) -> Double { self == .metric ? meters : meters / 0.3048 }
    public func lateralMeters(_ displayed: Double) -> Double { self == .metric ? displayed : displayed * 0.3048 }
}

public struct RouteGeometry: Sendable {
    public static let maximumPoints = 30_000
    public static let earthRadius = 6_371_008.8
    public let points: [RoutePoint]
    public let cumulative: [Double]
    public var totalDistance: Double { cumulative.last ?? 0 }

    public init(points rawPoints: [RoutePoint], loop: Bool = false) throws {
        guard (1...Self.maximumPoints).contains(rawPoints.count), rawPoints.allSatisfy(\.isValid) else {
            throw RoutePilotError("Choose 1–30,000 valid route points. Latitude must be −90 to 90 and longitude −180 to 180.")
        }
        var filtered: [RoutePoint] = []
        for point in rawPoints where filtered.last.map({ Self.distance($0, point) > 0.001 }) ?? true { filtered.append(point) }
        if loop, filtered.count > 1, Self.distance(filtered[0], filtered[filtered.count - 1]) > 0.001 {
            guard filtered.count < Self.maximumPoints else { throw RoutePilotError("Leave room for the return point when looping a maximum-sized route.") }
            filtered.append(filtered[0])
        }
        var lengths = [0.0]
        for index in 1..<filtered.count {
            let distance = Self.distance(filtered[index - 1], filtered[index])
            guard distance / Self.earthRadius <= .pi - 1e-6 else {
                throw RoutePilotError("Add an intermediate point between opposite sides of the globe.")
            }
            lengths.append(lengths[index - 1] + distance)
        }
        self.points = filtered
        self.cumulative = lengths
    }

    public static func distance(_ a: RoutePoint, _ b: RoutePoint) -> Double {
        let p = a.latitude.radians, q = b.latitude.radians
        let h = pow(sin((q - p) / 2), 2) + cos(p) * cos(q) * pow(sin((b.longitude - a.longitude).radians / 2), 2)
        return 2 * earthRadius * asin(sqrt(h.clamped(0, 1)))
    }

    public func position(atDistance meters: Double) -> RoutePoint {
        guard totalDistance > 0, meters.isFinite, meters > 0 else { return points[0] }
        guard meters < totalDistance else { return points[points.count - 1] }
        let index = segmentIndex(atDistance: meters)
        return Self.interpolate(points[index], points[index + 1], fraction: (meters - cumulative[index]) / (cumulative[index + 1] - cumulative[index]))
    }

    public func lateralPosition(atDistance meters: Double, offset requested: Double) -> (point: RoutePoint, offset: Double) {
        let center = position(atDistance: meters)
        guard requested.isFinite, requested != 0, meters > 0, meters < totalDistance else { return (center, 0) }
        let index = segmentIndex(atDistance: meters)
        let t = (min(meters - cumulative[index], cumulative[index + 1] - meters) / 5).clamped(0, 1)
        let offset = requested.clamped(-2, 2) * t * t * (3 - 2 * t)
        let lat = center.latitude.radians, lon = center.longitude.radians
        let q = points[index + 1].latitude.radians, delta = points[index + 1].longitude.radians - lon
        let bearing = atan2(sin(delta) * cos(q), cos(lat) * sin(q) - sin(lat) * cos(q) * cos(delta)) + .pi / 2
        let angular = offset / Self.earthRadius
        let p = asin((sin(lat) * cos(angular) + cos(lat) * sin(angular) * cos(bearing)).clamped(-1, 1))
        let n = lon + atan2(sin(bearing) * sin(angular) * cos(lat), cos(angular) - sin(lat) * sin(p))
        return (RoutePoint(latitude: p.degrees, longitude: Self.wrapLongitude(n.degrees)), offset)
    }

    public func segmentIndex(atDistance meters: Double) -> Int {
        guard points.count > 1 else { return 0 }
        var low = 0, high = cumulative.count - 1
        while low + 1 < high {
            let middle = (low + high) / 2
            if cumulative[middle] <= meters { low = middle } else { high = middle }
        }
        return min(low, points.count - 2)
    }

    public static func interpolate(_ a: RoutePoint, _ b: RoutePoint, fraction: Double) -> RoutePoint {
        guard fraction > 0 else { return a }
        guard fraction < 1 else { return b }
        let angle = distance(a, b) / earthRadius
        guard angle > 1e-10 else { return a }
        let x = sin((1 - fraction) * angle) / sin(angle), y = sin(fraction * angle) / sin(angle)
        let p = a.latitude.radians, l = a.longitude.radians, q = b.latitude.radians, m = b.longitude.radians
        let vx = x * cos(p) * cos(l) + y * cos(q) * cos(m)
        let vy = x * cos(p) * sin(l) + y * cos(q) * sin(m)
        let vz = x * sin(p) + y * sin(q)
        return RoutePoint(latitude: atan2(vz, hypot(vx, vy)).degrees, longitude: atan2(vy, vx).degrees)
    }

    private static func wrapLongitude(_ longitude: Double) -> Double {
        let remainder = (longitude + 180).truncatingRemainder(dividingBy: 360)
        return (remainder < 0 ? remainder + 360 : remainder) - 180
    }
}

extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
    func clamped(_ low: Double, _ high: Double) -> Double { min(high, max(low, self)) }
}
