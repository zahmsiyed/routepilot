import XCTest
@testable import RoutePilotCore

final class RoutePilotCoreTests: XCTestCase {
    let a = RoutePoint(latitude: 37, longitude: -122)
    let b = RoutePoint(latitude: 37.0005, longitude: -122)
    let c = RoutePoint(latitude: 37.0005, longitude: -121.999)

    func testRouteValidationDistanceCornersAndLoopClosure() throws {
        let route = try RouteGeometry(points: [a, a, b, c])
        XCTAssertEqual(route.points, [a, b, c])
        XCTAssertEqual(route.position(atDistance: route.cumulative[1]), b)
        XCTAssertEqual(route.position(atDistance: -1), a)
        XCTAssertEqual(route.position(atDistance: route.totalDistance + 1), c)
        XCTAssertEqual(RouteGeometry.distance(a, b), 55.5975, accuracy: 0.001)
        let loop = try RouteGeometry(points: [a, b, c], loop: true)
        XCTAssertEqual(loop.points, [a, b, c, a])
        XCTAssertEqual(try RouteGeometry(points: loop.points, loop: true).points, loop.points)
        XCTAssertThrowsError(try RouteGeometry(points: []))
        XCTAssertThrowsError(try RouteGeometry(points: [.init(latitude: .nan, longitude: 0)]))
        XCTAssertThrowsError(try RouteGeometry(points: [.init(latitude: 91, longitude: 0)]))
        XCTAssertThrowsError(try RouteGeometry(points: [.init(latitude: 0, longitude: 0), .init(latitude: 0, longitude: 180)]))
    }

    func testDatelineInterpolationAndPolarLateralRemainFinite() throws {
        let route = try RouteGeometry(points: [.init(latitude: 0, longitude: 179), .init(latitude: 0, longitude: -179)])
        let middle = route.position(atDistance: route.totalDistance / 2)
        XCTAssertEqual(abs(middle.longitude), 180, accuracy: 1e-6)
        XCTAssertLessThan(route.totalDistance, 223_000)
        let polar = try RouteGeometry(points: [.init(latitude: 89.9999, longitude: 0), .init(latitude: 89.9999, longitude: 179)])
        XCTAssertTrue(polar.lateralPosition(atDistance: polar.totalDistance / 2, offset: 2).point.isValid)
    }

    func testLateralVariationBoundedAndFadesAtCorners() throws {
        let route = try RouteGeometry(points: [a, b, c])
        for meters in stride(from: 0.0, to: route.totalDistance, by: 0.4) {
            let result = route.lateralPosition(atDistance: meters, offset: 20)
            XCTAssertTrue(result.point.isValid)
            XCTAssertLessThanOrEqual(abs(result.offset), 2)
            XCTAssertLessThanOrEqual(RouteGeometry.distance(result.point, route.position(atDistance: meters)), 2.001)
        }
        XCTAssertEqual(route.lateralPosition(atDistance: route.cumulative[1], offset: 2).offset, 0)
        XCTAssertEqual(route.lateralPosition(atDistance: 0, offset: 2).point, a)
        XCTAssertEqual(route.lateralPosition(atDistance: route.totalDistance, offset: 2).point, c)
    }

    func testPlaybackPauseSpeedChangesAndTimerGap() throws {
        let route = try RouteGeometry(points: [a, b, c])
        var playback = try PlaybackSimulation(route: route, mode: .running, settings: .init(speedKPH: 36))
        XCTAssertEqual(playback.advance(seconds: 1).meters, 10, accuracy: 1e-9)
        playback.setPaused(true)
        let paused = playback.snapshot
        XCTAssertEqual(playback.advance(seconds: 100).meters, paused.meters)
        XCTAssertEqual(playback.snapshot.elapsed, paused.elapsed)
        XCTAssertEqual(playback.snapshot.currentSpeedKPH, 0)
        playback.setPaused(false)
        try playback.updateSettings(.init(speedKPH: 72))
        XCTAssertEqual(playback.advance(seconds: 1).meters, 30, accuracy: 1e-9)
        XCTAssertEqual(playback.advance(seconds: 100).meters, 70, accuracy: 1e-9)
        XCTAssertEqual(playback.advance(seconds: .nan).meters, 70, accuracy: 1e-9)
        XCTAssertThrowsError(try playback.updateSettings(.init(speedKPH: .infinity)))
        XCTAssertEqual(playback.settings.speedKPH, 72)
    }

    func testPlaybackStationaryCompletionAndLoops() throws {
        var fixed = try PlaybackSimulation(route: RouteGeometry(points: [a]), mode: .stationary)
        XCTAssertEqual(fixed.advance(seconds: 1).position, a)
        XCTAssertEqual(fixed.snapshot.phase, .holding)
        XCTAssertEqual(fixed.snapshot.currentSpeedKPH, 0)
        XCTAssertThrowsError(try PlaybackSimulation(route: RouteGeometry(points: [a]), mode: .running))
        XCTAssertThrowsError(try PlaybackSimulation(route: RouteGeometry(points: [a, b]), mode: .stationary))
        var moving = try PlaybackSimulation(route: RouteGeometry(points: [a, b]), mode: .running, settings: .init(speedKPH: 250))
        _ = moving.advance(seconds: 2)
        XCTAssertEqual(moving.snapshot.phase, .completed)
        XCTAssertEqual(moving.snapshot.position, b)
        var loop = try PlaybackSimulation(route: RouteGeometry(points: [a, b], loop: true), mode: .running, settings: .init(speedKPH: 250), loop: true)
        for _ in 0..<50 { _ = loop.advance(seconds: 2) }
        XCTAssertGreaterThan(loop.snapshot.laps, 1)
        XCTAssertTrue(loop.snapshot.position.isValid)
        XCTAssertLessThan(loop.snapshot.meters, loop.route.totalDistance)
    }

    func testPlaybackSmoothVariationAndAtomicValidation() throws {
        let route = try RouteGeometry(points: [a, b, c], loop: true)
        var playback = try PlaybackSimulation(route: route, mode: .running, settings: .init(speedKPH: 10, speedVariationKPH: 2, lateralVariationMeters: 0.75), loop: true, seed: 7)
        for _ in 0..<1_000 {
            let snapshot = playback.advance(seconds: 0.5)
            XCTAssertTrue((8...12).contains(snapshot.currentSpeedKPH))
            XCTAssertLessThanOrEqual(abs(snapshot.lateralOffsetMeters), 0.75)
            XCTAssertTrue(snapshot.position.isValid)
        }
        XCTAssertThrowsError(try PlaybackSettings(speedKPH: 10, speedVariationKPH: 51).validate())
        XCTAssertThrowsError(try PlaybackSettings(speedKPH: 10, lateralVariationMeters: 2.01).validate())
    }

    func testPausedSettingsChangesKeepTheAppliedCoordinateFixed() throws {
        let route = try RouteGeometry(points: [a, b, c], loop: true)
        var playback = try PlaybackSimulation(route: route, mode: .running, settings: .init(speedKPH: 10, lateralVariationMeters: 2), loop: true, seed: 7)
        for _ in 0..<20 { playback.advance(seconds: 0.5) }
        playback.setPaused(true)
        let held = playback.snapshot
        try playback.updateSettings(.init(speedKPH: 20, speedVariationKPH: 2, lateralVariationMeters: 0))
        XCTAssertEqual(playback.snapshot.position, held.position)
        XCTAssertEqual(playback.snapshot.lateralOffsetMeters, held.lateralOffsetMeters)
        XCTAssertEqual(playback.snapshot.currentSpeedKPH, 0)
        playback.advance(seconds: 100)
        XCTAssertEqual(playback.snapshot.elapsed, held.elapsed)
        playback.setPaused(false)
        playback.advance(seconds: 0.5)
        XCTAssertEqual(playback.snapshot.lateralOffsetMeters, 0)
        XCTAssertGreaterThan(playback.snapshot.meters, held.meters)
    }

    func testUnitConversions() {
        XCTAssertEqual(UnitSystem.imperial.displaySpeed(1.609344), 1, accuracy: 1e-12)
        XCTAssertEqual(UnitSystem.imperial.displayDistance(1_609.344), 1, accuracy: 1e-12)
        XCTAssertEqual(UnitSystem.imperial.displayLateral(0.3048), 1, accuracy: 1e-12)
        XCTAssertEqual(UnitSystem.imperial.speedKPH(UnitSystem.imperial.displaySpeed(17.7)), 17.7, accuracy: 1e-12)
    }

    func testTimedGPXPreservesCornersWithStrictTimestampsAndEscapesName() throws {
        let route = try RouteGeometry(points: [a, b, c])
        let start = ISO8601DateFormatter().date(from: "2026-09-27T15:30:00Z")!
        let data = try GPXDocument.export(route: route, format: .track, name: "Test <run> & path", startTime: start, speedKPH: 12)
        let xml = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(xml.contains("Test &lt;run&gt; &amp; path"))
        XCTAssertTrue(xml.contains("Simulated track"))
        XCTAssertFalse(xml.contains("<wpt"))
        XCTAssertFalse(xml.contains("<ele>"))
        XCTAssertFalse(xml.contains("<rte"))
        XCTAssertTrue(xml.contains("2026-09-27T15:30:00.000000Z"))
        let points = try GPXDocument.importPoints(data)
        XCTAssertTrue([a, b, c].allSatisfy(points.contains))
        let timestamps = timestampStrings(xml)
        XCTAssertGreaterThan(timestamps.count, 2)
        XCTAssertTrue(zip(timestamps, timestamps.dropFirst()).allSatisfy { $1 > $0 })
    }

    func testSeparateGPXFormatsAndStationaryValidation() throws {
        let route = try RouteGeometry(points: [a, b, c])
        let planned = try GPXDocument.export(route: route, format: .route, name: "Plan", startTime: Date(timeIntervalSince1970: -.infinity), speedKPH: .nan)
        XCTAssertFalse(String(decoding: planned, as: UTF8.self).contains("<time>"))
        XCTAssertEqual(try GPXDocument.importPoints(planned), [a, b, c])
        let stationary = try RouteGeometry(points: [a])
        XCTAssertThrowsError(try GPXDocument.export(route: stationary, format: .track, name: "Fixed", mode: .stationary))
        let xcode = try GPXDocument.export(route: stationary, format: .xcode, name: "Fixed", mode: .stationary)
        XCTAssertTrue(String(decoding: xcode, as: UTF8.self).contains("<wpt"))
        XCTAssertEqual(try GPXDocument.importPoints(xcode), [a])
    }

    func testGPXInputValidationAndSizeBounds() throws {
        let route = try RouteGeometry(points: [a, b])
        for speed in [Double.nan, .infinity, 0, 250.01] {
            XCTAssertThrowsError(try GPXDocument.export(route: route, format: .track, name: "Run", speedKPH: speed))
        }
        for name in ["", " ", String(repeating: "a", count: 101), "bad\0name"] {
            XCTAssertThrowsError(try GPXDocument.export(route: route, format: .track, name: name))
        }
        XCTAssertThrowsError(try GPXDocument.export(route: route, format: .track, name: "Run", startTime: Date(timeIntervalSince1970: -1)))
        XCTAssertThrowsError(try GPXDocument.export(route: RouteGeometry(points: [.init(latitude: 0, longitude: 0), .init(latitude: 0, longitude: 90)]), format: .track, name: "Long", speedKPH: 0.1))
        let points = (0..<30_000).map { RoutePoint(latitude: 0, longitude: Double($0) * 0.00000002) }
        let maximum = try GPXDocument.export(route: RouteGeometry(points: points), format: .track, name: "Tiny", speedKPH: 250)
        XCTAssertLessThan(maximum.count, GPXDocument.maximumBytes)
        let timestamps = timestampStrings(String(decoding: maximum, as: UTF8.self))
        XCTAssertEqual(timestamps.count, 30_000)
        XCTAssertTrue(zip(timestamps, timestamps.dropFirst()).allSatisfy { $1 > $0 })
        XCTAssertEqual(try GPXDocument.importPoints(maximum).count, 30_000)
    }

    func testGPXImportRejectsUnsafeMalformedDisconnectedAndOversizedFiles() throws {
        let files = [
            "<hello/>",
            "<gpx><wpt lat='nan' lon='1'/></gpx>",
            "<gpx><wpt lat='1' lon='1'></gpx>",
            "<!DOCTYPE gpx [<!ENTITY x '0'>]><gpx><wpt lat='&x;' lon='1'/></gpx>",
            "<gpx><trk><trkseg><trkpt lat='1' lon='1'/></trkseg><trkseg><trkpt lat='2' lon='2'/></trkseg></trk></gpx>",
            "<gpx><rte><rtept lat='1' lon='1'/></rte><rte><rtept lat='2' lon='2'/></rte></gpx>"
        ]
        for file in files { XCTAssertThrowsError(try GPXDocument.importPoints(Data(file.utf8)), file) }
        XCTAssertThrowsError(try GPXDocument.importPoints(Data(repeating: 32, count: GPXDocument.maximumBytes + 1)))
    }

    func testGPXImportChoosesTrackAndDownsamplesCheckpoints() throws {
        let points = (0..<50).map { RoutePoint(latitude: 0, longitude: Double($0) / 100) }
        let data = try GPXDocument.export(route: RouteGeometry(points: points), format: .route, name: "Plan")
        let checkpoints = try GPXDocument.importCheckpoints(data)
        XCTAssertEqual(checkpoints.count, 24)
        XCTAssertEqual(checkpoints.first, points.first)
        XCTAssertEqual(checkpoints.last, points.last)
        let dual = "<gpx><wpt lat='9' lon='9'/><trk><trkseg><trkpt lat='1' lon='2'/><trkpt lat='3' lon='4'/></trkseg></trk></gpx>"
        XCTAssertEqual(try GPXDocument.importPoints(Data(dual.utf8)), [.init(latitude: 1, longitude: 2), .init(latitude: 3, longitude: 4)])
        XCTAssertThrowsError(try GPXDocument.importCheckpoints(data, maxCheckpoints: 0))
        XCTAssertEqual(GPXDocument.filename("../Park & Path/"), "Park-Path.gpx")
    }

    func testLegacyDualRepresentationDoesNotCountSameTrackTwice() throws {
        let points = (0..<16_000).map { "lat='0' lon='\(Double($0) / 100_000)'" }
        let xml = "<gpx>" + points.map { "<wpt \($0)/>" }.joined() + "<trk><trkseg>" + points.map { "<trkpt \($0)/>" }.joined() + "</trkseg></trk></gpx>"
        XCTAssertLessThan(Data(xml.utf8).count, GPXDocument.maximumBytes)
        XCTAssertEqual(try GPXDocument.importPoints(Data(xml.utf8)).count, 16_000)
    }

    private func timestampStrings(_ xml: String) -> [String] {
        // Metadata repeats the start timestamp; inspect point timestamps only.
        let content = xml.components(separatedBy: "</metadata>").last ?? ""
        return content.components(separatedBy: "<time>").dropFirst().map { $0.components(separatedBy: "</time>")[0] }
    }
}
