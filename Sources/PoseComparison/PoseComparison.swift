// The Swift Programming Language
// https://docs.swift.org/swift-book

import UIKit
import Vision

// MARK: - Protocol
public protocol ResultPointsProviding {
    func pointsProjected(onto image: UIImage) -> [CGPoint]
    func openPointGroups(projectedOnto image: UIImage) -> [[CGPoint]]
    func closedPointGroups(projectedOnto image: UIImage) -> [[CGPoint]]
}

// MARK: - BodyProcessingResult
public struct BodyProcessingResult {
    public let originalImage: UIImage
    public let openPaths: [[CGPoint]]
    public let closedPaths: [[CGPoint]]
    public let points: [CGPoint]

    public init(originalImage: UIImage,
                openPaths: [[CGPoint]],
                closedPaths: [[CGPoint]],
                points: [CGPoint]) {
        self.originalImage = originalImage
        self.openPaths = openPaths
        self.closedPaths = closedPaths
        self.points = points
    }
}

// MARK: - BodyClassifier
@available(iOS 17.0, *)
@Observable
public class BodyClassifier {
    public init() {}

    public func process(_ uiImage: UIImage) -> UIImage {
        guard let cgImage = uiImage.cgImage else {
            return UIImage()
        }

        let requests = [VNDetectHumanBodyPoseRequest(),
                        VNDetectHumanHandPoseRequest(),
                        VNDetectFaceLandmarksRequest()]

        let requestHandler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: .init(uiImage.imageOrientation),
            options: [:]
        )

        do {
            try requestHandler.perform(requests)
        } catch {
            print("Can't make the request due to \(error)")
        }

        let resultPointsProviders = requests.compactMap { $0 as? ResultPointsProviding }

        let openPointsGroups = resultPointsProviders
            .flatMap { $0.openPointGroups(projectedOnto: uiImage) }

        let closedPointsGroups = resultPointsProviders
            .flatMap { $0.closedPointGroups(projectedOnto: uiImage) }

        let points = resultPointsProviders
            .flatMap { $0.pointsProjected(onto: uiImage) }

        return uiImage.draw(openPaths: openPointsGroups,
                            closedPaths: closedPointsGroups,
                            points: points) ?? uiImage
    }

    public func processForOverlay(_ uiImage: UIImage) -> BodyProcessingResult {
        guard let cgImage = uiImage.cgImage else {
            return BodyProcessingResult(originalImage: uiImage, openPaths: [], closedPaths: [], points: [])
        }

        let requests = [VNDetectHumanBodyPoseRequest(),
                        VNDetectHumanHandPoseRequest(),
                        VNDetectFaceLandmarksRequest()]

        let requestHandler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: .init(uiImage.imageOrientation),
            options: [:]
        )

        do {
            try requestHandler.perform(requests)
        } catch {
            print("Can't make the request due to \(error)")
            return BodyProcessingResult(originalImage: uiImage, openPaths: [], closedPaths: [], points: [])
        }

        let resultPointsProviders = requests.compactMap { $0 as? ResultPointsProviding }

        let openPointsGroups = resultPointsProviders
            .flatMap { $0.openPointGroups(projectedOnto: uiImage) }

        let closedPointsGroups = resultPointsProviders
            .flatMap { $0.closedPointGroups(projectedOnto: uiImage) }

        let points = resultPointsProviders
            .flatMap { $0.pointsProjected(onto: uiImage) }

        return BodyProcessingResult(originalImage: uiImage,
                                    openPaths: openPointsGroups,
                                    closedPaths: closedPointsGroups,
                                    points: points)
    }
}


public enum PoseScoring {
    public static func calculateRobustPoseScore(livePose: BodyProcessingResult,
                                                presetPose: BodyProcessingResult,
                                                strictnessLevel: Double = 1) -> Double {
        print("=== Starting Pose Comparison ===")
        
        // Step 1: Validate and filter points
        var validPairs: [(live: CGPoint, preset: CGPoint)] = []
        let minCount = min(livePose.points.count, presetPose.points.count)
        
        guard minCount > 0 else {
            print("❌ No points to compare")
            return 0.0
        }
        
        for i in 0..<minCount {
            let livePoint = livePose.points[i]
            let presetPoint = presetPose.points[i]
            
            if isValidPoint(livePoint) && isValidPoint(presetPoint) {
                validPairs.append((live: livePoint, preset: presetPoint))
            } else {
                print("⚠️ Invalid point at index \(i): live=\(livePoint), preset=\(presetPoint)")
            }
        }
        
        guard validPairs.count >= 4 else {
            print("❌ Not enough valid points: \(validPairs.count)")
            return 0.0
        }
        
        print("✅ Valid joint pairs: \(validPairs.count)")
        
        // Step 2: Calculate pose characteristics for normalization
        let liveChar = calculatePoseCharacteristics(points: validPairs.map { $0.live })
        let presetChar = calculatePoseCharacteristics(points: validPairs.map { $0.preset })
        
        print("📊 Live pose - Center: \(liveChar.center), Scale: \(liveChar.scale)")
        print("📊 Preset pose - Center: \(presetChar.center), Scale: \(presetChar.scale)")
        
        // Step 3: Check if poses are reasonable (not collapsed to a point)
        if liveChar.scale < 10.0 || presetChar.scale < 10.0 {
            print("❌ One or both poses are too small (collapsed)")
            return 0.0
        }
        
        // Step 4: Normalize poses to same coordinate system
        let normalizedPairs = normalizePosePairs(validPairs, liveChar: liveChar, presetChar: presetChar)
        
        // Step 5: Find optimal alignment (translation + rotation + uniform scale)
        let alignment = findOptimalAlignment(pairs: normalizedPairs)
        print("🔄 Alignment - Rotation: \(alignment.rotation * 180 / .pi)°, Scale: \(alignment.scale), Translation: \(alignment.translation)")
        
        // Step 6: Apply alignment and calculate distances
        let alignedDistances = calculateAlignedDistances(pairs: normalizedPairs, alignment: alignment)
        
        // Step 7: Convert distances to scores with proper logic
        let finalScore = calculateFinalScore(distances: alignedDistances, strictness: strictnessLevel)
        
        print("🎯 Final Score: \(String(format: "%.2f", finalScore))/10")
        print("=== End Pose Comparison ===\n")
        
        return finalScore
    }
}

// MARK: - Helper Structures
private struct PoseCharacteristics {
    let center: CGPoint
    let scale: Double  // Average distance from center
    let boundingBox: CGRect
}

private struct PoseAlignment {
    let rotation: Double
    let scale: Double
    let translation: CGPoint
}

// MARK: - Validation
private func isValidPoint(_ point: CGPoint) -> Bool {
    return point.x.isFinite && point.y.isFinite &&
    !point.x.isNaN && !point.y.isNaN &&
    abs(point.x) < 10000 && abs(point.y) < 10000 &&
    point.x != 0 && point.y != 0  // Exclude points that are exactly at the origin
}

// MARK: - Pose Analysis
private func calculatePoseCharacteristics(points: [CGPoint]) -> PoseCharacteristics {
    guard !points.isEmpty else {
        return PoseCharacteristics(center: .zero, scale: 0, boundingBox: .zero)
    }
    
    let centerX = points.map { $0.x }.reduce(0, +) / CGFloat(points.count)
    let centerY = points.map { $0.y }.reduce(0, +) / CGFloat(points.count)
    let center = CGPoint(x: centerX, y: centerY)
    
    let distances = points.map { hypot(Double($0.x - center.x), Double($0.y - center.y)) }
    let scale = sqrt(distances.map { $0 * $0 }.reduce(0, +) / Double(distances.count))
    
    let minX = points.map { $0.x }.min() ?? 0
    let maxX = points.map { $0.x }.max() ?? 0
    let minY = points.map { $0.y }.min() ?? 0
    let maxY = points.map { $0.y }.max() ?? 0
    let boundingBox = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    
    return PoseCharacteristics(center: center, scale: scale, boundingBox: boundingBox)
}

// MARK: - Normalization
private func normalizePosePairs(_ pairs: [(live: CGPoint, preset: CGPoint)],
                                liveChar: PoseCharacteristics,
                                presetChar: PoseCharacteristics) -> [(live: CGPoint, preset: CGPoint)] {
    
    var normalizedPairs: [(live: CGPoint, preset: CGPoint)] = []
    
    for pair in pairs {
        let normalizedLive = CGPoint(
            x: (pair.live.x - liveChar.center.x) / CGFloat(liveChar.scale),
            y: (pair.live.y - liveChar.center.y) / CGFloat(liveChar.scale)
        )
        
        let normalizedPreset = CGPoint(
            x: (pair.preset.x - presetChar.center.x) / CGFloat(presetChar.scale),
            y: (pair.preset.y - presetChar.center.y) / CGFloat(presetChar.scale)
        )
        
        normalizedPairs.append((live: normalizedLive, preset: normalizedPreset))
    }
    
    return normalizedPairs
}

// MARK: - Optimal Alignment (Procrustes Analysis)
private func findOptimalAlignment(pairs: [(live: CGPoint, preset: CGPoint)]) -> PoseAlignment {
    let n = pairs.count
    guard n >= 2 else {
        return PoseAlignment(rotation: 0, scale: 1, translation: .zero)
    }
    
    let livePoints = pairs.map { (Double($0.live.x), Double($0.live.y)) }
    let presetPoints = pairs.map { (Double($0.preset.x), Double($0.preset.y)) }
    
    let liveCentroid = (
        livePoints.map { $0.0 }.reduce(0, +) / Double(n),
        livePoints.map { $0.1 }.reduce(0, +) / Double(n)
    )
    let presetCentroid = (
        presetPoints.map { $0.0 }.reduce(0, +) / Double(n),
        presetPoints.map { $0.1 }.reduce(0, +) / Double(n)
    )
    
    let centeredLive = livePoints.map { ($0.0 - liveCentroid.0, $0.1 - liveCentroid.1) }
    let centeredPreset = presetPoints.map { ($0.0 - presetCentroid.0, $0.1 - presetCentroid.1) }
    
    var h11 = 0.0, h12 = 0.0, h21 = 0.0, h22 = 0.0
    var sumPresetSquared = 0.0
    var sumLiveSquared = 0.0
    
    for i in 0..<n {
        let px = centeredPreset[i].0, py = centeredPreset[i].1
        let lx = centeredLive[i].0, ly = centeredLive[i].1
        
        h11 += px * lx
        h12 += px * ly
        h21 += py * lx
        h22 += py * ly
        
        sumPresetSquared += px * px + py * py
        sumLiveSquared += lx * lx + ly * ly
    }
    
    let rotation = atan2(h21 - h12, h11 + h22)
    let cosR = cos(rotation)
    let sinR = sin(rotation)
    let numerator = h11 * cosR + h12 * sinR + h21 * sinR + h22 * cosR
    let scale = (sumPresetSquared > 1e-10) ? numerator / sumPresetSquared : 1.0
    
    let translation = CGPoint(
        x: liveCentroid.0 - presetCentroid.0,
        y: liveCentroid.1 - presetCentroid.1
    )
    
    return PoseAlignment(rotation: rotation, scale: abs(scale), translation: translation)
}

// MARK: - Distance Calculation
private func calculateAlignedDistances(pairs: [(live: CGPoint, preset: CGPoint)],
                                       alignment: PoseAlignment) -> [Double] {
    var distances: [Double] = []
    
    let cosR = cos(alignment.rotation)
    let sinR = sin(alignment.rotation)
    
    for pair in pairs {
        let px = Double(pair.preset.x)
        let py = Double(pair.preset.y)
        
        let rotatedX = alignment.scale * (cosR * px - sinR * py)
        let rotatedY = alignment.scale * (sinR * px + cosR * py)
        
        let alignedX = rotatedX + Double(alignment.translation.x)
        let alignedY = rotatedY + Double(alignment.translation.y)
        
        let lx = Double(pair.live.x)
        let ly = Double(pair.live.y)
        let distance = hypot(lx - alignedX, ly - alignedY)
        
        distances.append(distance)
    }
    
    return distances
}
// MARK: - Final Scoring
private func calculateFinalScore(distances: [Double], strictness: Double) -> Double {
    guard !distances.isEmpty else { return 0.0 }
    let jointScores: [Double] = distances.map { exp(-$0 / strictness) }
    
    let meanScore = jointScores.reduce(0, +) / Double(jointScores.count)
    let minScore = jointScores.min() ?? 0.0
    
    let finalScore = 0.7 * meanScore + 0.3 * minScore
    
    let scaledScore = max(0.0, min(10.0, finalScore * 10.0))
    
    return scaledScore
}
// MARK: - Debug Function
func debugPoseComparison(livePose: BodyProcessingResult, presetPose: BodyProcessingResult) {
    print("\n🔍 DEBUG: Pose Comparison Details")
    print("Live pose points: (livePose.points.count)")
    print("Preset pose points: (presetPose.points.count)")
    
    let minCount = min(livePose.points.count, presetPose.points.count)
    for i in 0..<min(minCount, 5) {  // Show first 5 points
        let live = livePose.points[i]
        let preset = presetPose.points[i]
        let distance = hypot(Double(live.x - preset.x), Double(live.y - preset.y))
        print("Point \(i): Live(\(live.x), \(live.y)) vs Preset(\(preset.x), \(preset.y)) = distance \(distance)")
    }
    
    print("\n📊 Scores at different strictness levels:")
    for strictness in [0.05, 0.1, 0.15, 0.2, 0.3] {
        let score = PoseScoring.calculateRobustPoseScore(livePose: livePose, presetPose: presetPose, strictnessLevel: strictness)
        print("Strictness \(strictness): Score = \(String(format: "%.2f", score))")
    }
}


// MARK: - Extensions
extension CGImagePropertyOrientation {
    public init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}

@available(iOS 14.0, *)
extension VNRecognizedPoint {
    public func location(in image: UIImage) -> CGPoint {
        VNImagePointForNormalizedPoint(location,
                                       Int(image.size.width),
                                       Int(image.size.height))
    }
}

extension UIImage {
    public func draw(openPaths: [[CGPoint]]? = nil,
                     closedPaths: [[CGPoint]]? = nil,
                     points: [CGPoint]? = nil,
                     fillColor: UIColor = .white,
                     strokeColor: UIColor = .red,
                     radius: CGFloat = 5,
                     lineWidth: CGFloat = 2) -> UIImage? {
        let scale: CGFloat = 0
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(at: CGPoint.zero)

        points?.forEach { point in
            let path = UIBezierPath(arcCenter: point,
                                    radius: radius,
                                    startAngle: CGFloat(0),
                                    endAngle: CGFloat(Double.pi * 2),
                                    clockwise: true)

            fillColor.setFill()
            strokeColor.setStroke()
            path.lineWidth = lineWidth

            path.fill()
            path.stroke()
        }

        openPaths?.forEach { points in
            draw(points: points, isClosed: false, color: strokeColor, lineWidth: lineWidth)
        }

        closedPaths?.forEach { points in
            draw(points: points, isClosed: true, color: strokeColor, lineWidth: lineWidth)
        }

        let newImage = UIGraphicsGetImageFromCurrentImageContext()

        UIGraphicsEndImageContext()
        return newImage
    }

    private func draw(points: [CGPoint], isClosed: Bool, color: UIColor, lineWidth: CGFloat) {
        let bezierPath = UIBezierPath()
        bezierPath.drawLinePath(for: points, isClosed: isClosed)
        color.setStroke()
        bezierPath.lineWidth = lineWidth
        bezierPath.stroke()
    }
}

extension UIBezierPath {
    public func drawLinePath(for points: [CGPoint], isClosed: Bool) {
        points.enumerated().forEach { [unowned self] iterator in
            let index = iterator.offset
            let point = iterator.element

            let isFirst = index == 0
            let isLast = index == points.count - 1

            if isFirst {
                move(to: point)
            } else if isLast {
                addLine(to: point)
                move(to: point)

                guard isClosed, let firstItem = points.first else { return }
                addLine(to: firstItem)
            } else {
                addLine(to: point)
                move(to: point)
            }
        }
    }
}

extension CGPoint {
    public func translateFromCoreImageToUIKitCoordinateSpace(using height: CGFloat) -> CGPoint {
        let transform = CGAffineTransform(scaleX: 1, y: -1)
            .translatedBy(x: 0, y: -height)

        return self.applying(transform)
    }
}

// MARK: - Vision Extensions
@available(iOS 14.0, *)
extension VNDetectHumanBodyPoseRequest: ResultPointsProviding {
    public func pointsProjected(onto image: UIImage) -> [CGPoint] {
        point(jointGroups: [[.nose, .leftEye, .leftEar, .rightEye, .leftEar,]], projectedOnto: image).flatMap { $0 }
    }

    public func closedPointGroups(projectedOnto image: UIImage) -> [[CGPoint]] {
        point(jointGroups: [[.neck, .leftShoulder, .leftHip, .root, .rightHip, .rightShoulder]], projectedOnto: image)
    }

    public func openPointGroups(projectedOnto image: UIImage) -> [[CGPoint]] {
        point(jointGroups: [[.leftShoulder, .leftElbow, .leftWrist],
                            [.rightShoulder, .rightElbow, .rightWrist],
                            [.leftHip, .leftKnee, .leftAnkle],
                            [.rightHip, .rightKnee, .rightAnkle]], projectedOnto: image)
    }

    func point(jointGroups: [[VNHumanBodyPoseObservation.JointName]], projectedOnto image: UIImage) -> [[CGPoint]] {
        guard let results = results else { return [] }
        let pointGroups = results.map { result in
            jointGroups
                .compactMap { joints in
                    joints.compactMap { joint in
                        try? result.recognizedPoint(joint)
                    }
                    .filter { $0.confidence > 0.1 }
                    .map { $0.location(in: image) }
                    .map { $0.translateFromCoreImageToUIKitCoordinateSpace(using: image.size.height) }
                }
        }
        return pointGroups.flatMap { $0 }
    }
}

@available(iOS 14.0, *)
extension VNDetectHumanHandPoseRequest: ResultPointsProviding {
    public func pointsProjected(onto image: UIImage) -> [CGPoint] { [] }
    public func closedPointGroups(projectedOnto image: UIImage) -> [[CGPoint]] { [] }
    public func openPointGroups(projectedOnto image: UIImage) -> [[CGPoint]] {
        point(jointGroups: [[.wrist, .indexMCP, .indexPIP, .indexDIP, .indexTip],
                            [.wrist, .littleMCP, .littlePIP, .littleDIP, .littleTip],
                            [.wrist, .middleMCP, .middlePIP, .middleDIP, .middleTip],
                            [.wrist, .ringMCP, .ringPIP, .ringDIP, .ringTip],
                            [.wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip]],
                            projectedOnto: image)
    }

    func point(jointGroups: [[VNHumanHandPoseObservation.JointName]], projectedOnto image: UIImage) -> [[CGPoint]] {
        guard let results = results else { return [] }
        let pointGroups = results.map { result in
            jointGroups
                .compactMap { joints in
                    joints.compactMap { joint in
                        try? result.recognizedPoint(joint)
                    }
                    .filter { $0.confidence > 0.1 }
                    .map { $0.location(in: image) }
                    .map { $0.translateFromCoreImageToUIKitCoordinateSpace(using: image.size.height) }
                }
        }
        return pointGroups.flatMap { $0 }
    }
}

extension VNDetectFaceLandmarksRequest: ResultPointsProviding {
    public func pointsProjected(onto image: UIImage) -> [CGPoint] { [] }

    public func openPointGroups(projectedOnto image: UIImage) -> [[CGPoint]] {
        guard let results = results else { return [] }
        let landmarks = results.compactMap { [$0.landmarks?.leftEyebrow,
                                              $0.landmarks?.rightEyebrow,
                                              $0.landmarks?.faceContour,
                                              $0.landmarks?.noseCrest,
                                              $0.landmarks?.medianLine].compactMap { $0 } }
        return points(landmarks: landmarks, projectedOnto: image)
    }

    public func closedPointGroups(projectedOnto image: UIImage) -> [[CGPoint]] {
        guard let results = results else { return [] }
        let landmarks = results.compactMap { [$0.landmarks?.leftEye,
                                              $0.landmarks?.rightEye,
                                              $0.landmarks?.outerLips,
                                              $0.landmarks?.innerLips,
                                              $0.landmarks?.nose].compactMap { $0 } }
        return points(landmarks: landmarks, projectedOnto: image)
    }

    func points(landmarks: [[VNFaceLandmarkRegion2D]], projectedOnto image: UIImage) -> [[CGPoint]] {
        let faceLandmarks = landmarks.flatMap { $0 }
            .compactMap { landmark in
                landmark.pointsInImage(imageSize: image.size)
                    .map { $0.translateFromCoreImageToUIKitCoordinateSpace(using: image.size.height) }
            }
        return faceLandmarks
    }
}
