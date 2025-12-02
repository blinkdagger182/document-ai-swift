//
//  Models.swift
//  documentAI
//
//  Core data models for document processing
//

import Foundation

// MARK: - Document Model
struct DocumentModel: Identifiable, Codable {
    let id: String
    let name: String
    let url: URL
    let mimeType: String
    let sizeInBytes: Int64?
    
    var isImage: Bool {
        mimeType.hasPrefix("image/")
    }
    
    var isPDF: Bool {
        mimeType == "application/pdf"
    }
    
    var sizeInKB: String {
        guard let bytes = sizeInBytes else { return "0" }
        return String(format: "%.2f", Double(bytes) / 1024.0)
    }
}

// MARK: - Field Component
struct FieldComponent: Identifiable, Codable {
    let id: String
    let type: FieldType
    let label: String
    let placeholder: String?
    let options: [String]?
    let value: AnyCodable?
    
    enum CodingKeys: String, CodingKey {
        case id, type, label, placeholder, options, value
    }
}

enum FieldType: String, Codable {
    case text
    case textarea
    case select
    case checkbox
    case button
    case date
    case number
    case email
    case phone
}

// MARK: - AnyCodable for flexible JSON handling
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Field Map (stub for coordinate mapping)
typealias FieldMap = [String: FieldMetadata]

struct FieldMetadata: Codable {
    let x: Double?
    let y: Double?
    let width: Double?
    let height: Double?
    let page: Int?
    
    // Stub - will be populated by backend
}

// MARK: - Form Data
typealias FormData = [String: String]

// MARK: - API Response Models
struct ProcessResult: Codable {
    let documentId: String
    let components: [FieldComponent]
    let fieldMap: FieldMap
}

struct OverlayResult: Codable {
    let localPdfURL: URL
}

// MARK: - Upload Progress
struct UploadProgress {
    let percentage: Double
    let bytesUploaded: Int64
    let totalBytes: Int64
}
