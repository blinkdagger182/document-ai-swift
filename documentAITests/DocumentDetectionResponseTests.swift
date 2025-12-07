//
//  DocumentDetectionResponseTests.swift
//  documentAITests
//
//  Property-based tests for DocumentDetectionResponse JSON serialization
//

import XCTest
@testable import documentAI

// MARK: - Random Generators for Property-Based Testing

/// Simple random generator utilities for property-based testing
struct RandomGen {
    static func randomString(length: Int = 10) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    
    static func randomDouble(in range: ClosedRange<Double>) -> Double {
        Double.random(in: range)
    }
    
    static func randomInt(in range: ClosedRange<Int>) -> Int {
        Int.random(in: range)
    }
    
    static func randomBool() -> Bool {
        Bool.random()
    }
    
    static func randomFieldType() -> FieldType {
        let types: [FieldType] = [.text, .textarea, .multiline, .select, .checkbox, .button, .date, .number, .email, .phone, .signature, .unknown]
        return types.randomElement()!
    }
    
    static func randomFieldSource() -> FieldRegion.FieldSource {
        [FieldRegion.FieldSource.acroform, .ocr].randomElement()!
    }
    
    static func randomFieldRegion() -> FieldRegion {
        FieldRegion(
            id: UUID().uuidString,
            fieldId: randomString(length: randomInt(in: 5...15)),
            x: randomDouble(in: 0.0...1.0),
            y: randomDouble(in: 0.0...1.0),
            width: randomDouble(in: 0.01...0.5),
            height: randomDouble(in: 0.01...0.5),
            page: randomBool() ? randomInt(in: 0...10) : nil,
            fieldType: randomBool() ? randomFieldType() : nil,
            source: randomFieldSource()
        )
    }
    
    static func randomDocumentDetectionResponse() -> DocumentDetectionResponse {
        let fieldCount = randomInt(in: 0...20)
        let fields = (0..<fieldCount).map { _ in randomFieldRegion() }
        let statuses = ["ready", "processing", "completed", "error"]
        
        return DocumentDetectionResponse(
            documentId: UUID().uuidString,
            acroformDetected: randomBool(),
            fields: fields,
            pageCount: randomInt(in: 1...100),
            status: statuses.randomElement()!
        )
    }
}

// MARK: - Property-Based Tests

final class DocumentDetectionResponseTests: XCTestCase {
    
    /// Number of iterations for property-based tests
    private let iterations = 100
    
    /// **Feature: ios-pdf-interactive-form-mode, Property: JSON serialization round-trip**
    /// **Validates: Requirements 6.1**
    ///
    /// *For any* valid DocumentDetectionResponse, encoding to JSON and decoding back
    /// should produce an equivalent object.
    func testJSONRoundTrip() {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for i in 0..<iterations {
            let original = RandomGen.randomDocumentDetectionResponse()
            
            do {
                let jsonData = try encoder.encode(original)
                let decoded = try decoder.decode(DocumentDetectionResponse.self, from: jsonData)
                
                // Verify all top-level fields match
                XCTAssertEqual(original.documentId, decoded.documentId, "documentId mismatch at iteration \(i)")
                XCTAssertEqual(original.acroformDetected, decoded.acroformDetected, "acroformDetected mismatch at iteration \(i)")
                XCTAssertEqual(original.pageCount, decoded.pageCount, "pageCount mismatch at iteration \(i)")
                XCTAssertEqual(original.status, decoded.status, "status mismatch at iteration \(i)")
                XCTAssertEqual(original.fields.count, decoded.fields.count, "fields count mismatch at iteration \(i)")
                
                // Verify each field matches
                for (j, (origField, decodedField)) in zip(original.fields, decoded.fields).enumerated() {
                    XCTAssertEqual(origField.id, decodedField.id, "Field \(j) id mismatch at iteration \(i)")
                    XCTAssertEqual(origField.fieldId, decodedField.fieldId, "Field \(j) fieldId mismatch at iteration \(i)")
                    XCTAssertEqual(origField.x, decodedField.x, accuracy: 0.0001, "Field \(j) x mismatch at iteration \(i)")
                    XCTAssertEqual(origField.y, decodedField.y, accuracy: 0.0001, "Field \(j) y mismatch at iteration \(i)")
                    XCTAssertEqual(origField.width, decodedField.width, accuracy: 0.0001, "Field \(j) width mismatch at iteration \(i)")
                    XCTAssertEqual(origField.height, decodedField.height, accuracy: 0.0001, "Field \(j) height mismatch at iteration \(i)")
                    XCTAssertEqual(origField.page, decodedField.page, "Field \(j) page mismatch at iteration \(i)")
                    XCTAssertEqual(origField.fieldType, decodedField.fieldType, "Field \(j) fieldType mismatch at iteration \(i)")
                    XCTAssertEqual(origField.source, decodedField.source, "Field \(j) source mismatch at iteration \(i)")
                }
            } catch {
                XCTFail("JSON round-trip failed at iteration \(i): \(error)")
            }
        }
    }
    
    /// Test that snake_case JSON keys are correctly mapped to camelCase properties
    func testSnakeCaseDecoding() {
        let json = """
        {
            "document_id": "test-123",
            "acroform_detected": true,
            "fields": [],
            "page_count": 5,
            "status": "ready"
        }
        """
        
        let decoder = JSONDecoder()
        
        do {
            let response = try decoder.decode(DocumentDetectionResponse.self, from: json.data(using: .utf8)!)
            XCTAssertEqual(response.documentId, "test-123")
            XCTAssertTrue(response.acroformDetected)
            XCTAssertEqual(response.fields.count, 0)
            XCTAssertEqual(response.pageCount, 5)
            XCTAssertEqual(response.status, "ready")
        } catch {
            XCTFail("Failed to decode JSON: \(error)")
        }
    }
    
    /// Test encoding produces snake_case keys
    func testSnakeCaseEncoding() {
        let response = DocumentDetectionResponse(
            documentId: "test-456",
            acroformDetected: false,
            fields: [],
            pageCount: 3,
            status: "processing"
        )
        
        let encoder = JSONEncoder()
        
        do {
            let jsonData = try encoder.encode(response)
            let jsonString = String(data: jsonData, encoding: .utf8)!
            
            XCTAssertTrue(jsonString.contains("\"document_id\""))
            XCTAssertTrue(jsonString.contains("\"acroform_detected\""))
            XCTAssertTrue(jsonString.contains("\"page_count\""))
        } catch {
            XCTFail("Failed to encode: \(error)")
        }
    }
    
    /// Test with fields containing special characters in fieldId
    func testSpecialCharactersInFieldId() {
        for _ in 0..<iterations {
            let specialChars = "!@#$%^&*()_+-=[]{}|;':\",./<>?"
            let fieldId = "field_" + String((0..<5).map { _ in specialChars.randomElement()! })
            
            let field = FieldRegion(
                id: UUID().uuidString,
                fieldId: fieldId,
                x: 0.1,
                y: 0.2,
                width: 0.3,
                height: 0.1,
                page: 0,
                fieldType: .text,
                source: .ocr
            )
            
            let response = DocumentDetectionResponse(
                documentId: UUID().uuidString,
                acroformDetected: false,
                fields: [field],
                pageCount: 1,
                status: "ready"
            )
            
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            do {
                let jsonData = try encoder.encode(response)
                let decoded = try decoder.decode(DocumentDetectionResponse.self, from: jsonData)
                
                XCTAssertEqual(response.fields[0].fieldId, decoded.fields[0].fieldId, "Special characters not preserved")
            } catch {
                XCTFail("Failed with special characters: \(error)")
            }
        }
    }
}
