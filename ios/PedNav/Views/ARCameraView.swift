import SwiftUI
import AVFoundation
import CoreMotion

// MARK: - Camera preview layer wrapper

final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    func setSession(_ session: AVCaptureSession) {
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }
}

// MARK: - Live Mini-map View

final class MiniMapLiveView: UIView {

    var route: [String] = []             { didSet { setNeedsDisplay() } }
    var nodeMap: [String: MapNode] = [:] { didSet { setNeedsDisplay() } }
    var mapImage: UIImage?               { didSet { setNeedsDisplay() } }
    var currentStepIndex: Int = 0        { didSet { setNeedsDisplay() } }
    var steps: [NavStep] = []            { didSet { setNeedsDisplay() } }
    var directionIcon: String = "↑"      { didSet { setNeedsDisplay() } }

    private var pulsePhase: CGFloat = 0
    private var timer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow != nil {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                self?.pulsePhase = CGFloat(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1.0))
                self?.setNeedsDisplay()
            }
        } else {
            timer?.invalidate()
            timer = nil
        }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let W = rect.width, H = rect.height

        // Dark background
        ctx.setFillColor(UIColor(red: 0x0A/255.0, green: 0x0D/255.0, blue: 0x11/255.0, alpha: 1).cgColor)
        ctx.fill(rect)

        let rNodes = route.compactMap { nodeMap[$0] }
        guard rNodes.count >= 2 else { return }

        // Bounding box + 22% padding (matches web prototype exactly)
        var x0 = rNodes.map(\.x).min()!, y0 = rNodes.map(\.y).min()!
        var x1 = rNodes.map(\.x).max()!, y1 = rNodes.map(\.y).max()!
        let span = max(x1 - x0, y1 - y0, 50)
        let pad  = span * 0.22 + 20
        x0 -= pad; y0 -= pad; x1 += pad; y1 += pad

        let sc = min(W / (x1 - x0), H / (y1 - y0))
        let ox = (W - (x1 - x0) * sc) / 2 - x0 * sc
        let oy = (H - (y1 - y0) * sc) / 2 - y0 * sc

        func mm(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * sc + ox, y: y * sc + oy)
        }

        // Cropped map image at 65% opacity
        if let img = mapImage, let cgImg = img.cgImage {
            let iw = CGFloat(cgImg.width), ih = CGFloat(cgImg.height)
            let sx = max(0, x0), sy = max(0, y0)
            let sw = min(iw, x1) - sx, sh = min(ih, y1) - sy
            if sw > 0 && sh > 0 {
                let dp = mm(sx, sy)
                img.draw(in: CGRect(x: dp.x, y: dp.y, width: sw * sc, height: sh * sc),
                         blendMode: .normal, alpha: 0.65)
            }
        }

        // Route edges
        ctx.setStrokeColor(UIColor(red: 0x21/255.0, green: 0x96/255.0, blue: 0xF3/255.0, alpha: 0.75).cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineCap(.round)
        for i in 0..<(rNodes.count - 1) {
            let a = mm(rNodes[i].x, rNodes[i].y)
            let b = mm(rNodes[i+1].x, rNodes[i+1].y)
            ctx.move(to: a); ctx.addLine(to: b); ctx.strokePath()
        }

        // Route node dots
        for n in rNodes {
            let p = mm(n.x, n.y)
            ctx.setFillColor(UIColor(red: 0x21/255.0, green: 0x96/255.0, blue: 0xF3/255.0, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4))
        }

        // From marker (green)
        if let fromNode = nodeMap[route.first ?? ""] {
            let p = mm(fromNode.x, fromNode.y)
            ctx.setFillColor(UIColor(red: 0x4C/255.0, green: 0xAF/255.0, blue: 0x50/255.0, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9))
            ctx.setStrokeColor(UIColor.white.cgColor); ctx.setLineWidth(1)
            ctx.strokeEllipse(in: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9))
        }

        // To marker (red)
        if let toNode = nodeMap[route.last ?? ""] {
            let p = mm(toNode.x, toNode.y)
            ctx.setFillColor(UIColor(red: 0xF4/255.0, green: 0x43/255.0, blue: 0x36/255.0, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9))
            ctx.setStrokeColor(UIColor.white.cgColor); ctx.setLineWidth(1)
            ctx.strokeEllipse(in: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9))
        }

        // Current step: pulsing ring + highlighted dot + direction arrow
        guard currentStepIndex < steps.count,
              let curNode = nodeMap[steps[currentStepIndex].nodeId] else { return }
        let p = mm(curNode.x, curNode.y)

        // Pulsing ring (animates 0→1 per second)
        let pulseR = CGFloat(7 + pulsePhase * 7)
        let pulseA = CGFloat(0.55 * (1 - pulsePhase))
        ctx.setStrokeColor(UIColor(red: 0x64/255.0, green: 0xB5/255.0, blue: 0xF6/255.0, alpha: pulseA).cgColor)
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: CGRect(x: p.x - pulseR, y: p.y - pulseR, width: pulseR * 2, height: pulseR * 2))

        // Glowing dot
        ctx.setShadow(offset: .zero, blur: 10,
                      color: UIColor(red: 0x21/255.0, green: 0x96/255.0, blue: 0xF3/255.0, alpha: 1).cgColor)
        ctx.setFillColor(UIColor(red: 0x64/255.0, green: 0xB5/255.0, blue: 0xF6/255.0, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12))
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        ctx.setStrokeColor(UIColor.white.cgColor); ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12))

        // Direction arrow pointing where to go
        let ang = arrowAngle(directionIcon)
        ctx.saveGState()
        ctx.translateBy(x: p.x, y: p.y)
        ctx.rotate(by: ang)
        ctx.setShadow(offset: .zero, blur: 6,
                      color: UIColor(red: 0x21/255.0, green: 0x96/255.0, blue: 0xF3/255.0, alpha: 1).cgColor)
        ctx.beginPath()
        ctx.move(to:    CGPoint(x: 0,  y: -16))
        ctx.addLine(to: CGPoint(x: 4,  y: -8))
        ctx.addLine(to: CGPoint(x: 0,  y: -11))
        ctx.addLine(to: CGPoint(x: -4, y: -8))
        ctx.closePath()
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fillPath()
        ctx.restoreGState()
    }

    private func arrowAngle(_ icon: String) -> CGFloat {
        switch icon {
        case "↑":  return 0
        case "↗":  return .pi / 4
        case "→":  return .pi / 2
        case "↘":  return 3 * .pi / 4
        case "↓":  return .pi
        case "↙":  return 5 * .pi / 4
        case "←":  return -.pi / 2
        case "↖":  return -.pi / 4
        default:   return 0
        }
    }
}

// MARK: - Arrow Overlay View

final class AROverlayView: UIView {

    var directionIcon: String = "↑" {
        didSet {
            setNeedsDisplay()
            directionLabel.text = simplifiedLabel(directionIcon)
            miniMapView.directionIcon = directionIcon
        }
    }
    var instruction: String = "" { didSet { instructionLabel.text = instruction } }
    var onPrev: (() -> Void)?
    var onNext: (() -> Void)?

    // Pulsing ring layer
    private let pulseLayer = CAShapeLayer()
    private let directionLabel = UILabel()
    private let instructionLabel = UILabel()
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let stepCountLabel = UILabel()
    var stepText: String = "" { didSet { stepCountLabel.text = stepText } }

    // Live mini-map
    let miniMapView = MiniMapLiveView()
    private let miniMapContainer = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSubviews()
    }

    private func setupSubviews() {
        backgroundColor = .clear

        directionLabel.textColor     = .white
        directionLabel.font          = UIFont.systemFont(ofSize: 22, weight: .bold)
        directionLabel.textAlignment = .center
        directionLabel.text          = "Go Straight"
        addSubview(directionLabel)

        instructionLabel.textColor     = UIColor(white: 0.85, alpha: 1)
        instructionLabel.font          = UIFont.systemFont(ofSize: 15, weight: .regular)
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 2
        instructionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        instructionLabel.layer.cornerRadius = 10
        instructionLabel.layer.masksToBounds = true
        addSubview(instructionLabel)

        prevButton.setTitle("← Prev", for: .normal)
        prevButton.setTitleColor(.white, for: .normal)
        prevButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        prevButton.backgroundColor = UIColor(red: 0x1C/255.0, green: 0x1F/255.0, blue: 0x23/255.0, alpha: 0.85)
        prevButton.layer.cornerRadius = 10
        prevButton.addTarget(self, action: #selector(prevTapped), for: .touchUpInside)
        addSubview(prevButton)

        nextButton.setTitle("Next →", for: .normal)
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        nextButton.backgroundColor = UIColor(red: 0x21/255.0, green: 0x96/255.0, blue: 0xF3/255.0, alpha: 0.9)
        nextButton.layer.cornerRadius = 10
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        addSubview(nextButton)

        stepCountLabel.textColor     = UIColor(white: 1, alpha: 0.7)
        stepCountLabel.font          = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        stepCountLabel.textAlignment = .center
        addSubview(stepCountLabel)

        // Mini-map container with rounded corners + border
        miniMapContainer.backgroundColor = UIColor(red: 0x1C/255.0, green: 0x1F/255.0, blue: 0x23/255.0, alpha: 0.85)
        miniMapContainer.layer.cornerRadius = 12
        miniMapContainer.layer.masksToBounds = true
        miniMapContainer.layer.borderColor = UIColor(white: 1, alpha: 0.2).cgColor
        miniMapContainer.layer.borderWidth = 1
        addSubview(miniMapContainer)

        miniMapContainer.addSubview(miniMapView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        let h = bounds.height

        let arrowCenterY = h / 2 - 40

        let dirH: CGFloat = 30
        directionLabel.frame = CGRect(x: 20, y: arrowCenterY - 90, width: w - 40, height: dirH)

        let lblH: CGFloat = 50
        instructionLabel.frame = CGRect(x: 20, y: arrowCenterY + 80, width: w - 40, height: lblH)

        let btnW: CGFloat = 110
        let btnH: CGFloat = 44
        let btnY = h - 90
        prevButton.frame = CGRect(x: 20, y: btnY, width: btnW, height: btnH)
        nextButton.frame = CGRect(x: w - btnW - 20, y: btnY, width: btnW, height: btnH)

        stepCountLabel.frame = CGRect(x: (w - 120) / 2, y: btnY + 8, width: 120, height: 28)

        let mmSize: CGFloat = 160
        miniMapContainer.frame = CGRect(x: w - mmSize - 16, y: 16, width: mmSize, height: mmSize)
        miniMapView.frame = miniMapContainer.bounds
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let cx = rect.midX
        let cy = rect.height / 2 - 40
        let arrowLen: CGFloat = 70
        let arrowHeadLen: CGFloat = 22
        let arrowHeadWidth: CGFloat = 18

        let angle = simplifiedAngle(directionIcon)

        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        ctx.rotate(by: angle)

        let pulseRadius: CGFloat = 56
        ctx.setStrokeColor(UIColor(red: 0x21/255.0, green: 0x96/255.0, blue: 0xF3/255.0, alpha: 0.3).cgColor)
        ctx.setLineWidth(3)
        ctx.addEllipse(in: CGRect(x: -pulseRadius, y: -pulseRadius,
                                  width: pulseRadius * 2, height: pulseRadius * 2))
        ctx.strokePath()

        let shaftW: CGFloat = 8
        ctx.setFillColor(UIColor(red: 0x21/255.0, green: 0x96/255.0, blue: 0xF3/255.0, alpha: 1).cgColor)

        let shaftRect = CGRect(x: -shaftW / 2, y: -arrowLen / 2 + arrowHeadLen / 2,
                               width: shaftW, height: arrowLen - arrowHeadLen)
        let shaftPath = UIBezierPath(roundedRect: shaftRect, cornerRadius: 3)
        ctx.addPath(shaftPath.cgPath)
        ctx.fillPath()

        ctx.beginPath()
        ctx.move(to: CGPoint(x: 0, y: -arrowLen / 2))
        ctx.addLine(to: CGPoint(x: -arrowHeadWidth / 2, y: -arrowLen / 2 + arrowHeadLen))
        ctx.addLine(to: CGPoint(x:  arrowHeadWidth / 2, y: -arrowLen / 2 + arrowHeadLen))
        ctx.closePath()
        ctx.setFillColor(UIColor(red: 0x21/255.0, green: 0x96/255.0, blue: 0xF3/255.0, alpha: 1).cgColor)
        ctx.fillPath()

        ctx.restoreGState()
    }

    private func simplifiedAngle(_ icon: String) -> CGFloat {
        switch icon {
        case "←", "↙", "↖": return -.pi / 2
        case "→", "↘", "↗": return  .pi / 2
        default:              return 0
        }
    }

    private func simplifiedLabel(_ icon: String) -> String {
        switch icon {
        case "←", "↙", "↖": return "Turn Left"
        case "→", "↘", "↗": return "Turn Right"
        case "▶":             return "Start"
        case "⚑":             return "Arrived"
        default:              return "Go Straight"
        }
    }

    func startPulseAnimation() {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 0.95
        pulse.toValue   = 1.15
        pulse.duration  = 1.2
        pulse.autoreverses = true
        pulse.repeatCount  = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.6
        fade.toValue   = 0.1
        fade.duration  = 1.2
        fade.autoreverses = true
        fade.repeatCount  = .infinity

        let group = CAAnimationGroup()
        group.animations = [pulse, fade]
        group.duration   = 1.2
        group.repeatCount = .infinity

        setupPulseLayer()
        pulseLayer.add(group, forKey: "pulse")
    }

    private func setupPulseLayer() {
        if pulseLayer.superlayer != nil { return }
        let cx = bounds.midX
        let cy = bounds.height / 2 - 40
        let r: CGFloat = 56
        pulseLayer.path = UIBezierPath(ovalIn: CGRect(x: cx - r, y: cy - r,
                                                      width: r * 2, height: r * 2)).cgPath
        pulseLayer.fillColor = UIColor.clear.cgColor
        pulseLayer.strokeColor = UIColor(red: 0x21/255.0, green: 0x96/255.0,
                                          blue: 0xF3/255.0, alpha: 0.4).cgColor
        pulseLayer.lineWidth = 3
        layer.addSublayer(pulseLayer)
    }

    @objc private func prevTapped() { onPrev?() }
    @objc private func nextTapped() { onNext?() }
}

// MARK: - Camera session manager

final class CameraSessionManager: ObservableObject {
    let session = AVCaptureSession()
    @Published var isAuthorized = false

    func configure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted { DispatchQueue.main.async { self?.startSession() } }
            }
        default:
            break
        }
    }

    private func startSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                    for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async { self?.isAuthorized = true }
        }
    }

    func stop() {
        session.stopRunning()
    }
}

// MARK: - UIViewRepresentable for camera

struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewView {
        let v = CameraPreviewView()
        v.setSession(session)
        return v
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {}
}

// MARK: - AR Overlay representable

struct AROverlayRepresentable: UIViewRepresentable {
    var directionIcon: String
    var instruction: String
    var stepText: String
    var route: [String]
    var nodeMap: [String: MapNode]
    var mapImage: UIImage?
    var currentStepIndex: Int
    var steps: [NavStep]
    var onPrev: () -> Void
    var onNext: () -> Void

    func makeUIView(context: Context) -> AROverlayView {
        let v = AROverlayView()
        v.onPrev = onPrev
        v.onNext = onNext
        v.startPulseAnimation()
        return v
    }

    func updateUIView(_ uiView: AROverlayView, context: Context) {
        if uiView.directionIcon != directionIcon {
            uiView.directionIcon = directionIcon
        }
        uiView.instruction   = instruction
        uiView.stepText      = stepText
        uiView.miniMapView.route            = route
        uiView.miniMapView.nodeMap          = nodeMap
        uiView.miniMapView.mapImage         = mapImage
        uiView.miniMapView.currentStepIndex = currentStepIndex
        uiView.miniMapView.steps            = steps
        uiView.miniMapView.directionIcon    = directionIcon
    }
}

// MARK: - ARCameraView (SwiftUI)

struct ARCameraView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @StateObject private var cameraSession = CameraSessionManager()

    var body: some View {
        ZStack {
            if cameraSession.isAuthorized {
                CameraPreviewRepresentable(session: cameraSession.session)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "camera.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.5))
                    Text("Camera access required")
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            AROverlayRepresentable(
                directionIcon:    viewModel.currentStep?.directionIcon ?? "↑",
                instruction:      viewModel.currentStep?.instruction ?? "No active route",
                stepText:         stepCountText,
                route:            viewModel.route,
                nodeMap:          viewModel.nodeMap,
                mapImage:         viewModel.mapImage,
                currentStepIndex: viewModel.currentStepIndex,
                steps:            viewModel.steps,
                onPrev:           { viewModel.prevStep() },
                onNext:           { viewModel.nextStep() }
            )
            .ignoresSafeArea()
        }
        .onAppear  { cameraSession.configure() }
        .onDisappear { cameraSession.stop() }
    }

    private var stepCountText: String {
        guard !viewModel.steps.isEmpty else { return "" }
        return "Step \(viewModel.currentStepIndex + 1) of \(viewModel.steps.count)"
    }
}
