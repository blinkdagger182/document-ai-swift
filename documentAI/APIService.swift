//
//  APIService.swift
//  documentAI
//
//  Service for API calls (upload, process, overlay)
//

import Foundation

@MainActor
class APIService: ObservableObject {
    
    // TODO: Configure your API endpoint
    private let baseURL = "https://your-api-endpoint.com"
    
    // MARK: - Upload and Process Document
    func uploadAndProcessDocument(
        file: DocumentModel,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> ProcessResult {
        
        // TODO: Implement actual upload logic
        // This is a stub that simulates upload progress
        
        // Simulate upload progress
        for i in 0...100 {
            try await Task.sleep(nanoseconds: 30_000_000) // 30ms
            progressHandler(Double(i))
        }
        
        // TODO: Replace with actual API call
        // Example implementation:
        /*
        let url = URL(string: "\(baseURL)/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(file.name)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(file.mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: file.url))
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.uploadFailed
        }
        
        let result = try JSONDecoder().decode(ProcessResult.self, from: data)
        return result
        */
        
        // Stub response
        let stubComponents = [
            FieldComponent(
                id: "field_1",
                type: .text,
                label: "Full Name",
                placeholder: "Enter your full name",
                options: nil,
                value: AnyCodable("")
            ),
            FieldComponent(
                id: "field_2",
                type: .email,
                label: "Email Address",
                placeholder: "your@email.com",
                options: nil,
                value: AnyCodable("")
            ),
            FieldComponent(
                id: "field_3",
                type: .select,
                label: "Document Type",
                placeholder: "Select type",
                options: ["Passport", "Driver License", "ID Card"],
                value: AnyCodable("")
            ),
            FieldComponent(
                id: "field_4",
                type: .checkbox,
                label: "I agree to terms and conditions",
                placeholder: nil,
                options: nil,
                value: AnyCodable(false)
            )
        ]
        
        return ProcessResult(
            documentId: "doc_\(Int(Date().timeIntervalSince1970))",
            components: stubComponents,
            fieldMap: [:]
        )
    }
    
    // MARK: - Overlay PDF
    func overlayPDF(
        document: DocumentModel,
        documentId: String,
        formData: FormData
    ) async throws -> OverlayResult {
        
        // TODO: Implement actual overlay API call
        // This is a stub that simulates PDF generation
        
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // TODO: Replace with actual API call
        /*
        let url = URL(string: "\(baseURL)/overlay")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "documentId": documentId,
            "formData": formData
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.overlayFailed
        }
        
        // Download the generated PDF
        let pdfURL = try JSONDecoder().decode(OverlayResult.self, from: data).localPdfURL
        return OverlayResult(localPdfURL: pdfURL)
        */
        
        // Stub: Create a dummy PDF file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("filled_\(documentId).pdf")
        
        // Create empty PDF data
        let pdfData = Data()
        try pdfData.write(to: tempURL)
        
        return OverlayResult(localPdfURL: tempURL)
    }
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
