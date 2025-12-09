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
    @Published var components: [FieldComponent] = []
    @Published var fieldMap: FieldMap = [:]
    @Published var fieldRegions: [FieldRegion] = []
    @Published var formData: FormData = [:]
    @Published var documentId = ""
    @Published var pdfURL: URL?
    
    @Published var alertState: AlertState?
    
    // CommonForms state
    @Published var commonFormsProcessing = false
    @Published var commonFormsPdfURL: URL?
    @Published var commonFormsFields: [DetectedField] = []
    
    // MARK: - Services
    private let documentPickerService = DocumentPickerService()
    private let imagePickerService = ImagePickerService()
    private let apiService = APIService()
    private let storageService = LocalStorageService()
    
    // MARK: - Pick Document
    func pickDocument() async {
        if let document = await documentPickerService.pickDocument() {
            selectedFile = document
            showResults = false
            components = []
            formData = [:]
            documentId = ""
        }
    }
    
    // MARK: - Pick Image
    func pickImage() async {
        if let document = await imagePickerService.pickImage() {
            selectedFile = document
            showResults = false
            components = []
            formData = [:]
            documentId = ""
        }
    }
    
    // MARK: - Upload and Process (Following Architecture Spec)
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
            // Step 1: Init Upload
            let uploadResponse = try await apiService.initUpload(file: file) { progressValue in
                self.progress = progressValue
            }
            
            documentId = uploadResponse.documentId
            
            uploading = false
            processing = true
            
            // Step 2: Start Processing
            _ = try await apiService.processDocument(documentId: documentId)
            
            // Step 3: Poll Until Ready
            let detail = try await apiService.pollUntilReady(documentId: documentId)
            
            // Step 4: Extract components and fieldMap
            components = detail.components
            
            // Convert FieldRegionDTO to FieldRegion
            fieldRegions = detail.fieldMap.map { (fieldId, dto) in
                // Parse fieldType string to FieldType enum
                let fieldType: FieldType? = {
                    guard let typeStr = dto.fieldType else { return nil }
                    return FieldType(rawValue: typeStr)
                }()
                
                return FieldRegion(
                    id: dto.id,
                    fieldId: fieldId,
                    x: dto.x,
                    y: dto.y,
                    width: dto.width,
                    height: dto.height,
                    page: dto.pageIndex,
                    fieldType: fieldType,
                    source: .ocr
                )
            }
            
            // Build fieldMap for compatibility
            fieldMap = detail.fieldMap.reduce(into: [:]) { result, item in
                result[item.key] = FieldMetadata(
                    x: item.value.x,
                    y: item.value.y,
                    width: item.value.width,
                    height: item.value.height,
                    page: item.value.pageIndex
                )
            }
            
            pdfURL = file.url
            
            // Initialize form data with default values
            var initialFormData: FormData = [:]
            for component in components {
                if let value = component.value?.value as? String {
                    initialFormData[component.id] = value
                } else {
                    initialFormData[component.id] = ""
                }
            }
            
            // Try to load saved form data
            if let savedData = storageService.loadFormData(documentId: documentId) {
                formData = savedData.formData
                alertState = AlertState(
                    title: "Restored",
                    message: "Previously saved form data has been restored"
                )
            } else {
                formData = initialFormData
            }
            
            processing = false
            showResults = true
            
            print("✅ Document ready: \(components.count) fields, AcroForm: \(detail.document.acroform ?? false)")
            
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
        components = []
        fieldMap = [:]
        fieldRegions = []
        formData = [:]
        documentId = ""
        pdfURL = nil
        progress = 0.0
        commonFormsPdfURL = nil
        commonFormsFields = []
    }
    
    // MARK: - Test CommonForms Integration
    /// Triggers CommonForms processing for the current document
    /// 1. Calls /process/commonforms/{documentId}
    /// 2. Polls /process/status/{jobId} until complete
    /// 3. Downloads the fillable PDF
    /// 4. Logs detected fields to console
    func testCommonForms() async {
        guard !documentId.isEmpty else {
            alertState = AlertState(
                title: "No Document",
                message: "Please upload a document first"
            )
            return
        }
        
        guard let docUUID = UUID(uuidString: documentId) else {
            alertState = AlertState(
                title: "Invalid ID",
                message: "Document ID is not a valid UUID"
            )
            return
        }
        
        commonFormsProcessing = true
        
        do {
            // Step 1: Start CommonForms processing
            print("🚀 Starting CommonForms processing for document: \(documentId)")
            let jobId = try await apiService.processWithCommonForms(documentId: docUUID)
            print("📋 Job ID: \(jobId)")
            
            // Step 2: Poll until complete
            print("⏳ Polling for CommonForms completion...")
            let result = try await apiService.pollCommonFormsUntilComplete(jobId: jobId)
            
            // Step 3: Log detected fields
            if let fields = result.fields {
                commonFormsFields = fields
                print("📝 ===== COMMONFORMS DETECTED FIELDS =====")
                for (index, field) in fields.enumerated() {
                    print("  [\(index)] id: \(field.id)")
                    print("       type: \(field.type)")
                    print("       page: \(field.page)")
                    print("       bbox: \(field.bbox)")
                    print("       label: \(field.label ?? "nil")")
                }
                print("📝 ===== TOTAL: \(fields.count) FIELDS =====")
            }
            
            // Step 4: Download fillable PDF and assign to state
            if let pdfUrlString = result.outputPdfUrl {
                print("📥 Downloading fillable PDF from: \(pdfUrlString)")
                let localPdfURL = try await apiService.downloadPDFData(from: pdfUrlString)
                
                // Verify file exists
                if FileManager.default.fileExists(atPath: localPdfURL.path) {
                    print("✅ PDF file verified at: \(localPdfURL.path)")
                    
                    // Assign CommonForms PDF URL
                    self.commonFormsPdfURL = localPdfURL
                    self.pdfURL = localPdfURL
                    
                    print("✅ pdfURL assigned: \(self.pdfURL?.path ?? "nil")")
                    print("✅ commonFormsPdfURL assigned: \(self.commonFormsPdfURL?.path ?? "nil")")
                } else {
                    print("❌ PDF file does not exist at path: \(localPdfURL.path)")
                    throw APIError.downloadFailed
                }
            } else {
                print("⚠️ No outputPdfUrl in CommonForms result")
                throw APIError.invalidResponse
            }
            
            // Assign CommonForms fields
            if let fields = result.fields {
                self.commonFormsFields = fields
            }
            
            commonFormsProcessing = false
            showResults = true
            
            // Log fields for debugging
            print("📝 CommonForms fields assigned: \(commonFormsFields.count)")
            
            alertState = AlertState(
                title: "CommonForms Complete",
                message: "Fillable PDF generated with \(commonFormsFields.count) fields. Check console for field details."
            )
            
        } catch {
            commonFormsProcessing = false
            
            print("❌ CommonForms error: \(error)")
            
            let errorMessage: String
            if let apiError = error as? APIError {
                errorMessage = apiError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
            
            alertState = AlertState(
                title: "CommonForms Error",
                message: errorMessage
            )
        }
    }
    
    // MARK: - Test CommonForms Mock (for testing without CommonForms library)
    /// Uses mock endpoint that returns immediately with fake fields
    /// Use this to test iOS integration when CommonForms isn't installed on backend
    func testCommonFormsMock() async {
        guard !documentId.isEmpty else {
            alertState = AlertState(
                title: "No Document",
                message: "Please upload a document first"
            )
            return
        }
        
        guard let docUUID = UUID(uuidString: documentId) else {
            alertState = AlertState(
                title: "Invalid ID",
                message: "Document ID is not a valid UUID"
            )
            return
        }
        
        commonFormsProcessing = true
        
        do {
            // Call mock endpoint (returns immediately)
            print("🧪 Testing CommonForms with mock endpoint for document: \(documentId)")
            let result = try await apiService.processWithCommonFormsMock(documentId: docUUID)
            
            // Log detected fields
            if let fields = result.fields {
                commonFormsFields = fields
                print("📝 ===== MOCK COMMONFORMS FIELDS =====")
                for (index, field) in fields.enumerated() {
                    print("  [\(index)] id: \(field.id)")
                    print("       type: \(field.type)")
                    print("       page: \(field.page)")
                    print("       bbox: \(field.bbox)")
                    print("       label: \(field.label ?? "nil")")
                }
                print("📝 ===== TOTAL: \(fields.count) MOCK FIELDS =====")
            }
            
            // Download PDF (original PDF in mock mode)
            if let pdfUrlString = result.outputPdfUrl {
                print("📥 Downloading PDF from: \(pdfUrlString)")
                let localPdfURL = try await apiService.downloadPDFData(from: pdfUrlString)
                commonFormsPdfURL = localPdfURL
                pdfURL = localPdfURL
                print("✅ Mock PDF ready at: \(localPdfURL.path)")
            }
            
            commonFormsProcessing = false
            showResults = true
            
            alertState = AlertState(
                title: "Mock Test Complete",
                message: "Received \(commonFormsFields.count) mock fields. Check console for details."
            )
            
        } catch {
            commonFormsProcessing = false
            
            print("❌ CommonForms mock error: \(error)")
            
            let errorMessage: String
            if let apiError = error as? APIError {
                errorMessage = apiError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
            
            alertState = AlertState(
                title: "Mock Test Error",
                message: errorMessage
            )
        }
    }
}

// MARK: - Alert State
struct AlertState: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
