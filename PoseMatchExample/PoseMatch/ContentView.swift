//
//  ContentView.swift
//  PoseMatch
//
//  Created by Shubham Kachhiya on 09/09/25.
//

import SwiftUI
import PoseComparison

struct ContentView: View {
    @State private var selectedImage: UIImage?
    @State private var newImage: UIImage?
    @State private var isCameraPickerPresented = false
    @State private var presetPose: BodyProcessingResult?
    @State private var score: Double = 0.0
    @State private var maxScore: Double = 0.0
    @State private var lastProcessedImage: UIImage?
    @State private var isCameraRunning = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: geometry.size.height / 2)
                    
                    if let presetImage = newImage {
                        Image(uiImage: presetImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: geometry.size.height / 2 - 40)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "person.crop.square.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            
                            Text("Tap to select pose")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                isCameraPickerPresented = true
                            }) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            .padding(.trailing, 20)
                            .padding(.top, 50)
                        }
                        Spacer()
                    }
                }
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 2)
                
                ZStack {
                    if presetPose != nil {
                        if isCameraRunning {
                            LiveCameraView(isRunning: $isCameraRunning) { processedImage in
                                lastProcessedImage = processedImage
                                if let presetPose = presetPose {
                                    let livePose = BodyClassifier().processForOverlay(processedImage)
                                    score = PoseScoring.calculateRobustPoseScore(
                                        livePose: livePose,
                                        presetPose: presetPose,
                                        strictnessLevel: 0.30
                                    )
                                    maxScore = max(maxScore, score)
                                }
                            }
                            .frame(height: geometry.size.height / 2)
                            .clipped()
                        } else {
                            Rectangle()
                                .fill(Color.black)
                                .frame(height: geometry.size.height / 2)
                            
                            VStack(spacing: 12) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                Text("Camera is stopped")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("Tap start to begin")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    } else {
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: geometry.size.height / 2)
                        
                        VStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                            
                            Text("Select a pose first")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    
                    if presetPose != nil {
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: {
                                    isCameraRunning.toggle()
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: isCameraRunning ? "stop.circle.fill" : "play.circle.fill")
                                            .font(.title3)
                                        Text(isCameraRunning ? "Stop" : "Start")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(isCameraRunning ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                                    .cornerRadius(20)
                                    .shadow(color: .black.opacity(0.3), radius: 2)
                                }
                                .padding(.trailing, 16)
                                .padding(.top, 16)
                            }
                            Spacer()
                        }
                    }
                    
                    if presetPose != nil && isCameraRunning {
                        VStack {
                            Spacer()
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("SCORE")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Text("\(customRound(score))")
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundColor(scoreColor(score))
                                        .shadow(color: .black.opacity(0.5), radius: 2)
                                    
                                    Text("Max: \(customRound(maxScore))")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(12)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(12)
                                .padding(.leading, 16)
                                .padding(.bottom, 16)
                                
                                Spacer()
                            }
                        }
                    }
                    
                    if presetPose != nil && maxScore > 0 && isCameraRunning {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button("Reset Max") {
                                    maxScore = 0.0
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.2))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .padding(.trailing, 16)
                                .padding(.bottom, 16)
                            }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $isCameraPickerPresented) {
            CameraPickerViewController(images: $selectedImage, isCamera: $isCameraPickerPresented) { image in
                self.newImage = BodyClassifier().process(image)
                self.presetPose = BodyClassifier().processForOverlay(image)
                self.score = 0.0
                self.maxScore = 0.0
                self.isCameraRunning = false
            }
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 8...10:
            return .green
        case 5..<8:
            return .yellow
        case 0..<5:
            return .red
        default:
            return .white
        }
    }
    
    func customRound(_ value: Double) -> Int {
        let intPart = Int(value)
        let decimalPart = value - Double(intPart)
        
        if decimalPart >= 0.5 {
            return intPart + 1
        } else {
            return intPart
        }
    }
}

#Preview {
    ContentView()
}
