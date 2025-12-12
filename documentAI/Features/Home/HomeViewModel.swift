//
//  HomeViewModel.swift
//  documentAI
//
//  ViewModel for HomeView - handles document selection, upload, and processing
//

import Foundation
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

@MainActor
class HomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var uploading = false
    @Published var processing = false
    @Published var progress: Double = 0.0
    @Published var selectedFile: DocumentModel?
    @Published var showResults = false
    @Published var documentId = ""
    @Published var pdfURL: URL?
    @Published var alertState: AlertState?
    
    // CommonForms state
    @Published var commonFormsPdfURL: URL?
    @Published var commonFormsFields: [DetectedField] = []
    
    // Photo picker
    @Published var selectedPhotoItem: PhotosPickerItem?
    
    // MARK: - Services
    private let apiService = APIService()
    
    // MARK: - Handle Document Selection (from fileImporter)
    func handleDocumentSelection(result: Result<[URL], Error>) async {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            
            // Access security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ Failed to access security-scoped resource")
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
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
            
            selectedFile = DocumentModel(
                id: UUID().uuidString,
                name: url.lastPathComponent,
                url: tempURL,
                mimeType: mimeType,
                sizeInBytes: fileSize
            )
            
            showResults = false
            documentId = ""
            
            print("✅ Document selected: \(url.lastPathComponent)")
            
        } catch {
            print("❌ Error handling document: \(error)")
            alertState = AlertState(
                title: "Error",
                message: "Failed to load document: \(error.localizedDescription)"
            )
        }
    }
    
    // MARK: - Handle Image Selection (from PhotosPicker)
    func handleImageSelection() async {
        guard let item = selectedPhotoItem else { return }
        
        do {
            // Load the image data
            guard let data = try await item.loadTransferable(type: Data.self) else {
                print("❌ Failed to load image data")
                return
            }
            
            // Determine file extension from content type
            let contentType = item.supportedContentTypes.first
            let fileExtension: String
            if contentType == .png {
                fileExtension = "png"
            } else if contentType == .jpeg {
                fileExtension = "jpg"
            } else if contentType == .heic {
                fileExtension = "heic"
            } else {
                fileExtension = "jpg" // default
            }
            
            // Save to temporary directory
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)
            
            try data.write(to: tempURL)
            
            let fileSize = Int64(data.count)
            
            selectedFile = DocumentModel(
                id: UUID().uuidString,
                name: "image.\(fileExtension)",
                url: tempURL,
                mimeType: "image/\(fileExtension)",
                sizeInBytes: fileSize
            )
            
            showResults = false
            documentId = ""
            
            print("✅ Image selected: \(tempURL.lastPathComponent)")
            
        } catch {
            print("❌ Error handling image: \(error)")
            alertState = AlertState(
                title: "Error",
                message: "Failed to load image: \(error.localizedDescription)"
            )
        }
    }
    
    // MARK: - Upload and Process with CommonForms
    func uploadAndProcess() async {
        guard let file = selectedFile else {
            alertState = AlertState(
                title: "No File",
                message: "Please select a file first"
            )
            return
        }
        
        uploading = true
        progress = 0.0
        
        do {
            // Step 1: Upload document
            print("📤 Uploading document...")
            let uploadResponse = try await apiService.initUpload(file: file) { progressValue in
                self.progress = progressValue
            }
            
            documentId = uploadResponse.documentId
            print("✅ Upload complete. Document ID: \(documentId)")
            
            uploading = false
            processing = true
            
            // Step 2: Process with CommonForms
            guard let docUUID = UUID(uuidString: documentId) else {
                print("❌ Invalid document ID format")
                throw APIError.invalidResponse
            }
            
            print("🚀 Starting CommonForms processing...")
            let jobId = try await apiService.processWithCommonForms(documentId: docUUID)
            print("📋 Job ID: \(jobId)")
            
            print("⏳ Polling for completion...")
            let result = try await apiService.pollCommonFormsUntilComplete(jobId: jobId)
            print("✅ CommonForms status: \(result.status)")
            
            // Step 3: Download fillable PDF
            guard let pdfUrlString = result.outputPdfUrl else {
                print("❌ No outputPdfUrl in result")
                print("   Result: status=\(result.status), error=\(result.error ?? "nil")")
                throw APIError.invalidResponse
            }
            
            print("📥 Downloading PDF from: \(pdfUrlString)")
            let localPdfURL = try await apiService.downloadPDFData(from: pdfUrlString)
            
            guard FileManager.default.fileExists(atPath: localPdfURL.path) else {
                print("❌ Downloaded PDF not found at: \(localPdfURL.path)")
                throw APIError.downloadFailed
            }
            
            self.commonFormsPdfURL = localPdfURL
            self.pdfURL = localPdfURL
            print("✅ PDF ready at: \(localPdfURL.path)")
            
            // Step 4: Store detected fields
            if let fields = result.fields {
                self.commonFormsFields = fields
                print("✅ Stored \(fields.count) detected fields")
            }
            
            processing = false
            showResults = true
            
            print("✅ CommonForms complete: \(commonFormsFields.count) fields detected")
            
        } catch {
            uploading = false
            processing = false
            
            print("❌ Upload/Process error: \(error)")
            
            let errorMessage: String
            if let apiError = error as? APIError {
                errorMessage = apiError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
            
            alertState = AlertState(
                title: "Error",
                message: errorMessage
            )
        }
    }
    
    // MARK: - Reset
    func reset() {
        selectedFile = nil
        showResults = false
        documentId = ""
        pdfURL = nil
        progress = 0.0
        commonFormsPdfURL = nil
        commonFormsFields = []
    }
    

}

// MARK: - Alert State
struct AlertState: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
