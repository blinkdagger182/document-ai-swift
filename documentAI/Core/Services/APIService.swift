//
//  APIService.swift
//  documentAI
//
//  Service for API calls (upload, process, overlay)
//  Updated with real Cloud Run endpoints
//

import Foundation

@MainActor
class APIService: ObservableObject {
    
    // Production Cloud Run endpoint
    private let baseURL = "https://documentai-ocr-worker-824241800977.us-central1.run.app"
    
    // MARK: - Upload and Process Document
    func uploadAndProcessDocument(
        file: DocumentModel,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> ProcessResult {
        
        let url = URL(string: "\(baseURL)/ui/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(file.name)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(file.mimeType)\r\n\r\n".data(using: .utf8)!)
        
        let fileData = try Data(contentsOf: file.url)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Simulate progress during upload
        Task {
            for i in 0...90 {
                try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
                progressHandler(Double(i))
            }
        }
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        progressHandler(100)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ API Error (\(httpResponse.statusCode)): \(errorMessage)")
            throw APIError.uploadFailed
        }
        
        // Parse response
        do {
            // Debug: Print raw response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📥 API Response: \(jsonString.prefix(500))")
            }
            
            let ocrResponse = try JSONDecoder().decode(OCRResponse.self, from: data)
            print("✅ Decoded successfully: \(ocrResponse.components.count) components")
            
            // Convert to ProcessResult
            return convertOCRResponseToProcessResult(ocrResponse, pdfURL: file.url)
        } catch {
            print("❌ Decoding error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   Missing key: \(key.stringValue) at \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("   Type mismatch: expected \(type) at \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("   Value not found: \(type) at \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("   Data corrupted at \(context.codingPath)")
                @unknown default:
                    print("   Unknown decoding error")
                }
            }
            throw error
        }
    }
    
    // MARK: - Overlay PDF
    func overlayPDF(
        document: DocumentModel,
        documentId: String,
        formData: FormData,
        fieldRegions: [FieldRegion]
    ) async throws -> OverlayResult {
        
        let url = URL(string: "\(baseURL)/overlay")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(document.name)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(document.mimeType)\r\n\r\n".data(using: .utf8)!)
        
        let fileData = try Data(contentsOf: document.url)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add filled_data JSON
        let filledData = createFilledDataPayload(
            documentId: documentId,
            formData: formData,
            fieldRegions: fieldRegions
        )
        
        let jsonData = try JSONSerialization.data(withJSONObject: filledData)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"filled_data\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
        body.append(jsonData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Overlay Error (\(httpResponse.statusCode)): \(errorMessage)")
            throw APIError.overlayFailed
        }
        
        // Save PDF to temp file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("filled_\(documentId).pdf")
        
        try data.write(to: tempURL)
        
        return OverlayResult(localPdfURL: tempURL)
    }
    
    // MARK: - Helper Functions
    
    private func convertOCRResponseToProcessResult(_ response: OCRResponse, pdfURL: URL) -> ProcessResult {
        // Convert OCR components to FieldComponents
        var fieldComponents: [FieldComponent] = []
        var fieldRegions: [FieldRegion] = []
        
        for component in response.components {
            // Map component type
            let fieldType: FieldType
            switch component.type {
            case "checkbox":
                fieldType = .checkbox
            case "input", "text_field":
                fieldType = .text
            default:
                fieldType = .text
            }
            
            // Create FieldComponent
            let fieldComponent = FieldComponent(
                id: component.id,
                type: fieldType,
                label: component.label,
                placeholder: nil,
                options: nil,
                value: AnyCodable(component.value ?? "")
            )
            fieldComponents.append(fieldComponent)
            
            // Create FieldRegion from bbox
            if let bbox = component.bbox, bbox.count == 8 {
                let x = min(bbox[0], bbox[6])
                let y = min(bbox[1], bbox[3])
                let width = max(bbox[2], bbox[4]) - x
                let height = max(bbox[5], bbox[7]) - y
                
                let fieldRegion = FieldRegion(
                    fieldId: component.id,
                    x: x,
                    y: y,
                    width: width,
                    height: height,
                    page: component.page > 0 ? component.page - 1 : 0, // Convert to 0-indexed
                    source: .ocr
                )
                fieldRegions.append(fieldRegion)
            }
        }
        
        return ProcessResult(
            documentId: UUID().uuidString,
            components: fieldComponents,
            fieldMap: [:],
            fieldRegions: fieldRegions,
            pdfURL: pdfURL
        )
    }
    
    private func createFilledDataPayload(
        documentId: String,
        formData: FormData,
        fieldRegions: [FieldRegion]
    ) -> [String: Any] {
        var fieldMap: [String: [String: Any]] = [:]
        
        for region in fieldRegions {
            fieldMap[region.fieldId] = [
                "bbox": [
                    region.x, region.y,
                    region.x + region.width, region.y,
                    region.x + region.width, region.y + region.height,
                    region.x, region.y + region.height
                ],
                "page": (region.page ?? 0) + 1, // Convert back to 1-indexed
                "type": "text_field"
            ]
        }
        
        return [
            "documentId": documentId,
            "values": formData,
            "fieldMap": fieldMap
        ]
    }
}

// MARK: - API Response Models

struct OCRResponse: Codable {
    let success: Bool
    let components: [OCRComponent]
    let fieldMap: [String: OCRFieldInfo]?
    let metadata: OCRMetadata?
}

struct OCRComponent: Codable {
    let id: String
    let type: String
    let label: String
    let valueRaw: AnyCodable?
    let bbox: [Double]?
    let page: Int
    
    enum CodingKeys: String, CodingKey {
        case id, type, label, bbox, page
        case valueRaw = "value"
    }
    
    // Computed property to get value as string
    var value: String? {
        if let val = valueRaw?.value {
            if let boolVal = val as? Bool {
                return boolVal ? "true" : "false"
            } else if let stringVal = val as? String {
                return stringVal
            } else {
                return String(describing: val)
            }
        }
        return nil
    }
}

struct OCRFieldInfo: Codable {
    let bbox: [Double]
    let page: Int
    let type: String
}

struct OCRMetadata: Codable {
    let pages: [PageInfo]?
    let total_pages: Int?
    let total_fields: Int?
}

struct PageInfo: Codable {
    let page: Int
    let width: Double
    let height: Double
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case uploadFailed
    case overlayFailed
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .uploadFailed:
            return "Failed to upload document"
        case .overlayFailed:
            return "Failed to generate filled PDF"
        case .invalidResponse:
            return "Invalid server response"
        }
    }
}

// MARK: - Data Extension
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
