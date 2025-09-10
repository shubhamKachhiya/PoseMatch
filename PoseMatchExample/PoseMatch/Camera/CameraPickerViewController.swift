//
//  CameraPickerViewController.swift
//  PoseMatch
//
//  Created by Shubham Kachhiya on 05/09/25.
//


import SwiftUI

struct CameraPickerViewController: UIViewControllerRepresentable{
    
    @Binding var images: UIImage?
    @Binding var isCamera: Bool
    var onImagePicked: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.allowsEditing = true
        vc.delegate = context.coordinator
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(images: self.$images, isCamera: self.$isCamera, onImagePicked: self.onImagePicked)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate{
        @Binding var images: UIImage?
        @Binding var isCamera: Bool
        var onImagePicked: (UIImage) -> Void
        
        init(images: Binding<UIImage?>, isCamera: Binding<Bool>, onImagePicked: @escaping (UIImage) -> Void) {
            self._images = images
            self._isCamera = isCamera
            self.onImagePicked = onImagePicked
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            guard let image = info[.editedImage] as? UIImage else {
                print("No image found")
                return
            }
            images = image
            onImagePicked(image)
            isCamera = false
        }
    }
}
