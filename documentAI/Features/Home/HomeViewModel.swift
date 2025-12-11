//
//  HomeViewModel.swift
//  documentAI
//
//  ViewModel for HomeView - handles document selection, upload, and processing
//

import Foundation
import SwiftUI

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
    
    // MARK: - Services
    private let documentPickerService = DocumentPickerService()
    private let imagePickerService = ImagePickerService()
    private let apiService = APIService()
    
    // MARK: - Pick Document
    func pickDocument() async {
        if let document = await documentPickerService.pickDocument() {
            selectedFile = document
            showResults = false
            documentId = ""
        }
    }
    
    // MARK: - Pick Image
    func pickImage() async {
        if let document = await imagePickerService.pickImage() {
            selectedFile = document
            showResults = false
            documentId = ""
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
