import MapKit
import SwiftUI
import RoutePilotCore
import OSLog

struct RouteMap: UIViewRepresentable {
    @ObservedObject var model: RoutePilotModel

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsCompass = true
        map.pointOfInterestFilter = .excludingAll
        map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.7694, longitude: -122.483), span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)), animated: false)
        let hold = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.dragCheckpoint(_:)))
        hold.minimumPressDuration = 0.3
        hold.allowableMovement = 12
        hold.cancelsTouchesInView = true
        hold.delegate = context.coordinator
        context.coordinator.checkpointHold = hold
        map.addGestureRecognizer(hold)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))
        tap.delegate = context.coordinator
        let doubleTap = UITapGestureRecognizer()
        doubleTap.numberOfTapsRequired = 2
        doubleTap.cancelsTouchesInView = false
        doubleTap.delegate = context.coordinator
        context.coordinator.mapDoubleTap = doubleTap
        tap.require(toFail: doubleTap)
        map.addGestureRecognizer(doubleTap)
        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let c = context.coordinator
        c.parent = self
        let existing = Dictionary(uniqueKeysWithValues: map.annotations.compactMap { $0 as? CheckpointAnnotation }.map { ($0.id, $0) })
        let ids = Set(model.checkpoints.map(\.id))
        if let draggingID = c.draggingCheckpointID, !ids.contains(draggingID) || !model.canEdit { c.cancelDrag(in: map) }
        map.removeAnnotations(existing.values.filter { !ids.contains($0.id) })
        for (index, checkpoint) in model.checkpoints.enumerated() {
            if let annotation = existing[checkpoint.id] {
                if c.draggingCheckpointID != checkpoint.id { annotation.coordinate = checkpoint.point.coordinate }
                annotation.number = index + 1
                if let view = map.view(for: annotation) as? CheckpointMarkerView {
                    view.number = index + 1
                    view.accessibilityIdentifier = "checkpoint-\(index + 1)"
                    view.accessibilityLabel = model.canEdit ? "Checkpoint \(index + 1). Tap to remove; hold and drag to move." : "Checkpoint \(index + 1). Route in progress."
                    view.isDraggable = false
                    view.removalTap?.isEnabled = model.canEdit
                }
            } else { map.addAnnotation(CheckpointAnnotation(checkpoint, number: index + 1)) }
        }
        if c.lastRoute != model.route?.points {
            map.removeOverlays(map.overlays)
            if let points = model.route?.points, points.count > 1 {
                let coords = points.map(\.coordinate)
                map.addOverlay(MKPolyline(coordinates: coords, count: coords.count))
            }
            c.lastRoute = model.route?.points
        }
        if let point = model.position {
            if let current = c.current { current.coordinate = point.coordinate } else { let current = CurrentAnnotation(); current.coordinate = point.coordinate; c.current = current; map.addAnnotation(current) }
        } else if let current = c.current { map.removeAnnotation(current); c.current = nil }
        if c.fitRevision != model.fitRevision {
            c.fitRevision = model.fitRevision
            let annotations = map.annotations
            if let overlay = map.overlays.first {
                map.setVisibleMapRect(overlay.boundingMapRect, edgePadding: UIEdgeInsets(top: 65, left: 45, bottom: 55, right: 75), animated: true)
            } else if !annotations.isEmpty { map.showAnnotations(annotations, animated: true) }
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: RouteMap
        var lastRoute: [RoutePoint]?
        var fitRevision = -1
        var current: CurrentAnnotation?
        weak var mapDoubleTap: UITapGestureRecognizer?
        weak var checkpointHold: UILongPressGestureRecognizer?
        var draggingCheckpointID: UUID?
        private var dragStartCoordinate: CLLocationCoordinate2D?
        private var dragTouchOffset = CGPoint.zero
        private var mapWasScrollable = true
        private var mapWasZoomable = true
        private var lastDragFinished: CFTimeInterval = 0
        init(_ parent: RouteMap) { self.parent = parent }

        func cancelDrag(in map: MKMapView) {
            if let annotation = map.annotations.compactMap({ $0 as? CheckpointAnnotation }).first(where: { $0.id == draggingCheckpointID }) {
                if let original = dragStartCoordinate { annotation.coordinate = original }
                map.view(for: annotation)?.alpha = 1
            }
            map.isScrollEnabled = mapWasScrollable
            map.isZoomEnabled = mapWasZoomable
            draggingCheckpointID = nil
            dragStartCoordinate = nil
            lastDragFinished = CACurrentMediaTime()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            if gestureRecognizer === checkpointHold {
                guard parent.model.canEdit, let map = gestureRecognizer.view as? MKMapView else { return false }
                let point = touch.location(in: map)
                let hit = checkpoint(at: point, in: map)
                trace("hold touch=\(point), checkpoint=\(hit?.number ?? 0)")
                return hit != nil
            }
            var view = touch.view
            while let candidate = view {
                if candidate is MKAnnotationView || candidate is UIControl { return false }
                view = candidate.superview
            }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Let MapKit's own double tap still zoom. Its two-tap gesture must
            // not also add a checkpoint through our single-tap handler.
            gestureRecognizer === mapDoubleTap || otherGestureRecognizer === mapDoubleTap ||
                gestureRecognizer === checkpointHold || otherGestureRecognizer === checkpointHold
        }

        @objc func tap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, let map = gesture.view as? MKMapView, parent.model.canEdit,
                  draggingCheckpointID == nil, CACurrentMediaTime() - lastDragFinished > 0.3 else { return }
            let coordinate = map.convert(gesture.location(in: map), toCoordinateFrom: map)
            parent.model.add(RoutePoint(latitude: coordinate.latitude, longitude: coordinate.longitude))
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is CurrentAnnotation {
                let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "current")
                view.markerTintColor = .systemOrange
                view.glyphImage = UIImage(systemName: "figure.run")
                view.displayPriority = .required
                view.accessibilityLabel = "Simulated position"
                return view
            }
            guard let checkpoint = annotation as? CheckpointAnnotation else { return nil }
            let view = CheckpointMarkerView(annotation: checkpoint, reuseIdentifier: "checkpoint")
            view.number = checkpoint.number
            // The app owns hold-and-drag instead of depending on MapKit's
            // marker selection animation to enter a native dragging state.
            view.isDraggable = false
            view.canShowCallout = false
            view.displayPriority = .required
            view.accessibilityLabel = "Checkpoint \(checkpoint.number). Tap to remove; hold and drag to move."
            view.accessibilityTraits = .button
            view.accessibilityIdentifier = "checkpoint-\(checkpoint.number)"
            let id = checkpoint.id
            view.onActivate = { [weak self] in
                guard let self, self.parent.model.canEdit else { return false }
                self.parent.model.remove(id)
                return true
            }
            let tap = UITapGestureRecognizer(target: self, action: #selector(removeCheckpoint(_:)))
            tap.cancelsTouchesInView = false
            tap.isEnabled = parent.model.canEdit
            if let hold = checkpointHold { tap.require(toFail: hold) }
            view.removalTap = tap
            view.addGestureRecognizer(tap)
            trace("created checkpoint \(checkpoint.number), draggable=\(view.isDraggable)")
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            guard let checkpoint = annotation as? CheckpointAnnotation else { return }
            trace("selected checkpoint \(checkpoint.number), draggable=\(mapView.view(for: annotation)?.isDraggable ?? false)")
        }

        @objc private func removeCheckpoint(_ gesture: UITapGestureRecognizer) {
            trace("pin tap state=\(gesture.state.rawValue), dragging=\(draggingCheckpointID != nil)")
            guard gesture.state == .ended, parent.model.canEdit,
                  let view = gesture.view as? MKAnnotationView,
                  let checkpoint = view.annotation as? CheckpointAnnotation,
                  draggingCheckpointID == nil, view.dragState == .none,
                  CACurrentMediaTime() - lastDragFinished > 0.3 else { return }
            parent.model.remove(checkpoint.id)
        }

        private func checkpoint(at point: CGPoint, in map: MKMapView) -> CheckpointAnnotation? {
            map.annotations.compactMap { $0 as? CheckpointAnnotation }.filter { annotation in
                guard let view = map.view(for: annotation), !view.isHidden, view.alpha > 0.1 else { return false }
                // A coordinate-anchored target stays stable even when MapKit's
                // annotation containers apply private layout transforms.
                let anchor = map.convert(annotation.coordinate, toPointTo: map)
                let target = CGRect(x: anchor.x - 26, y: anchor.y - 50, width: 52, height: 58)
                return target.contains(point) || view.convert(view.bounds, to: map).insetBy(dx: -4, dy: -4).contains(point)
            }.min { lhs, rhs in
                let a = map.convert(lhs.coordinate, toPointTo: map), b = map.convert(rhs.coordinate, toPointTo: map)
                return hypot(a.x - point.x, a.y - point.y) < hypot(b.x - point.x, b.y - point.y)
            }
        }

        @objc func dragCheckpoint(_ gesture: UILongPressGestureRecognizer) {
            guard let map = gesture.view as? MKMapView else { return }
            switch gesture.state {
            case .began:
                guard parent.model.canEdit, let checkpoint = checkpoint(at: gesture.location(in: map), in: map) else { return }
                draggingCheckpointID = checkpoint.id
                dragStartCoordinate = checkpoint.coordinate
                let anchor = map.convert(checkpoint.coordinate, toPointTo: map)
                let touch = gesture.location(in: map)
                dragTouchOffset = CGPoint(x: anchor.x - touch.x, y: anchor.y - touch.y)
                mapWasScrollable = map.isScrollEnabled
                mapWasZoomable = map.isZoomEnabled
                map.isScrollEnabled = false
                map.isZoomEnabled = false
                map.view(for: checkpoint)?.alpha = 0.8
                trace("explicit drag began checkpoint \(checkpoint.number)")
            case .changed:
                guard parent.model.canEdit, let id = draggingCheckpointID,
                      let checkpoint = map.annotations.compactMap({ $0 as? CheckpointAnnotation }).first(where: { $0.id == id }) else { return }
                let point = gesture.location(in: map)
                let coordinate = map.convert(CGPoint(x: point.x + dragTouchOffset.x, y: point.y + dragTouchOffset.y), toCoordinateFrom: map)
                if CLLocationCoordinate2DIsValid(coordinate) { checkpoint.coordinate = coordinate }
            case .ended:
                guard let id = draggingCheckpointID,
                      let checkpoint = map.annotations.compactMap({ $0 as? CheckpointAnnotation }).first(where: { $0.id == id }) else { return }
                // Read the final touch even if UIKit coalesced all movement into
                // the ending event of a short drag.
                let touch = gesture.location(in: map)
                let coordinate = map.convert(CGPoint(x: touch.x + dragTouchOffset.x, y: touch.y + dragTouchOffset.y), toCoordinateFrom: map)
                let point = RoutePoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let original = dragStartCoordinate
                draggingCheckpointID = nil
                dragStartCoordinate = nil
                lastDragFinished = CACurrentMediaTime()
                map.isScrollEnabled = mapWasScrollable
                map.isZoomEnabled = mapWasZoomable
                map.view(for: checkpoint)?.alpha = 1
                trace("explicit drag ended checkpoint \(checkpoint.number), lat=\(point.latitude), lon=\(point.longitude)")
                if parent.model.canEdit, point.isValid, let original,
                   RouteGeometry.distance(RoutePoint(latitude: original.latitude, longitude: original.longitude), point) > 0.001 {
                    // Mutate the draft once per completed drag, giving Undo one
                    // complete operation rather than one entry per movement.
                    parent.model.move(checkpoint.id, to: point)
                } else if let original { checkpoint.coordinate = original }
            case .cancelled, .failed:
                if draggingCheckpointID != nil { cancelDrag(in: map); trace("explicit drag cancelled") }
            default: break
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let line = MKPolylineRenderer(overlay: overlay)
            line.strokeColor = UIColor(red: 0.14, green: 0.39, blue: 0.29, alpha: 1)
            line.lineWidth = 5
            return line
        }

        private func trace(_ message: String) {
            #if DEBUG
            guard ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return }
            Logger(subsystem: "dev.zahmsiyed.RoutePilot", category: "CheckpointDrag").notice("\(message, privacy: .public)")
            print("RoutePilot fixture: \(message)")
            #endif
        }
    }
}

private final class CheckpointMarkerView: MKAnnotationView {
    var onActivate: (() -> Bool)?
    weak var removalTap: UITapGestureRecognizer?
    private let circle = UIView(frame: CGRect(x: 4, y: 4, width: 36, height: 36))
    private let label = UILabel(frame: CGRect(x: 0, y: 0, width: 36, height: 36))
    var number = 0 { didSet { label.text = String(number) } }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        bounds = CGRect(x: 0, y: 0, width: 44, height: 44)
        centerOffset = CGPoint(x: 0, y: -22)
        backgroundColor = .clear
        isAccessibilityElement = true
        circle.backgroundColor = UIColor(red: 0.14, green: 0.39, blue: 0.29, alpha: 1)
        circle.layer.cornerRadius = 18
        circle.layer.borderWidth = 3
        circle.layer.borderColor = UIColor.white.cgColor
        circle.layer.shadowColor = UIColor.black.cgColor
        circle.layer.shadowOpacity = 0.18
        circle.layer.shadowRadius = 3
        circle.layer.shadowOffset = CGSize(width: 0, height: 2)
        circle.isUserInteractionEnabled = false
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.isAccessibilityElement = false
        circle.addSubview(label)
        addSubview(circle)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func accessibilityActivate() -> Bool { onActivate?() ?? false }
}

final class CheckpointAnnotation: NSObject, MKAnnotation {
    let id: UUID
    var number: Int
    @objc dynamic var coordinate: CLLocationCoordinate2D
    @objc dynamic var title: String? { "Checkpoint \(number)" }
    init(_ checkpoint: Checkpoint, number: Int) { self.id = checkpoint.id; self.number = number; self.coordinate = checkpoint.point.coordinate }
}

final class CurrentAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate = CLLocationCoordinate2D()
}
