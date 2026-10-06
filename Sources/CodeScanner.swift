import SwiftUI
import AVFoundation

struct CodeScanner:View {
    var onCode:(String)->Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var allowed=false
    @State private var checked=false
    var body:some View {
        NavigationStack {
            ZStack {
                Dawn.cream.ignoresSafeArea()
                if allowed {
                    BarcodeCamera {code in onCode(code);dismiss()}
                        .overlay(alignment:.bottom) {Text("Point at a barcode or QR code.\nProcessed on device. No photos or video saved.").font(.subheadline).multilineTextAlignment(.center).padding(20).background(Dawn.cream,in:RoundedRectangle(cornerRadius:20)).padding()}
                } else if checked {
                    VStack(spacing:18) {Image(systemName:"camera.slash").font(.largeTitle);Text("Camera scanning is unavailable.").font(.headline);Text("Allow camera access in Settings, or use guided check-in.").multilineTextAlignment(.center)}
                        .padding(24)
                } else {ProgressView()}
            }.navigationTitle("Scan your destination").navigationBarTitleDisplayMode(.inline)
                .toolbar {ToolbarItem(placement:.cancellationAction) {Button("Cancel") {dismiss()}}}
        }.task {
            let status=AVCaptureDevice.authorizationStatus(for:.video)
            if status == .authorized {allowed=true}
            else if status == .notDetermined {allowed=await AVCaptureDevice.requestAccess(for:.video)}
            checked=true
        }.onChange(of:phase) {_,phase in if phase == .background {dismiss()}}
    }
}
private struct BarcodeCamera:UIViewControllerRepresentable {
    var found:(String)->Void
    func makeUIViewController(context:Context)->BarcodeController {let controller=BarcodeController();controller.found=found;return controller}
    func updateUIViewController(_ uiViewController:BarcodeController,context:Context) {}
    static func dismantleUIViewController(_ uiViewController:BarcodeController,coordinator:()) {uiViewController.stop()}
}
private final class BarcodeController:UIViewController,AVCaptureMetadataOutputObjectsDelegate {
    var found:((String)->Void)?
    private let session=AVCaptureSession()
    private let queue=DispatchQueue(label:"wake.destination.camera")
    private var layer:AVCaptureVideoPreviewLayer?
    private var delivered=false
    override func viewDidLoad() {
        super.viewDidLoad()
        let preview=AVCaptureVideoPreviewLayer(session:session);preview.videoGravity = .resizeAspectFill;view.layer.addSublayer(preview);layer=preview
        queue.async { [weak self] in
            guard let self,let device=AVCaptureDevice.default(.builtInWideAngleCamera,for:.video,position:.back),
                  let input=try? AVCaptureDeviceInput(device:device),self.session.canAddInput(input) else {return}
            self.session.beginConfiguration();self.session.addInput(input)
            let output=AVCaptureMetadataOutput()
            if self.session.canAddOutput(output) {
                self.session.addOutput(output);output.setMetadataObjectsDelegate(self,queue:.main)
                let supported:[AVMetadataObject.ObjectType]=[.qr,.ean8,.ean13,.upce,.code128,.code39,.pdf417,.aztec,.dataMatrix]
                output.metadataObjectTypes=supported.filter {output.availableMetadataObjectTypes.contains($0)}
            }
            self.session.commitConfiguration();self.session.startRunning()
        }
    }
    override func viewDidLayoutSubviews() {super.viewDidLayoutSubviews();layer?.frame=view.bounds}
    func metadataOutput(_ output:AVCaptureMetadataOutput,didOutput metadataObjects:[AVMetadataObject],from connection:AVCaptureConnection) {
        guard !delivered,let code=metadataObjects.compactMap({($0 as? AVMetadataMachineReadableCodeObject)?.stringValue}).first else {return}
        delivered=true;stop();found?(code)
    }
    func stop() {queue.async { [session] in if session.isRunning {session.stopRunning()} }}
}
