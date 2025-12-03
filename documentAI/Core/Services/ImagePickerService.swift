//
//  ImagePickerService.swift
//  documentAI
//
//  Service for picking images from photo library
//

import SwiftUI
import PhotosUI

@MainActor
class ImagePickerService: NSObject, ObservableObject {
    private var continuation: CheckedContinuation<DocumentModel?, Never>?
    
    func pickImage() async -> DocumentModel? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            configuration.selectionLimit = 1
            
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = self
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(picker, animated: true)
            }
        }
    }
}

extension ImagePickerService: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let result = results.first else {
            continuation?.resume(returning: nil)
            continuation = nil
            return
        }
        
        result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
            guard let url = url, error == nil else {
                DispatchQueue.main.async {
                    self.continuation?.resume(returning: nil)
                    self.continuation = nil
                }
                return
            }
            
            do {
                // Copy to temporary directory
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(url.pathExtension)
                
                try FileManager.default.copyItem(at: url, to: tempURL)
                
                let attributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
                let fileSize = attributes[.size] as? Int64
                
                let document = DocumentModel(
                    id: UUID().uuidString,
                    name: tempURL.lastPathComponent,
                    url: tempURL,
                    mimeType: "image/\(tempURL.pathExtension.lowercased())",
                    sizeInBytes: fileSize
                )
                
                DispatchQueue.main.async {
                    self.continuation?.resume(returning: document)
                    self.continuation = nil
                }
            } catch {
                print("Error copying image: \(error)")
                DispatchQueue.main.async {
                    self.continuation?.resume(returning: nil)
                    self.continuation = nil
                }
            }
        }
    }
}
