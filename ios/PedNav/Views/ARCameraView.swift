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

// MARK: - Arrow Overlay View

final class AROverlayView: UIView {

    var directionIcon: String = "↑" { didSet { setNeedsDisplay() } }
    var instruction: String = "" { didSet { instructionLabel.text = instruction } }
    var onPrev: (() -> Void)?
    var onNext: (() -> Void)?

    // Pulsing ring layer
    private let pulseLayer = CAShapeLayer()
    private let instructionLabel = UILabel()
    private let prevButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let stepCountLabel = UILabel()
    var stepText: String = "" { didSet { stepCountLabel.text = stepText } }

    // Mini-map
    var miniMapImage: UIImage? { didSet { miniMapImageView.image = miniMapImage } }
    private let miniMapImageView = UIImageView()
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

        // Instruction label
        instructionLabel.textColor     = .white
        instructionLabel.font          = UIFont.systemFont(ofSize: 18, weight: .semibold)
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 2
        instructionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        instructionLabel.layer.cornerRadius = 10
        instructionLabel.layer.masksToBounds = true
        addSubview(instructionLabel)

        // Prev button
        prevButton.setTitle("← Prev", for: .normal)
        prevButton.setTitleColor(.white, for: .normal)
        prevButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        prevButton.backgroundColor = UIColor(red: 0x1C/255.0, green: 0x1F/255.0, blue: 0x23/255.0, alpha: 0.85)
        prevButton.layer.cornerRadius = 10
        prevButton.addTarget(self, action: #selector(prevTapped), for: .touchUpInside)
        addSubview(prevButton)

        // Next button
        nextButton.setTitle("Next →", for: .normal)
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        nextButton.backgroundColor = UIColor(red: 0x21/255.0, green: 0x96/255.0, blue: 0xF3/255.0, alpha: 0.9)
        nextButton.layer.cornerRadius = 10
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        addSubview(nextButton)

        // Step count label
        stepCountLabel.textColor     = UIColor(white: 1, alpha: 0.7)
        stepCountLabel.font          = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        stepCountLabel.textAlignment = .center
        addSubview(stepCountLabel)

        // Mini-map container
        miniMapContainer.backgroundColor = UIColor(red: 0x1C/255.0, green: 0x1F/255.0, blue: 0x23/255.0, alpha: 0.85)
        miniMapContainer.layer.cornerRadius = 12
        miniMapContainer.layer.masksToBounds = true
        miniMapContainer.layer.borderColor = UIColor(white: 1, alpha: 0.2).cgColor
        miniMapContainer.layer.borderWidth = 1
        addSubview(miniMapContainer)

        miniMapImageView.contentMode = .scaleAspectFill
        miniMapImageView.clipsToBounds = true
        miniMapContainer.addSubview(miniMapImageView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        let h = bounds.height

        // Arrow drawn in draw(_:) — center area
        let arrowSize: CGFloat = 100

        // Instruction label near bottom
        let lblH: CGFloat = 60
        instructionLabel.frame = CGRect(x: 20, y: h - 170, width: w - 40, height: lblH)

        // Buttons
        let btnW: CGFloat = 110
        let btnH: CGFloat = 44
        let btnY = h - 95
        prevButton.frame = CGRect(x: 20, y: btnY, width: btnW, height: btnH)
        nextButton.frame = CGRect(x: w - btnW - 20, y: btnY, width: btnW, height: btnH)

        // Step count
        stepCountLabel.frame = CGRect(x: (w - 120) / 2, y: btnY + 8, width: 120, height: 28)

        // Mini-map top-right
        let mmSize: CGFloat = 150
        miniMapContainer.frame = CGRect(x: w - mmSize - 16, y: 16, width: mmSize, height: mmSize)
        miniMapImageView.frame = miniMapContainer.bounds
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let cx = rect.midX
        let cy = rect.midY - 30 // slightly above center
        let arrowLen: CGFloat = 70
        let arrowHeadLen: CGFloat = 22
        let arrowHeadWidth: CGFloat = 18

        let angle = angleForIcon(directionIcon)

        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        ctx.rotate(by: angle)

        // Pulsing circle (static in draw; animation added separately)
        let pulseRadius: CGFloat = 56
        ctx.setStrokeColor(UIColor(red: 0x21/255.0, green: 0x96/255.0, blue: 0xF3/255.0, alpha: 0.3).cgColor)
        ctx.setLineWidth(3)
        ctx.addEllipse(in: CGRect(x: -pulseRadius, y: -pulseRadius,
                                  width: pulseRadius * 2, height: pulseRadius * 2))
        ctx.strokePath()

        // Arrow shaft
        let shaftW: CGFloat = 8
        ctx.setFillColor(UIColor(red: 0x21/255.0, green: 0x96/255.0, blue: 0xF3/255.0, alpha: 1).cgColor)

        let shaftRect = CGRect(x: -shaftW / 2, y: -arrowLen / 2 + arrowHeadLen / 2,
                               width: shaftW, height: arrowLen - arrowHeadLen)
        let shaftPath = UIBezierPath(roundedRect: shaftRect, cornerRadius: 3)
        ctx.addPath(shaftPath.cgPath)
        ctx.fillPath()

        // Arrow head (triangle)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 0, y: -arrowLen / 2))
        ctx.addLine(to: CGPoint(x: -arrowHeadWidth / 2, y: -arrowLen / 2 + arrowHeadLen))
        ctx.addLine(to: CGPoint(x:  arrowHeadWidth / 2, y: -arrowLen / 2 + arrowHeadLen))
        ctx.closePath()
        ctx.setFillColor(UIColor(red: 0x21/255.0, green: 0x96/255.0, blue: 0xF3/255.0, alpha: 1).cgColor)
        ctx.fillPath()

        ctx.restoreGState()
    }

    private func angleForIcon(_ icon: String) -> CGFloat {
        switch icon {
        case "↑", "▶": return 0
        case "↓":       return .pi
        case "←":       return -.pi / 2
        case "→":       return  .pi / 2
        case "↗":       return  .pi / 4
        case "↖":       return -.pi / 4
        case "↘":       return  .pi * 3 / 4
        case "↙":       return -.pi * 3 / 4
        default:        return 0
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

        // We'll animate a dedicated ring layer
        setupPulseLayer()
        pulseLayer.add(group, forKey: "pulse")
    }

    private func setupPulseLayer() {
        if pulseLayer.superlayer != nil { return }
        let cx = bounds.midX
        let cy = bounds.midY - 30
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
        uiView.instruction = instruction
        uiView.stepText    = stepText
    }
}

// MARK: - ARCameraView (SwiftUI)

struct ARCameraView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @StateObject private var cameraSession = CameraSessionManager()

    var body: some View {
        ZStack {
            // Camera feed
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

            // AR Overlay
            AROverlayRepresentable(
                directionIcon: viewModel.currentStep?.directionIcon ?? "↑",
                instruction:   viewModel.currentStep?.instruction ?? "No active route",
                stepText:      stepCountText,
                onPrev:        { viewModel.prevStep() },
                onNext:        { viewModel.nextStep() }
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
