import UIKit
import SwiftUI

// MARK: - UIView subclass

final class MapCanvasView: UIView {

    // MARK: Public properties
    var mapImage: UIImage? { didSet { setNeedsDisplay() } }
    var nodes: [MapNode] = [] { didSet { setNeedsDisplay() } }
    var edges: [(from: String, to: String)] = [] { didSet { setNeedsDisplay() } }
    var route: [String] = [] { didSet { setNeedsDisplay() } }
    var fromNodeId: String? { didSet { setNeedsDisplay() } }
    var toNodeId: String? { didSet { setNeedsDisplay() } }
    var filterType: String = "all" { didSet { setNeedsDisplay() } }
    var showLabels: Bool = true      { didSet { setNeedsDisplay() } }
    var nodeMap: [String: MapNode] = [:]

    var onNodeTapped: ((MapNode) -> Void)?

    // MARK: Pan / Zoom state
    private var panOffset: CGPoint = .zero
    private var zoom: CGFloat = 1.0
    private let minZoom: CGFloat = 0.05
    private let maxZoom: CGFloat = 5.0

    // State for gesture recognizers
    private var lastPanOffset: CGPoint = .zero
    private var lastZoom: CGFloat = 1.0

    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = UIColor(red: 0x11/255.0, green: 0x14/255.0, blue: 0x16/255.0, alpha: 1)
        isOpaque = true
        contentMode = .redraw

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinch)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)

        pan.require(toFail: tap)
    }

    // MARK: Gesture handlers

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let translation = g.translation(in: self)
        switch g.state {
        case .began:
            lastPanOffset = panOffset
        case .changed, .ended:
            panOffset = CGPoint(x: lastPanOffset.x + translation.x,
                                y: lastPanOffset.y + translation.y)
            setNeedsDisplay()
        default:
            break
        }
    }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        switch g.state {
        case .began:
            lastZoom = zoom
        case .changed, .ended:
            let newZoom = (lastZoom * g.scale).clamped(to: minZoom...maxZoom)
            // Zoom toward the pinch center
            let pinchCenter = g.location(in: self)
            let zoomDelta = newZoom / zoom
            panOffset = CGPoint(
                x: pinchCenter.x - zoomDelta * (pinchCenter.x - panOffset.x),
                y: pinchCenter.y - zoomDelta * (pinchCenter.y - panOffset.y)
            )
            zoom = newZoom
            setNeedsDisplay()
        default:
            break
        }
    }

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        let screenPoint = g.location(in: self)
        let mapPoint = screenToMap(screenPoint)
        let hitRadius: CGFloat = 20.0 / zoom

        var closestNode: MapNode? = nil
        var closestDist: CGFloat = hitRadius

        let visibleNodes = filterType == "all" ? nodes : nodes.filter { $0.type == filterType }
        for node in visibleNodes {
            if zoom < 0.2 && node.type == "junction" { continue }
            let dx = node.x - mapPoint.x
            let dy = node.y - mapPoint.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < closestDist {
                closestDist = dist
                closestNode = node
            }
        }

        if let node = closestNode {
            onNodeTapped?(node)
        }
    }

    // MARK: Coordinate transforms

    private func screenToMap(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - panOffset.x) / zoom,
                y: (p.y - panOffset.y) / zoom)
    }

    private func mapToScreen(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x * zoom + panOffset.x,
                y: p.y * zoom + panOffset.y)
    }

    // MARK: Drawing

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Background
        ctx.setFillColor(UIColor(red: 0x11/255.0, green: 0x14/255.0, blue: 0x16/255.0, alpha: 1).cgColor)
        ctx.fill(rect)

        ctx.saveGState()
        ctx.translateBy(x: panOffset.x, y: panOffset.y)
        ctx.scaleBy(x: zoom, y: zoom)

        // Draw map image
        if let img = mapImage {
            img.draw(in: CGRect(origin: .zero, size: CGSize(width: CGFloat(img.cgImage?.width ?? 4900),
                                                             height: CGFloat(img.cgImage?.height ?? 7300))))
        }

        // Build route set for fast lookup
        var routeEdgeSet = Set<String>()
        if route.count > 1 {
            for i in 0..<(route.count - 1) {
                let key1 = "\(route[i])-\(route[i+1])"
                let key2 = "\(route[i+1])-\(route[i])"
                routeEdgeSet.insert(key1)
                routeEdgeSet.insert(key2)
            }
        }

        // Draw non-route edges
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        for edge in edges {
            guard let fromNode = nodeMap[edge.from],
                  let toNode = nodeMap[edge.to] else { continue }
            let isRoute = routeEdgeSet.contains("\(edge.from)-\(edge.to)")
            if !isRoute {
                ctx.setStrokeColor(UIColor(white: 1, alpha: 0.08).cgColor)
                ctx.setLineWidth(1.0 / zoom)
                ctx.move(to: CGPoint(x: fromNode.x, y: fromNode.y))
                ctx.addLine(to: CGPoint(x: toNode.x, y: toNode.y))
                ctx.strokePath()
            }
        }

        // Draw route — Google Maps style: dark border pass then bright fill pass
        if route.count > 1 {
            // Pass 1: dark shadow/border underneath
            ctx.setStrokeColor(UIColor(red: 0x0D/255.0, green: 0x47/255.0, blue: 0xA1/255.0, alpha: 0.9).cgColor)
            ctx.setLineWidth(14.0 / zoom)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            for i in 0..<(route.count - 1) {
                guard let a = nodeMap[route[i]], let b = nodeMap[route[i + 1]] else { continue }
                ctx.move(to: CGPoint(x: a.x, y: a.y))
                ctx.addLine(to: CGPoint(x: b.x, y: b.y))
                ctx.strokePath()
            }
            // Pass 2: bright blue on top
            ctx.setStrokeColor(UIColor(red: 0x21/255.0, green: 0x96/255.0, blue: 0xF3/255.0, alpha: 1).cgColor)
            ctx.setLineWidth(9.0 / zoom)
            for i in 0..<(route.count - 1) {
                guard let a = nodeMap[route[i]], let b = nodeMap[route[i + 1]] else { continue }
                ctx.move(to: CGPoint(x: a.x, y: a.y))
                ctx.addLine(to: CGPoint(x: b.x, y: b.y))
                ctx.strokePath()
            }
        }

        // Draw nodes
        let visibleNodes = filterType == "all" ? nodes : nodes.filter { $0.type == filterType }
        let labelZoomThreshold: CGFloat = 0.12  // show labels above this zoom
        let junctionZoomThreshold: CGFloat = 0.20

        for node in visibleNodes {
            if zoom < junctionZoomThreshold && node.type == "junction" { continue }

            let isFrom = node.id == fromNodeId
            let isTo   = node.id == toNodeId
            let isOnRoute = route.contains(node.id)

            // Screen-space radius capped so nodes shrink when zoomed out
            let baseScreenR: CGFloat = node.type == "junction" ? 2.5 : 4.5
            let maxScreenR: CGFloat  = isFrom || isTo ? 9.0 : (node.type == "junction" ? 3.5 : 6.0)
            let screenRadius = (isFrom || isTo)
                ? min(9.0, max(5.0, 9.0 * zoom))
                : min(maxScreenR, max(1.5, baseScreenR * min(1.0, zoom * 1.5)))
            let radius = screenRadius / zoom

            let nodeColor: UIColor
            if isFrom {
                nodeColor = UIColor(red: 0x4C/255.0, green: 0xAF/255.0, blue: 0x50/255.0, alpha: 1)
            } else if isTo {
                nodeColor = UIColor(red: 0xF4/255.0, green: 0x43/255.0, blue: 0x36/255.0, alpha: 1)
            } else {
                nodeColor = uiColorFromSwiftColor(node.color)
            }

            let nr = CGRect(x: node.x - radius, y: node.y - radius,
                            width: radius * 2, height: radius * 2)

            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            ctx.setFillColor(nodeColor.cgColor)
            ctx.fillEllipse(in: nr)

            if node.type != "junction" || isFrom || isTo {
                ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.5).cgColor)
                ctx.setLineWidth(0.8 / zoom)
                ctx.strokeEllipse(in: nr)
            }

            // A/B label for from/to
            if isFrom || isTo {
                let label = isFrom ? "A" : "B"
                let font = UIFont.boldSystemFont(ofSize: 7.0 / zoom)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
                let str = NSAttributedString(string: label, attributes: attrs)
                let strSize = str.size()
                str.draw(at: CGPoint(x: node.x - strSize.width / 2, y: node.y - strSize.height / 2))
            }

            // Name label for named nodes at sufficient zoom (only when labels enabled)
            if showLabels && zoom >= labelZoomThreshold && node.type != "junction" && !isFrom && !isTo && !node.name.isEmpty {
                let fontSize: CGFloat = 9.0 / zoom
                let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.white
                ]
                let str = NSAttributedString(string: node.name, attributes: attrs)
                let strSize = str.size()
                let labelX = node.x - strSize.width / 2
                let labelY = node.y + radius + (2.0 / zoom)

                // Pill background for readability
                let bgPad: CGFloat = 2.0 / zoom
                let bgRect = CGRect(x: labelX - bgPad, y: labelY - bgPad,
                                    width: strSize.width + bgPad * 2, height: strSize.height + bgPad * 2)
                let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: 2.0 / zoom)
                UIColor.black.withAlphaComponent(0.55).setFill()
                bgPath.fill()

                str.draw(at: CGPoint(x: labelX, y: labelY))
            }
        }

        ctx.restoreGState()
    }

    // Rough conversion — SwiftUI Color doesn't expose RGBA easily;
    // we stored the ARGB in the node's color field so we recompute here
    // Instead, we use the node type to re-derive the UIColor reliably.
    private func uiColorFromSwiftColor(_ color: Color) -> UIColor {
        // Use UIColor(color:) available on iOS 14+
        return UIColor(color)
    }

    // MARK: Fit to view
    func fitMapToView() {
        guard let img = mapImage else { return }
        let iw = CGFloat(img.cgImage?.width ?? 4900)
        let ih = CGFloat(img.cgImage?.height ?? 7300)
        let scaleX = bounds.width / iw
        let scaleY = bounds.height / ih
        zoom = min(scaleX, scaleY)
        panOffset = CGPoint(
            x: (bounds.width  - iw * zoom) / 2,
            y: (bounds.height - ih * zoom) / 2
        )
        setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if panOffset == .zero && zoom == 1.0 {
            fitMapToView()
        }
    }
}

// MARK: - Comparable extension for clamping
extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - UIViewRepresentable

struct MapCanvasRepresentable: UIViewRepresentable {
    @EnvironmentObject var viewModel: AppViewModel

    func makeUIView(context: Context) -> MapCanvasView {
        let view = MapCanvasView()
        if let url = Bundle.main.url(forResource: "map", withExtension: "jpg") {
            view.mapImage = UIImage(contentsOfFile: url.path)
        }
        view.onNodeTapped = { node in
            Task { @MainActor in
                viewModel.selectNode(node)
            }
        }
        return view
    }

    func updateUIView(_ uiView: MapCanvasView, context: Context) {
        uiView.nodes      = viewModel.filteredNodes
        uiView.route      = viewModel.route
        uiView.fromNodeId = viewModel.fromNode?.id
        uiView.toNodeId   = viewModel.toNode?.id
        uiView.filterType = viewModel.filterType
        uiView.showLabels = viewModel.showLabels

        var nodeMap: [String: MapNode] = [:]
        for n in viewModel.nodes { nodeMap[n.id] = n }
        uiView.nodeMap = nodeMap

        uiView.edges = viewModel.edges
        uiView.setNeedsDisplay()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {}
}
