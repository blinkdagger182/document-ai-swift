//
//  FillDocumentViewModel.swift
//  documentAI
//
//  ViewModel for FillDocumentView - handles form editing and submission
//

import Foundation
import SwiftUI

@MainActor
class FillDocumentViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var components: [FieldComponent]
    @Published var fieldMap: FieldMap
    @Published var formData: FormData
    @Published var documentId: String
    @Published var submitting = false
    @Published var savedPdfUrl: URL?
    @Published var alertState: FillAlertState?
    
    // MARK: - Services
    private let apiService = APIService()
    private let storageService = LocalStorageService()
    
    // MARK: - Private Properties
    private var selectedFile: DocumentModel?
    private var fileName: String?
    private var autoSaveTimer: Timer?
    
    // MARK: - Init
    init(
        components: [FieldComponent],
        fieldMap: FieldMap,
        formData: FormData,
        documentId: String,
        selectedFile: DocumentModel?
    ) {
        self.components = components
        self.fieldMap = fieldMap
        self.formData = formData
        self.documentId = documentId
        self.selectedFile = selectedFile
        self.fileName = selectedFile?.name
    }
    
    // MARK: - Update Field Value
    func updateFieldValue(id: String, value: String) {
        formData[id] = value
        
        // Reset auto-save timer (5 seconds after last change)
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.autoSave()
            }
        }
    }
    
    // MARK: - Auto Save
    private func autoSave() {
        storageService.saveFormData(
            documentId: documentId,
            formData: formData,
            fileName: fileName
        )
    }
    
    // MARK: - Save Progress
    func saveProgress() {
        storageService.saveFormData(
            documentId: documentId,
            formData: formData,
            fileName: fileName
        )
        
        alertState = FillAlertState(
            title: "Saved",
            message: "Your progress has been saved",
            actions: [
                FillAlertAction(title: "OK", style: .default, handler: {})
            ]
        )
    }
    
    // MARK: - Submit and Generate PDF
    func submitAndGeneratePDF() async {
        guard let file = selectedFile else {
            alertState = FillAlertState(
                title: "Error",
                message: "No document selected",
                actions: [
                    FillAlertAction(title: "OK", style: .default, handler: {})
                ]
            )
            return
        }
        
        submitting = true
        
        do {
            // Save form data before submission
            storageService.saveFormData(
                documentId: documentId,
                formData: formData,
                fileName: fileName
            )
            
            // Call overlay API
            let result = try await apiService.overlayPDF(
                document: file,
                documentId: documentId,
                formData: formData
            )
            
            savedPdfUrl = result.localPdfURL
            submitting = false
            
            // Show success alert with options
            alertState = FillAlertState(
                title: "Success!",
                message: "Your document has been filled and saved locally.",
                actions: [
                    FillAlertAction(title: "View PDF", style: .default) { [weak self] in
                        self?.viewPDF()
                    },
                    FillAlertAction(title: "Share", style: .default) { [weak self] in
                        self?.sharePDF()
                    },
                    FillAlertAction(title: "Upload Another", style: .cancel) { [weak self] in
                        self?.uploadAnother()
                    }
                ]
            )
            
        } catch {
            submitting = false
            alertState = FillAlertState(
                title: "Error",
                message: error.localizedDescription,
                actions: [
                    FillAlertAction(title: "OK", style: .default, handler: {})
                ]
            )
        }
    }
    
    // MARK: - View PDF
    private func viewPDF() {
        guard let pdfUrl = savedPdfUrl else { return }
        // TODO: Implement PDF viewer
        print("View PDF at: \(pdfUrl)")
    }
    
    // MARK: - Share PDF
    private func sharePDF() {
        guard let pdfUrl = savedPdfUrl else { return }
        // TODO: Implement share sheet
        print("Share PDF at: \(pdfUrl)")
    }
    
    // MARK: - Upload Another
    private func uploadAnother() {
        // This will be handled by the parent view
    }
}

// MARK: - Alert State
struct FillAlertState: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let actions: [FillAlertAction]
}

struct FillAlertAction {
    let title: String
    let style: ActionStyle
    let handler: () -> Void
    
    enum ActionStyle {
        case `default`
        case cancel
        case destructive
    }
}
