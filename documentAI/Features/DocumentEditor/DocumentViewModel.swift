//
//  DocumentViewModel.swift
//  documentAI
//
//  Triangle of Truth: Central source of truth for all form field values
//

import Foundation
import SwiftUI
import Combine

@MainActor
class DocumentViewModel: ObservableObject {
    // MARK: - Triangle of Truth: Single Source of Truth
    @Published var formValues: [UUID: String] = [:]
    
    // MARK: - Document State
    @Published var components: [FieldComponent]
    @Published var fieldRegions: [FieldRegion]
    @Published var documentId: String
    @Published var pdfURL: URL?
    @Published var submitting = false
    @Published var alertState: FillAlertState?
    
    // MARK: - Services
    private let apiService = APIService()
    private let storageService = LocalFormStorageService()
    
    // MARK: - Private Properties
    private var selectedFile: DocumentModel?
    private var fileName: String?
    private var autoSaveTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var fieldIdToUUID: [String: UUID] = [:]
    var uuidToFieldId: [UUID: String] = [:]
    
    // MARK: - Init
    init(
        components: [FieldComponent],
        fieldRegions: [FieldRegion],
        documentId: String,
        selectedFile: DocumentModel?,
        pdfURL: URL?
    ) {
        self.components = components
        self.fieldRegions = fieldRegions
        self.documentId = documentId
        self.selectedFile = selectedFile
        self.fileName = selectedFile?.name
        self.pdfURL = pdfURL
        
        // Build UUID mappings
        buildFieldMappings()
        
        // Load saved form data if exists
        loadSavedFormData()
        
        // Setup autosave observer
        setupAutosave()
    }
    
    // MARK: - Build Field Mappings
    private func buildFieldMappings() {
        for component in components {
            let uuid = UUID()
            fieldIdToUUID[component.id] = uuid
            uuidToFieldId[uuid] = component.id
            
            // Initialize formValues with empty string or saved value
            if formValues[uuid] == nil {
                formValues[uuid] = ""
            }
        }
    }
    
    // MARK: - Load Saved Form Data
    private func loadSavedFormData() {
        if let savedData = storageService.loadFormData(documentId: documentId) {
            // Convert saved data to UUID-based formValues
            for (fieldId, value) in savedData.formData {
                if let uuid = fieldIdToUUID[fieldId] {
                    formValues[uuid] = value
                }
            }
        }
    }
    
    // MARK: - Setup Autosave
    private func setupAutosave() {
        // Autosave every 5 seconds when formValues changes
        $formValues
            .debounce(for: .seconds(5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.autoSave()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Auto Save
    private func autoSave() {
        // Convert UUID-based formValues to fieldId-based FormData
        var formData: FormData = [:]
        for (uuid, value) in formValues {
            if let fieldId = uuidToFieldId[uuid] {
                formData[fieldId] = value
            }
        }
        
        storageService.saveFormData(
            documentId: documentId,
            formData: formData,
            fileName: fileName
        )
        print("✅ Autosaved form data")
    }
    
    // MARK: - Update Field Value
    func updateFieldValue(uuid: UUID, value: String) {
        formValues[uuid] = value
    }
    
    // MARK: - Get Field Value
    func getFieldValue(uuid: UUID) -> String {
        return formValues[uuid] ?? ""
    }
    
    // MARK: - Get Field Component by UUID
    func getComponent(for uuid: UUID) -> FieldComponent? {
        guard let fieldId = uuidToFieldId[uuid] else { return nil }
        return components.first { $0.id == fieldId }
    }
    
    // MARK: - Get Field Region by UUID
    func getFieldRegion(for uuid: UUID) -> FieldRegion? {
        guard let fieldId = uuidToFieldId[uuid] else { return nil }
        return fieldRegions.first { $0.fieldId == fieldId }
    }
    
    // MARK: - Manual Save
    func saveProgress() {
        autoSave()
        
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
            // Convert UUID-based formValues to fieldId-based FormData
            var formData: FormData = [:]
            for (uuid, value) in formValues {
                if let fieldId = uuidToFieldId[uuid] {
                    formData[fieldId] = value
                }
            }
            
            // Save before submission
            storageService.saveFormData(
                documentId: documentId,
                formData: formData,
                fileName: fileName
            )
            
            // Call overlay API
            _ = try await apiService.overlayPDF(
                document: file,
                documentId: documentId,
                formData: formData,
                fieldRegions: fieldRegions
            )
            
            submitting = false
            
            // Show success alert
            alertState = FillAlertState(
                title: "Success!",
                message: "Your document has been filled and saved.",
                actions: [
                    FillAlertAction(title: "OK", style: .default, handler: {})
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
}
