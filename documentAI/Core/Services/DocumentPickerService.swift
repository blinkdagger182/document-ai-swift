//
//  DocumentPickerService.swift
//  documentAI
//
//  Service for picking PDF and image documents
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

@MainActor
class DocumentPickerService: NSObject, ObservableObject {
    private var continuation: CheckedContinuation<DocumentModel?, Never>?
    
    func pickDocument() async -> DocumentModel? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            
            let picker = UIDocumentPickerViewController(
                forOpeningContentTypes: [.pdf, .image],
                asCopy: true
            )
            picker.delegate = self
            picker.allowsMultipleSelection = false
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(picker, animated: true)
            }
        }
    }
}

extension DocumentPickerService: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            continuation?.resume(returning: nil)
            continuation = nil
            return
        }
        
        // Access security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            continuation?.resume(returning: nil)
            continuation = nil
            return
        }
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            // Copy to temporary directory
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(url.pathExtension)
            
            try FileManager.default.copyItem(at: url, to: tempURL)
            
            let attributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
            let fileSize = attributes[.size] as? Int64
            
            let mimeType: String
            if url.pathExtension.lowercased() == "pdf" {
                mimeType = "application/pdf"
            } else {
                mimeType = "image/\(url.pathExtension.lowercased())"
            }
            
            let document = DocumentModel(
                id: UUID().uuidString,
                name: url.lastPathComponent,
                url: tempURL,
                mimeType: mimeType,
                sizeInBytes: fileSize
            )
            
            continuation?.resume(returning: document)
        } catch {
            print("Error copying document: \(error)")
            continuation?.resume(returning: nil)
        }
        
        continuation = nil
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        continuation?.resume(returning: nil)
        continuation = nil
    }
}
