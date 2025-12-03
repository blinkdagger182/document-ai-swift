//
//  PDFKitRepresentedView.swift
//  documentAI
//
//  PDFKit wrapper with two-way binding to formValues
//

import SwiftUI
import PDFKit

struct PDFKitRepresentedView: UIViewRepresentable {
    let pdfURL: URL
    @Binding var formValues: [UUID: String]
    let fieldRegions: [FieldRegion]
    let fieldIdToUUID: [String: UUID]
    let onFieldTapped: (UUID) -> Void
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        // Load PDF document
        if let document = PDFDocument(url: pdfURL) {
            pdfView.document = document
            
            // Add tap gesture recognizer for field overlays
            let tapGesture = UITapGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleTap(_:))
            )
            pdfView.addGestureRecognizer(tapGesture)
            
            context.coordinator.pdfView = pdfView
        }
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        guard let document = pdfView.document else { return }
        
        // Update PDF annotations with current formValues
        for (uuid, value) in formValues {
            // Find the field region for this UUID
            guard let fieldId = context.coordinator.uuidToFieldId(uuid),
                  let region = fieldRegions.first(where: { $0.fieldId == fieldId }),
                  let pageIndex = region.page,
                  let page = document.page(at: pageIndex) else {
                continue
            }
            
            // Find or create annotation for this field
            let annotation = findOrCreateAnnotation(
                for: region,
                on: page,
                fieldId: fieldId
            )
            
            // Update annotation value if changed
            if annotation.widgetStringValue != value {
                annotation.widgetStringValue = value
                
                // Force redraw only for this annotation's bounds
                pdfView.setNeedsDisplay(annotation.bounds)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            formValues: $formValues,
            fieldRegions: fieldRegions,
            fieldIdToUUID: fieldIdToUUID,
            onFieldTapped: onFieldTapped
        )
    }
    
    // MARK: - Find or Create Annotation
    private func findOrCreateAnnotation(
        for region: FieldRegion,
        on page: PDFPage,
        fieldId: String
    ) -> PDFAnnotation {
        // Try to find existing annotation by field name
        if let existing = page.annotations.first(where: { $0.fieldName == fieldId }) {
            return existing
        }
        
        // Create new text widget annotation
        let bounds = CGRect(
            x: region.x,
            y: region.y,
            width: region.width,
            height: region.height
        )
        
        let annotation = PDFAnnotation(
            bounds: bounds,
            forType: .widget,
            withProperties: nil
        )
        annotation.fieldName = fieldId
        annotation.widgetFieldType = .text
        annotation.font = UIFont.systemFont(ofSize: 12)
        annotation.fontColor = .black
        annotation.backgroundColor = UIColor.white.withAlphaComponent(0.8)
        
        page.addAnnotation(annotation)
        
        return annotation
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject {
        @Binding var formValues: [UUID: String]
        let fieldRegions: [FieldRegion]
        let fieldIdToUUID: [String: UUID]
        let onFieldTapped: (UUID) -> Void
        weak var pdfView: PDFView?
        
        init(
            formValues: Binding<[UUID: String]>,
            fieldRegions: [FieldRegion],
            fieldIdToUUID: [String: UUID],
            onFieldTapped: @escaping (UUID) -> Void
        ) {
            self._formValues = formValues
            self.fieldRegions = fieldRegions
            self.fieldIdToUUID = fieldIdToUUID
            self.onFieldTapped = onFieldTapped
        }
        
        func uuidToFieldId(_ uuid: UUID) -> String? {
            return fieldIdToUUID.first(where: { $0.value == uuid })?.key
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let pdfView = pdfView else { return }
            
            let location = gesture.location(in: pdfView)
            
            // Convert to PDF coordinates
            guard let page = pdfView.page(for: location, nearest: true) else {
                return
            }
            
            let pagePoint = pdfView.convert(location, to: page)
            
            // Check if tap is within any field region
            for region in fieldRegions {
                guard let pageIndex = region.page,
                      let currentPage = pdfView.document?.page(at: pageIndex),
                      currentPage == page else {
                    continue
                }
                
                let fieldBounds = CGRect(
                    x: region.x,
                    y: region.y,
                    width: region.width,
                    height: region.height
                )
                
                if fieldBounds.contains(pagePoint) {
                    // Field tapped - notify parent
                    if let uuid = fieldIdToUUID[region.fieldId] {
                        onFieldTapped(uuid)
                    }
                    break
                }
            }
        }
    }
}

// MARK: - PDF Annotation Extension
extension PDFAnnotation {
    var widgetStringValue: String? {
        get {
            return value(forAnnotationKey: .widgetValue) as? String
        }
        set {
            setValue(newValue, forAnnotationKey: .widgetValue)
        }
    }
    
    var fieldName: String? {
        get {
            return value(forAnnotationKey: PDFAnnotationKey(rawValue: "/T")) as? String
        }
        set {
            setValue(newValue as Any?, forAnnotationKey: PDFAnnotationKey(rawValue: "/T"))
        }
    }
    
    var widgetFieldType: PDFAnnotationWidgetSubtype {
        get {
            if let typeString = value(forAnnotationKey: .widgetFieldType) as? String {
                return PDFAnnotationWidgetSubtype(rawValue: typeString) ?? .text
            }
            return .text
        }
        set {
            setValue(newValue.rawValue, forAnnotationKey: .widgetFieldType)
        }
    }
}
