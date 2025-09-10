//
//  LiveCameraView.swift
//  PoseMatch
//
//  Created by Shubham Kachhiya on 09/09/25.
//

import SwiftUI

struct LiveCameraView: UIViewControllerRepresentable {
    @Binding var isRunning: Bool
    var onFrameProcessed: ((UIImage) -> Void)?
    
    func makeUIViewController(context: Context) -> LiveCameraViewController {
        let controller = LiveCameraViewController()
        controller.onFrameProcessed = onFrameProcessed
        return controller
    }
    
    func updateUIViewController(_ uiViewController: LiveCameraViewController, context: Context) {
        
    }
}
