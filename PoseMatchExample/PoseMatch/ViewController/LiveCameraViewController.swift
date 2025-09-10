//
//  LiveCameraViewController.swift
//  PoseMatch
//
//  Created by Shubham Kachhiya on 09/09/25.
//


import AVFoundation
import Vision
import SwiftUI
import PoseComparison

class LiveCameraViewController: UIViewController {
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var videoOutput: AVCaptureVideoDataOutput!
    private let bodyClassifier = BodyClassifier()
    private var overlayLayer: CALayer!
    
    var onFrameProcessed: ((UIImage) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupOverlay()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: backCamera) else {
            print("Unable to access camera")
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // Set the video connection orientation
        if let connection = videoOutput.connection(with: .video) {
            // 0 = up, 90 = right, 180 = down, 270 = left
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90 // Portrait
            }
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }
    
    private func setupOverlay() {
        overlayLayer = CALayer()
        overlayLayer.frame = view.layer.bounds
        view.layer.addSublayer(overlayLayer)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
        overlayLayer?.frame = view.layer.bounds
    }
    
    private func startSession() {
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }
    
    private func stopSession() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
}

// MARK: - Video Output Delegate
extension LiveCameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)
        
        let processedImage = bodyClassifier.processForOverlay(uiImage)
        
        DispatchQueue.main.async { [weak self] in
            self?.updateOverlay(with: processedImage)
            self?.onFrameProcessed?(processedImage.originalImage)
        }
    }
    
    private func updateOverlay(with result: BodyProcessingResult) {
        overlayLayer.sublayers?.removeAll()
        
        let scaleX = overlayLayer.bounds.width / result.originalImage.size.width
        let scaleY = overlayLayer.bounds.height / result.originalImage.size.height
        let scale = min(scaleX, scaleY)
        
        let imageWidth = result.originalImage.size.width * scale
        let imageHeight = result.originalImage.size.height * scale
        let offsetX = (overlayLayer.bounds.width - imageWidth) / 2
        let offsetY = (overlayLayer.bounds.height - imageHeight) / 2
        
        for path in result.openPaths {
            let pathLayer = CAShapeLayer()
            let bezierPath = UIBezierPath()
            
            for (index, point) in path.enumerated() {
                let scaledPoint = CGPoint(x: point.x * scale + offsetX,
                                        y: point.y * scale + offsetY)
                if index == 0 {
                    bezierPath.move(to: scaledPoint)
                } else {
                    bezierPath.addLine(to: scaledPoint)
                }
            }
            
            pathLayer.path = bezierPath.cgPath
            pathLayer.strokeColor = UIColor.red.cgColor
            pathLayer.lineWidth = 2
            pathLayer.fillColor = UIColor.clear.cgColor
            overlayLayer.addSublayer(pathLayer)
        }
        
        for path in result.closedPaths {
            let pathLayer = CAShapeLayer()
            let bezierPath = UIBezierPath()
            
            for (index, point) in path.enumerated() {
                let scaledPoint = CGPoint(x: point.x * scale + offsetX,
                                        y: point.y * scale + offsetY)
                if index == 0 {
                    bezierPath.move(to: scaledPoint)
                } else {
                    bezierPath.addLine(to: scaledPoint)
                }
            }
            bezierPath.close()
            
            pathLayer.path = bezierPath.cgPath
            pathLayer.strokeColor = UIColor.blue.cgColor
            pathLayer.lineWidth = 2
            pathLayer.fillColor = UIColor.clear.cgColor
            overlayLayer.addSublayer(pathLayer)
        }
        
        for point in result.points {
            let pointLayer = CAShapeLayer()
            let scaledPoint = CGPoint(x: point.x * scale + offsetX,
                                    y: point.y * scale + offsetY)
            let circlePath = UIBezierPath(arcCenter: scaledPoint,
                                        radius: 5,
                                        startAngle: 0,
                                        endAngle: .pi * 2,
                                        clockwise: true)
            
            pointLayer.path = circlePath.cgPath
            pointLayer.fillColor = UIColor.yellow.cgColor
            pointLayer.strokeColor = UIColor.red.cgColor
            pointLayer.lineWidth = 2
            overlayLayer.addSublayer(pointLayer)
        }
    }
}
