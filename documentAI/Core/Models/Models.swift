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
    let fieldId: String?
    let type: FieldType
    let label: String
    let placeholder: String?
    let options: [String]?
    let value: AnyCodable?
    let pageIndex: Int?
    let defaultValue: String?
    
    enum CodingKeys: String, CodingKey {
        case id, fieldId, type, label, placeholder, options, value, pageIndex, defaultValue
    }
    
    init(id: String, fieldId: String? = nil, type: FieldType, label: String, placeholder: String? = nil, options: [String]? = nil, value: AnyCodable? = nil, pageIndex: Int? = nil, defaultValue: String? = nil) {
        self.id = id
        self.fieldId = fieldId ?? id
        self.type = type
        self.label = label
        self.placeholder = placeholder
        self.options = options
        self.value = value
        self.pageIndex = pageIndex
        self.defaultValue = defaultValue
    }
}

enum FieldType: String, Codable {
    case text
    case textarea
    case multiline
    case select
    case checkbox
    case button
    case date
    case number
    case email
    case phone
    case signature
    case unknown
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

// MARK: - Field Region (for PDF coordinate mapping)
struct FieldRegion: Identifiable, Codable {
    let id: String
    let fieldId: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let page: Int?
    let source: FieldSource
    
    enum FieldSource: String, Codable {
        case acroform = "acroform"  // Native PDF form field
        case ocr = "ocr"            // OCR-detected field
    }
    
    init(id: String = UUID().uuidString, fieldId: String, x: Double, y: Double, width: Double, height: Double, page: Int?, source: FieldSource = .acroform) {
        self.id = id
        self.fieldId = fieldId
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.page = page
        self.source = source
    }
    
    // Convert from FieldMetadata
    static func from(fieldId: String, metadata: FieldMetadata, source: FieldSource = .acroform) -> FieldRegion? {
        guard let x = metadata.x,
              let y = metadata.y,
              let width = metadata.width,
              let height = metadata.height else {
            return nil
        }
        
        return FieldRegion(
            fieldId: fieldId,
            x: x,
            y: y,
            width: width,
            height: height,
            page: metadata.page,
            source: source
        )
    }
}

// MARK: - Form Data
typealias FormData = [String: String]

// MARK: - API Response Models
struct ProcessResult: Codable {
    let documentId: String
    let components: [FieldComponent]
    let fieldMap: FieldMap
    let fieldRegions: [FieldRegion]?
    let pdfURL: URL?
    
    // Computed property to get field regions from fieldMap if not provided
    var regions: [FieldRegion] {
        if let fieldRegions = fieldRegions {
            return fieldRegions
        }
        
        // Convert fieldMap to fieldRegions
        return fieldMap.compactMap { (fieldId, metadata) in
            FieldRegion.from(fieldId: fieldId, metadata: metadata)
        }
    }
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
