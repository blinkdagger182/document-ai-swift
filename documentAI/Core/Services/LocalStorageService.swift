//
//  LocalStorageService.swift
//  documentAI
//
//  Service for local storage of form data
//

import Foundation

@MainActor
class LocalStorageService: ObservableObject {
    
    private let fileManager = FileManager.default
    
    private var storageDirectory: URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let storageDir = documentsDirectory.appendingPathComponent("FormData")
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: storageDir.path) {
            try? fileManager.createDirectory(at: storageDir, withIntermediateDirectories: true)
        }
        
        return storageDir
    }
    
    // MARK: - Save Form Data
    func saveFormData(documentId: String, formData: FormData, fileName: String?) {
        let fileURL = storageDirectory.appendingPathComponent("\(documentId).json")
        
        let saveData: [String: Any] = [
            "documentId": documentId,
            "formData": formData,
            "fileName": fileName ?? "",
            "savedAt": ISO8601DateFormatter().string(from: Date())
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: saveData, options: .prettyPrinted)
            try jsonData.write(to: fileURL)
            print("✅ Form data saved for document: \(documentId)")
        } catch {
            print("❌ Error saving form data: \(error)")
        }
    }
    
    // MARK: - Load Form Data
    func loadFormData(documentId: String) -> SavedFormData? {
        let fileURL = storageDirectory.appendingPathComponent("\(documentId).json")
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let jsonData = try Data(contentsOf: fileURL)
            let savedData = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            
            guard let formData = savedData?["formData"] as? FormData else {
                return nil
            }
            
            return SavedFormData(
                documentId: documentId,
                formData: formData,
                fileName: savedData?["fileName"] as? String,
                savedAt: savedData?["savedAt"] as? String
            )
        } catch {
            print("❌ Error loading form data: \(error)")
            return nil
        }
    }
    
    // MARK: - Delete Form Data
    func deleteFormData(documentId: String) {
        let fileURL = storageDirectory.appendingPathComponent("\(documentId).json")
        
        do {
            try fileManager.removeItem(at: fileURL)
            print("✅ Form data deleted for document: \(documentId)")
        } catch {
            print("❌ Error deleting form data: \(error)")
        }
    }
    
    // MARK: - List All Saved Forms
    func listSavedForms() -> [String] {
        do {
            let files = try fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil)
            return files.map { $0.deletingPathExtension().lastPathComponent }
        } catch {
            print("❌ Error listing saved forms: \(error)")
            return []
        }
    }
}

// MARK: - Saved Form Data Model
struct SavedFormData {
    let documentId: String
    let formData: FormData
    let fileName: String?
    let savedAt: String?
}
