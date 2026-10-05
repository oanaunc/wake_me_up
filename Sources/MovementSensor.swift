import SwiftUI
import AVFoundation
import Vision
import CoreMotion

final class PoseCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "wake.camera")
    var onAngle: (@Sendable (Double?) -> Void)?
    var onFailure: (@Sendable (String) -> Void)?
    private var configured = false
    private var lastFrame = -Double.infinity
    func start() {
        queue.async { [self] in
            do {
                if !configured {
                    session.beginConfiguration(); defer { session.commitConfiguration() }
                    session.sessionPreset = .medium
                    guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else { throw WakeError.message("No front camera is available. Try guided counting.") }
                    let input = try AVCaptureDeviceInput(device: camera)
                    guard session.canAddInput(input) else { throw WakeError.message("Camera is unavailable. Try guided counting.") }
                    session.addInput(input)
                    let output = AVCaptureVideoDataOutput(); output.alwaysDiscardsLateVideoFrames = true
                    output.setSampleBufferDelegate(self, queue: queue)
                    guard session.canAddOutput(output) else { throw WakeError.message("Camera cannot start. Try guided counting.") }
                    session.addOutput(output); configured = true
                }
            } catch { onFailure?(error.localizedDescription); return }
            if !session.isRunning { session.startRunning() }
        }
    }
    func stop() { queue.async { [self] in if session.isRunning { session.stopRunning() } } }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastFrame >= 0.12 else { return }
        lastFrame = now
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectHumanBodyPoseRequest()
        do {
            try VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .leftMirrored).perform([request])
            guard let body = request.results?.first else { onAngle?(nil); return }
            let points = try body.recognizedPoints(.all)
            var best: (angle: Double, confidence: Float)?
            for side: [VNHumanBodyPoseObservation.JointName] in [[.leftShoulder,.leftElbow,.leftWrist,.leftHip],[.rightShoulder,.rightElbow,.rightWrist,.rightHip]] {
                guard let shoulder = points[side[0]], let elbow = points[side[1]], let wrist = points[side[2]], let hip = points[side[3]], [shoulder,elbow,wrist,hip].allSatisfy({ $0.confidence > 0.45 }) else { continue }
                // Reject upright arm curls. A push-up requires a near-horizontal torso.
                let torsoDX = abs(shoulder.location.x - hip.location.x)
                let torsoDY = abs(shoulder.location.y - hip.location.y)
                guard torsoDX > torsoDY * 1.2 else { continue }
                let a = CGVector(dx: shoulder.location.x - elbow.location.x, dy: shoulder.location.y - elbow.location.y)
                let b = CGVector(dx: wrist.location.x - elbow.location.x, dy: wrist.location.y - elbow.location.y)
                let magnitude = hypot(a.dx,a.dy) * hypot(b.dx,b.dy)
                guard magnitude > 0.001 else { continue }
                let angle = acos(min(1,max(-1,(a.dx*b.dx + a.dy*b.dy)/magnitude))) * 180 / .pi
                let confidence = min(shoulder.confidence,elbow.confidence,wrist.confidence,hip.confidence)
                if best == nil || confidence > best!.confidence { best = (angle,confidence) }
            }
            onAngle?(best?.angle)
        } catch { onAngle?(nil) }
    }
}

@MainActor @Observable
final class MovementSensor {
    var count = 0
    var status = "Ready when you are"
    var cameraActive = false
    var motionActive = false
    var moving = false
    let capture = PoseCapture()
    private let motion = CMMotionManager()
    private var counter = RepCounter()
    private var generation = UUID()
    func camera() async {
        let token = UUID(); generation = token
        let state = AVCaptureDevice.authorizationStatus(for: .video)
        var allowed = state == .authorized
        if state == .notDetermined { allowed = await AVCaptureDevice.requestAccess(for: .video) }
        guard generation == token else { return }
        guard allowed else { status = "Camera access is off. Use guided counting or enable Camera in Settings."; return }
        cameraActive = true; status = "Place the camera at your side. Start with straight arms."
        capture.onAngle = { [weak self] angle in
            Task { @MainActor in
                guard let self, self.cameraActive, self.generation == token else { return }
                self.status = angle == nil ? "Move back until your side and whole body are visible." : "Looking good. Lower, then rise."
                if self.counter.consume(angle: angle, time: Date().timeIntervalSinceReferenceDate) { self.count = self.counter.count }
            }
        }
        capture.onFailure = { [weak self] text in Task { @MainActor in guard let self, self.generation == token else { return }; self.cameraActive = false; self.status = text } }
        capture.start()
    }
    func dance() {
        guard motion.isDeviceMotionAvailable else { status = "Motion sensing is unavailable. Use guided mode."; return }
        motionActive = true; status = "Move gently with your phone held securely or in a pocket."
        motion.deviceMotionUpdateInterval = 0.1
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
            Task { @MainActor in
                guard let self, self.motionActive else { return }
                if let error { self.status = "Motion access unavailable: \(error.localizedDescription). Use guided mode."; self.stop(); return }
                guard let data else { return }
                let a = data.userAcceleration
                self.moving = sqrt(a.x*a.x + a.y*a.y + a.z*a.z) > 0.06
            }
        }
    }
    func stop() { _ = counter.consume(angle: nil, time: Date().timeIntervalSinceReferenceDate); generation = UUID(); cameraActive = false; motionActive = false; moving = false; capture.stop(); motion.stopDeviceMotionUpdates() }
}

private final class PreviewSurface: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
struct CameraPreview: UIViewRepresentable {
    var session: AVCaptureSession
    func makeUIView(context: Context) -> UIView {
        let view = PreviewSurface(); view.preview.session = session; view.preview.videoGravity = .resizeAspectFill; return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
