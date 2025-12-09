//
//  APIService.swift
//  documentAI
//
//  Service for API calls following the architecture spec
//  API Contract: /api/v1/documents/*
//

import Foundation

@MainActor
class APIService: ObservableObject {
    
    // MARK: - Configuration
    // Deployed FastAPI backend URL
    private let baseURL = "https://documentai-api-824241800977.us-central1.run.app"
    
    // MARK: - 1. Init Upload
    /// POST /api/v1/documents/init-upload
    /// Upload document and create database record
    func initUpload(
        file: DocumentModel,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> InitUploadResponse {
        
        let url = URL(string: "\(baseURL)/api/v1/documents/init-upload")!
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
        
        guard httpResponse.statusCode == 201 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Init Upload Error (\(httpResponse.statusCode)): \(errorMessage)")
            throw APIError.uploadFailed
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let uploadResponse = try decoder.decode(InitUploadResponse.self, from: data)
        
        print("✅ Document uploaded: \(uploadResponse.documentId)")
        return uploadResponse
    }
    
    // MARK: - 2. Process Document
    /// POST /api/v1/documents/{id}/process
    /// Start OCR/AcroForm processing
    func processDocument(documentId: String) async throws -> ProcessDocumentResponse {
        
        let url = URL(string: "\(baseURL)/api/v1/documents/\(documentId)/process")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Process Error (\(httpResponse.statusCode)): \(errorMessage)")
            throw APIError.processFailed
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let processResponse = try decoder.decode(ProcessDocumentResponse.self, from: data)
        
        print("✅ Processing started: \(processResponse.status)")
        return processResponse
    }
    
    // MARK: - 3. Get Document Details
    /// GET /api/v1/documents/{id}
    /// Poll for document status and get components/fieldMap when ready
    func getDocument(documentId: String) async throws -> DocumentDetailResponse {
        
        let url = URL(string: "\(baseURL)/api/v1/documents/\(documentId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Get Document Error (\(httpResponse.statusCode)): \(errorMessage)")
            throw APIError.fetchFailed
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let detailResponse = try decoder.decode(DocumentDetailResponse.self, from: data)
        
        print("✅ Document fetched: status=\(detailResponse.document.status), fields=\(detailResponse.components.count)")
        return detailResponse
    }
    
    // MARK: - 4. Submit Values
    /// POST /api/v1/documents/{id}/values
    /// Submit user-entered field values
    func submitValues(
        documentId: String,
        values: [FieldValueInput]
    ) async throws -> SubmitValuesResponse {
        
        let url = URL(string: "\(baseURL)/api/v1/documents/\(documentId)/values")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = SubmitValuesRequest(values: values)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Submit Values Error (\(httpResponse.statusCode)): \(errorMessage)")
            throw APIError.submitFailed
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let submitResponse = try decoder.decode(SubmitValuesResponse.self, from: data)
        
        print("✅ Values submitted: \(values.count) fields")
        return submitResponse
    }
    
    // MARK: - 5. Compose PDF
    /// POST /api/v1/documents/{id}/compose
    /// Generate filled PDF
    func composePDF(documentId: String) async throws -> ProcessDocumentResponse {
        
        let url = URL(string: "\(baseURL)/api/v1/documents/\(documentId)/compose")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Compose Error (\(httpResponse.statusCode)): \(errorMessage)")
            throw APIError.composeFailed
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let composeResponse = try decoder.decode(ProcessDocumentResponse.self, from: data)
        
        print("✅ PDF composition started")
        return composeResponse
    }
    
    // MARK: - 6. Download Filled PDF
    /// GET /api/v1/documents/{id}/download
    /// Get presigned URL for filled PDF
    func downloadPDF(documentId: String) async throws -> DownloadResponse {
        
        let url = URL(string: "\(baseURL)/api/v1/documents/\(documentId)/download")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Download Error (\(httpResponse.statusCode)): \(errorMessage)")
            throw APIError.downloadFailed
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let downloadResponse = try decoder.decode(DownloadResponse.self, from: data)
        
        print("✅ Download URL received")
        return downloadResponse
    }
    
    // MARK: - Helper: Poll Until Ready
    /// Poll document status until it reaches 'ready' state
    func pollUntilReady(documentId: String, maxAttempts: Int = 60) async throws -> DocumentDetailResponse {
        for attempt in 1...maxAttempts {
            let detail = try await getDocument(documentId: documentId)
            
            if detail.document.status == "ready" {
                return detail
            } else if detail.document.status == "failed" {
                throw APIError.processingFailed(detail.document.errorMessage ?? "Unknown error")
            }
            
            print("⏳ Polling attempt \(attempt)/\(maxAttempts): status=\(detail.document.status)")
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }
        
        throw APIError.timeout
    }
    
    // MARK: - Helper: Poll Until Filled
    /// Poll document status until PDF composition is complete
    func pollUntilFilled(documentId: String, maxAttempts: Int = 60) async throws -> DocumentDetailResponse {
        for attempt in 1...maxAttempts {
            let detail = try await getDocument(documentId: documentId)
            
            if detail.document.status == "filled" {
                return detail
            } else if detail.document.status == "failed" {
                throw APIError.processingFailed(detail.document.errorMessage ?? "Unknown error")
            }
            
            print("⏳ Polling composition \(attempt)/\(maxAttempts): status=\(detail.document.status)")
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }
        
        throw APIError.timeout
    }
    
    // MARK: - 7. Process with CommonForms
    /// POST /api/v1/process/commonforms/{documentId}
    /// Start CommonForms processing to generate fillable PDF
    func processWithCommonForms(documentId: UUID) async throws -> String {
        let url = URL(string: "\(baseURL)/api/v1/process/commonforms/\(documentId.uuidString)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ CommonForms Error (\(httpResponse.statusCode)): \(errorMessage)")
            throw APIError.commonFormsFailed
        }
        
        let decoder = JSONDecoder()
        let cfResponse = try decoder.decode(CommonFormsJobResponse.self, from: data)
        
        print("✅ CommonForms job started: \(cfResponse.jobId)")
        return cfResponse.jobId
    }
    
    // MARK: - 8. Fetch CommonForms Status
    /// GET /api/v1/process/status/{jobId}
    /// Poll for CommonForms job status
    func fetchCommonFormsStatus(jobId: String) async throws -> CommonFormsResult {
        let url = URL(string: "\(baseURL)/api/v1/process/status/\(jobId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ CommonForms Status Error (\(httpResponse.statusCode)): \(errorMessage)")
            throw APIError.fetchFailed
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(CommonFormsResult.self, from: data)
        
        print("✅ CommonForms status: \(result.status)")
        return result
    }
    
    // MARK: - Helper: Poll CommonForms Until Complete
    /// Poll CommonForms job until completed or failed
    func pollCommonFormsUntilComplete(jobId: String, maxAttempts: Int = 60) async throws -> CommonFormsResult {
        for attempt in 1...maxAttempts {
            let result = try await fetchCommonFormsStatus(jobId: jobId)
            
            if result.status == "completed" {
                return result
            } else if result.status == "failed" {
                throw APIError.processingFailed(result.error ?? "CommonForms processing failed")
            }
            
            print("⏳ CommonForms polling \(attempt)/\(maxAttempts): status=\(result.status)")
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }
        
        throw APIError.timeout
    }
    
    // MARK: - Helper: Download PDF Data
    /// Download PDF from URL and return local file URL
    func downloadPDFData(from urlString: String) async throws -> URL {
        print("🔗 Attempting to download PDF from: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL string: \(urlString)")
            throw APIError.invalidResponse
        }
        
        print("📡 Starting URLSession download...")
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Response is not HTTPURLResponse")
            throw APIError.downloadFailed
        }
        
        print("📊 HTTP Status Code: \(httpResponse.statusCode)")
        print("📦 Downloaded data size: \(data.count) bytes")
        
        guard httpResponse.statusCode == 200 else {
            print("❌ HTTP error: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Response body: \(responseString)")
            }
            throw APIError.downloadFailed
        }
        
        // Save to temp file
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "commonforms_\(UUID().uuidString).pdf"
        let localURL = tempDir.appendingPathComponent(fileName)
        
        print("💾 Writing PDF to: \(localURL.path)")
        try data.write(to: localURL)
        
        // Verify file was written
        let fileSize = try FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int ?? 0
        print("✅ PDF saved successfully: \(fileSize) bytes at \(localURL.path)")
        
        return localURL
    }
    
    // MARK: - 9. Process with CommonForms (Mock)
    /// POST /api/v1/process/commonforms/{documentId}/mock
    /// Mock CommonForms processing for testing - returns immediately with fake fields
    func processWithCommonFormsMock(documentId: UUID) async throws -> CommonFormsResult {
        let url = URL(string: "\(baseURL)/api/v1/process/commonforms/\(documentId.uuidString)/mock")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ CommonForms Mock Error (\(httpResponse.statusCode)): \(errorMessage)")
            throw APIError.commonFormsFailed
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(CommonFormsResult.self, from: data)
        
        print("✅ CommonForms mock completed: \(result.fields?.count ?? 0) fields")
        return result
    }
}

// MARK: - API Response Models

struct InitUploadResponse: Codable {
    let documentId: String
    let document: DocumentSummary
}

struct DocumentSummary: Codable {
    let id: String
    let fileName: String
    let mimeType: String
    let status: String
    let pageCount: Int?
    let acroform: Bool?
    let createdAt: String
    let errorMessage: String?
}

struct ProcessDocumentResponse: Codable {
    let documentId: String
    let status: String
}

struct DocumentDetailResponse: Codable {
    let document: DocumentSummary
    let components: [FieldComponent]
    let fieldMap: [String: FieldRegionDTO]
}

struct FieldRegionDTO: Codable {
    let id: String
    let pageIndex: Int
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let fieldType: String?
    let label: String
    let confidence: Double
}

struct SubmitValuesRequest: Codable {
    let values: [FieldValueInput]
}

struct FieldValueInput: Codable {
    let fieldRegionId: String
    let value: String
    let source: String // "manual", "autofill", "ai"
}

struct SubmitValuesResponse: Codable {
    let documentId: String
    let status: String
}

struct DownloadResponse: Codable {
    let documentId: String
    let filledPdfUrl: String
}

// MARK: - CommonForms Response Models

struct CommonFormsJobResponse: Codable {
    let jobId: String
}

struct CommonFormsResult: Codable {
    let status: String
    let outputPdfUrl: String?
    let fields: [DetectedField]?
    let documentId: String?
    let error: String?
}

struct DetectedField: Codable {
    let id: String
    let type: String
    let page: Int
    let bbox: [Double]
    let label: String?
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case uploadFailed
    case processFailed
    case fetchFailed
    case submitFailed
    case composeFailed
    case downloadFailed
    case commonFormsFailed
    case processingFailed(String)
    case invalidResponse
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .uploadFailed:
            return "Failed to upload document"
        case .processFailed:
            return "Failed to start processing"
        case .fetchFailed:
            return "Failed to fetch document details"
        case .submitFailed:
            return "Failed to submit values"
        case .composeFailed:
            return "Failed to start PDF composition"
        case .downloadFailed:
            return "Failed to get download URL"
        case .commonFormsFailed:
            return "Failed to start CommonForms processing"
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        case .invalidResponse:
            return "Invalid server response"
        case .timeout:
            return "Request timed out"
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
