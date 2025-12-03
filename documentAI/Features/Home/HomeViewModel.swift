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
    
    // MARK: - Upload and Process
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
            let result = try await apiService.uploadAndProcessDocument(file: file) { progressValue in
                self.progress = progressValue
            }
            
            uploading = false
            processing = true
            
            // Store document ID, field map, and regions
            documentId = result.documentId
            components = result.components
            fieldMap = result.fieldMap
            fieldRegions = result.regions
            pdfURL = result.pdfURL ?? file.url
            
            // Initialize form data with default values
            var initialFormData: FormData = [:]
            for component in result.components {
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
            
        } catch {
            uploading = false
            processing = false
            alertState = AlertState(
                title: "Error",
                message: error.localizedDescription
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
