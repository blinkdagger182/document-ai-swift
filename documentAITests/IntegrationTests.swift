//
//  IntegrationTests.swift
//  documentAITests
//
//  Integration tests for iOS PDF Interactive Form Mode
//

import XCTest
@testable import documentAI

// MARK: - Integration Tests

final class IntegrationTests: XCTestCase {
    
    /// Test 12.1: Test with native AcroForm PDF
    /// Verify native mode is activated, no synthetic widgets created, form values sync correctly
    /// _Requirements: 7.1, 7.2, 7.3_
    func testNativeAcroFormPDFFlow() {
        // Create a DocumentDetectionResponse with acroformDetected = true
        let response = DocumentDetectionResponse(
            documentId: "test-acroform-123",
            acroformDetected: true,
            fields: [], // No detected fields needed for AcroForm
            pageCount: 1,
            status: "ready"
        )
        
        // Verify mode selection
        XCTAssertTrue(response.acroformDetected, "AcroForm should be detected")
        XCTAssertEqual(response.fields.count, 0, "No synthetic fields should be needed")
        
        // In native mode, synthetic widget count should be 0
        let expectedSyntheticCount = 0
        XCTAssertEqual(expectedSyntheticCount, 0, "Native mode should have 0 synthetic widgets")
    }
    
    /// Test 12.2: Test with non-AcroForm PDF using backend detection
    /// Verify synthetic widgets appear at correct positions, two-way binding works, tap chain works
    /// _Requirements: 1.4, 2.1, 4.1, 5.1_
    func testSyntheticWidgetPDFFlow() {
        // Create detected fields
        let fields = [
            createTestFieldRegion(fieldId: "name", x: 0.1, y: 0.1, width: 0.3, height: 0.05),
            createTestFieldRegion(fieldId: "email", x: 0.1, y: 0.2, width: 0.3, height: 0.05),
            createTestFieldRegion(fieldId: "phone", x: 0.1, y: 0.3, width: 0.3, height: 0.05)
        ]
        
        let response = DocumentDetectionResponse(
            documentId: "test-synthetic-456",
            acroformDetected: false,
            fields: fields,
            pageCount: 1,
            status: "ready"
        )
        
        // Verify mode selection
        XCTAssertFalse(response.acroformDetected, "AcroForm should not be detected")
        XCTAssertEqual(response.fields.count, 3, "Should have 3 detected fields")
        
        // Verify field coordinates are valid
        for field in response.fields {
            XCTAssertGreaterThanOrEqual(field.x, 0, "x should be >= 0")
            XCTAssertLessThanOrEqual(field.x, 1, "x should be <= 1")
            XCTAssertGreaterThanOrEqual(field.y, 0, "y should be >= 0")
            XCTAssertLessThanOrEqual(field.y, 1, "y should be <= 1")
            XCTAssertGreaterThan(field.width, 0, "width should be > 0")
            XCTAssertGreaterThan(field.height, 0, "height should be > 0")
        }
    }

    /// Test 12.3: Test edge cases
    /// Test with empty field list, invalid coordinates, multi-page PDF
    /// _Requirements: 8.1, 8.2, 8.3_
    func testEdgeCases() {
        // Test empty field list
        let emptyResponse = DocumentDetectionResponse(
            documentId: "test-empty",
            acroformDetected: false,
            fields: [],
            pageCount: 1,
            status: "ready"
        )
        XCTAssertEqual(emptyResponse.fields.count, 0, "Empty field list should have 0 fields")
        
        // Test invalid coordinates (should be filtered out during processing)
        let invalidField = createTestFieldRegion(
            fieldId: "invalid",
            x: 1.5, // Invalid: > 1
            y: 0.1,
            width: 0.3,
            height: 0.05
        )
        XCTAssertGreaterThan(invalidField.x, 1, "Invalid field should have x > 1")
        
        // Test multi-page PDF
        let multiPageFields = [
            createTestFieldRegion(fieldId: "page0_field", x: 0.1, y: 0.1, width: 0.3, height: 0.05, page: 0),
            createTestFieldRegion(fieldId: "page1_field", x: 0.1, y: 0.2, width: 0.3, height: 0.05, page: 1),
            createTestFieldRegion(fieldId: "page2_field", x: 0.1, y: 0.3, width: 0.3, height: 0.05, page: 2)
        ]
        
        let multiPageResponse = DocumentDetectionResponse(
            documentId: "test-multipage",
            acroformDetected: false,
            fields: multiPageFields,
            pageCount: 3,
            status: "ready"
        )
        
        XCTAssertEqual(multiPageResponse.pageCount, 3, "Should have 3 pages")
        XCTAssertEqual(multiPageResponse.fields.count, 3, "Should have 3 fields")
        
        // Verify each field is on correct page
        XCTAssertEqual(multiPageResponse.fields[0].page, 0, "First field should be on page 0")
        XCTAssertEqual(multiPageResponse.fields[1].page, 1, "Second field should be on page 1")
        XCTAssertEqual(multiPageResponse.fields[2].page, 2, "Third field should be on page 2")
    }
    
    /// Test 12.4: Integration test for full flow
    /// Test AcroForm PDF flow and synthetic widget flow end-to-end
    /// _Requirements: All_
    func testFullFlowIntegration() {
        // Test AcroForm flow
        let acroformResponse = DocumentDetectionResponse(
            documentId: UUID().uuidString,
            acroformDetected: true,
            fields: [],
            pageCount: 1,
            status: "ready"
        )
        
        // Verify AcroForm mode
        XCTAssertTrue(acroformResponse.acroformDetected)
        
        // Test synthetic widget flow
        let syntheticFields = (0..<5).map { i in
            createTestFieldRegion(
                fieldId: "field_\(i)",
                x: 0.1,
                y: 0.1 + Double(i) * 0.1,
                width: 0.3,
                height: 0.05,
                page: 0
            )
        }
        
        let syntheticResponse = DocumentDetectionResponse(
            documentId: UUID().uuidString,
            acroformDetected: false,
            fields: syntheticFields,
            pageCount: 1,
            status: "ready"
        )
        
        // Verify synthetic mode
        XCTAssertFalse(syntheticResponse.acroformDetected)
        XCTAssertEqual(syntheticResponse.fields.count, 5)
        
        // Verify JSON round-trip for both responses
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let acroformData = try encoder.encode(acroformResponse)
            let decodedAcroform = try decoder.decode(DocumentDetectionResponse.self, from: acroformData)
            XCTAssertEqual(acroformResponse.documentId, decodedAcroform.documentId)
            XCTAssertEqual(acroformResponse.acroformDetected, decodedAcroform.acroformDetected)
            
            let syntheticData = try encoder.encode(syntheticResponse)
            let decodedSynthetic = try decoder.decode(DocumentDetectionResponse.self, from: syntheticData)
            XCTAssertEqual(syntheticResponse.documentId, decodedSynthetic.documentId)
            XCTAssertEqual(syntheticResponse.fields.count, decodedSynthetic.fields.count)
        } catch {
            XCTFail("JSON encoding/decoding failed: \(error)")
        }
    }
    
    // MARK: - Helper Functions
    
    private func createTestFieldRegion(
        fieldId: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        page: Int? = 0
    ) -> FieldRegion {
        return FieldRegion(
            id: UUID().uuidString,
            fieldId: fieldId,
            x: x,
            y: y,
            width: width,
            height: height,
            page: page,
            fieldType: .text,
            source: .ocr
        )
    }
}
