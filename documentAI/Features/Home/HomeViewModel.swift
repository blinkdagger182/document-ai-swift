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
                FieldRegion(
                    id: dto.id,
                    fieldId: fieldId,
                    x: dto.x,
                    y: dto.y,
                    width: dto.width,
                    height: dto.height,
                    page: dto.pageIndex,
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
    }
}

// MARK: - Alert State
struct AlertState: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
