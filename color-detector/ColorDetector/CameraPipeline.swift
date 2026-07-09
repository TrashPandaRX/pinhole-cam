import AVFoundation
import CoreGraphics
import Foundation
import Combine

final class CameraPipeline: NSObject, ObservableObject {
    @Published private(set) var isAuthorized = false
    @Published private(set) var detectedRegions: [DetectedRegion] = []
    @Published private(set) var videoSize: CGSize = .zero
    @Published var target = ColorTarget() {
        didSet {
            stateQueue.async(flags: .barrier) { [target] in
                self.targetSnapshot = target
            }
        }
    }
    @Published var isPanelCollapsed = false
    @Published var lastError: String?

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoOutputQueue = DispatchQueue(label: "camera.video.output.queue")
    private let stateQueue = DispatchQueue(label: "camera.state.queue", attributes: .concurrent)
    private let analyzer = FrameAnalyzer()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var targetSnapshot = ColorTarget()
    private var isConfigured = false
    private var lastAnalysisTimestamp = CFAbsoluteTimeGetCurrent()
    private let portraitRotationAngle: CGFloat = 90

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            configureAndStartIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.configureAndStartIfNeeded()
                    } else {
                        self?.lastError = "Camera access was denied."
                    }
                }
            }
        case .denied, .restricted:
            isAuthorized = false
            lastError = "Enable camera access in Settings to use live color detection."
        @unknown default:
            isAuthorized = false
            lastError = "The camera authorization state is unavailable."
        }
    }

    func stop() {
        sessionQueue.async {
            guard self.session.isRunning else {
                return
            }

            self.session.stopRunning()
        }
    }

    private func configureAndStartIfNeeded() {
        sessionQueue.async {
            if !self.isConfigured {
                self.configureSession()
            }

            guard self.isConfigured, !self.session.isRunning else {
                return
            }

            self.session.startRunning()
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high
        defer { session.commitConfiguration() }

        do {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                publishError("The back camera is unavailable on this device.")
                return
            }

            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                publishError("The camera input could not be added to the capture session.")
                return
            }
            session.addInput(input)

            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)

            guard session.canAddOutput(videoOutput) else {
                publishError("The video output could not be added to the capture session.")
                return
            }
            session.addOutput(videoOutput)

            if let connection = videoOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(portraitRotationAngle) {
                connection.videoRotationAngle = portraitRotationAngle
            }

            isConfigured = true
        } catch {
            publishError("Camera configuration failed: \(error.localizedDescription)")
        }
    }

    private func publishError(_ message: String) {
        DispatchQueue.main.async {
            self.lastError = message
        }
    }
}

extension CameraPipeline: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastAnalysisTimestamp >= (1 / 12) else {
            return
        }
        lastAnalysisTimestamp = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let target = stateQueue.sync { targetSnapshot }
        let detected = analyzer.analyze(pixelBuffer: pixelBuffer, target: target)
        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))

        DispatchQueue.main.async {
            self.videoSize = size
            self.detectedRegions = detected
        }
    }
}
