//
//  PDFKitRepresentedView.swift
//  documentAI
//
//  Hybrid PDF editor supporting both native AcroForm and synthetic widgets
//  Step 1: Native AcroForm fields (if present)
//  Step 2: Synthetic widgets from Vision-detected fieldRegions
//

import SwiftUI
import PDFKit

struct PDFKitRepresentedView: UIViewRepresentable {
    let pdfURL: URL
    @Binding var formValues: [UUID: String]
    let fieldRegions: [FieldRegion]
    let fieldIdToUUID: [String: UUID]
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            formValues: $formValues,
            fieldRegions: fieldRegions,
            fieldIdToUUID: fieldIdToUUID
        )
    }
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        
        // Configure for native form editing (Files.app mode)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = .clear
        
        // Enable interactive form mode (critical for Files.app behavior)
        if #available(iOS 16.0, *) {
            pdfView.isInMarkupMode = false
        }
        
        // Load PDF document
        guard let document = PDFDocument(url: pdfURL) else {
            print("❌ Failed to load PDF")
            return pdfView
        }
        
        pdfView.document = document
        context.coordinator.pdfView = pdfView
        context.coordinator.document = document
        
        // Detect mode: AcroForm vs Synthetic
        let hasAcroForm = document.hasAcroFormFields
        
        if hasAcroForm {
            // Step 1: Native AcroForm mode
            print("✅ PDF has native AcroForm fields")
            context.coordinator.mapNativeWidgets()
        } else if !fieldRegions.isEmpty {
            // Step 2: Synthetic widget mode
            print("✅ Creating synthetic widgets from \(fieldRegions.count) field regions")
            context.coordinator.createSyntheticWidgets()
        } else {
            print("⚠️ No AcroForm fields or field regions available")
        }
        
        // Listen for annotation changes
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.annotationChanged(_:)),
            name: .PDFViewAnnotationHit,
            object: pdfView
        )
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.annotationWillHit(_:)),
            name: .PDFViewAnnotationWillHit,
            object: pdfView
        )
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Sync SwiftUI form values to PDF annotations
        context.coordinator.syncFormValuesToPDF()
    }
    
    static func dismantleUIView(_ pdfView: PDFView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject {
        @Binding var formValues: [UUID: String]
        weak var pdfView: PDFView?
        weak var document: PDFDocument?
        
        let fieldRegions: [FieldRegion]
        let fieldIdToUUID: [String: UUID]
        
        // Map fieldId → annotation for both native and synthetic widgets
        var annotationMap: [String: PDFAnnotation] = [:]
        // Track synthetic annotations for cleanup
        var syntheticAnnotations: Set<PDFAnnotation> = []
        
        init(
            formValues: Binding<[UUID: String]>,
            fieldRegions: [FieldRegion],
            fieldIdToUUID: [String: UUID]
        ) {
            self._formValues = formValues
            self.fieldRegions = fieldRegions
            self.fieldIdToUUID = fieldIdToUUID
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        // MARK: - Native Widget Detection
        
        func mapNativeWidgets() {
            guard let document = document else { return }
            
            annotationMap.removeAll()
            
            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }
                
                for annotation in page.annotations {
                    if annotation.widgetFieldType == .text,
                       let fieldName = annotation.fieldName {
                        annotationMap[fieldName] = annotation
                        
                        // Initialize formValues with current annotation value if UUID exists
                        if let uuid = fieldIdToUUID[fieldName] {
                            let currentValue = annotation.widgetStringValue ?? ""
                            if !currentValue.isEmpty {
                                formValues[uuid] = currentValue
                            }
                        }
                        
                        print("📋 Mapped native widget: \(fieldName)")
                    }
                }
            }
            
            print("✅ Found \(annotationMap.count) native AcroForm fields")
        }
        
        // MARK: - Synthetic Widget Creation
        
        func createSyntheticWidgets() {
            guard let document = document else { return }
            
            annotationMap.removeAll()
            syntheticAnnotations.removeAll()
            
            for region in fieldRegions {
                // Determine page index (default to 0 if not specified)
                let pageIndex = region.page ?? 0
                guard pageIndex < document.pageCount,
                      let page = document.page(at: pageIndex) else {
                    print("⚠️ Invalid page index \(pageIndex) for field \(region.fieldId)")
                    continue
                }
                
                // Convert normalized coordinates to PDF coordinates
                let bounds = normalizedToPDFRect(
                    normalized: CGRect(x: region.x, y: region.y, width: region.width, height: region.height),
                    page: page
                )
                
                // Create synthetic widget annotation
                let annotation = PDFAnnotation(bounds: bounds, forType: .widget, withProperties: nil)
                
                // Configure widget type based on field type
                let widgetType: PDFAnnotationWidgetSubtype = {
                    switch region.fieldType {
                    case .checkbox:
                        return .button
                    case .signature:
                        return .text // Signature fields are text fields in PDF
                    default:
                        return .text
                    }
                }()
                
                annotation.widgetFieldType = widgetType
                annotation.fieldName = region.fieldId
                
                // Style like Files.app
                annotation.backgroundColor = UIColor.white.withAlphaComponent(0.9)
                annotation.color = UIColor.black
                
                // Configure font for text fields
                if widgetType == .text {
                    annotation.font = UIFont.systemFont(ofSize: 12)
                    annotation.fontColor = UIColor.black
                }
                
                // Add border
                let border = PDFBorder()
                border.lineWidth = 1.0
                border.style = .solid
                annotation.border = border
                
                // Initialize with current form value if exists
                if let uuid = fieldIdToUUID[region.fieldId],
                   let value = formValues[uuid], !value.isEmpty {
                    annotation.widgetStringValue = value
                }
                
                // Add to page
                page.addAnnotation(annotation)
                
                // Track annotation
                annotationMap[region.fieldId] = annotation
                syntheticAnnotations.insert(annotation)
                
                print("✨ Created synthetic widget: \(region.fieldId) at page \(pageIndex), bounds: \(bounds)")
            }
            
            print("✅ Created \(syntheticAnnotations.count) synthetic widgets")
            
            // Force redraw
            pdfView?.setNeedsDisplay(pdfView?.bounds ?? .zero)
        }
        
        // MARK: - Coordinate Conversion
        
        /// Convert normalized coordinates (0-1, bottom-left origin) to PDF coordinates
        private func normalizedToPDFRect(normalized: CGRect, page: PDFPage) -> CGRect {
            let pageRect = page.bounds(for: .mediaBox)
            
            let px = normalized.origin.x * pageRect.width
            let py = normalized.origin.y * pageRect.height
            let pw = normalized.width * pageRect.width
            let ph = normalized.height * pageRect.height
            
            return CGRect(x: px, y: py, width: pw, height: ph)
        }
        
        // MARK: - Sync
        
        func syncFormValuesToPDF() {
            guard let pdfView = pdfView else { return }
            
            for (fieldId, annotation) in annotationMap {
                guard let uuid = fieldIdToUUID[fieldId] else { continue }
                
                let newValue = formValues[uuid] ?? ""
                let currentValue = annotation.widgetStringValue ?? ""
                
                if newValue != currentValue {
                    annotation.widgetStringValue = newValue
                    
                    // Clear appearance stream to force regeneration
                    annotation.removeValue(forAnnotationKey: .appearanceDictionary)
                    
                    // Trigger redraw
                    if let page = annotation.page {
                        let viewRect = pdfView.convert(annotation.bounds, from: page)
                        pdfView.setNeedsDisplay(viewRect)
                    }
                }
            }
        }
        
        // MARK: - Notification Handlers
        
        @objc func annotationWillHit(_ notification: Notification) {
            guard let annotation = notification.userInfo?["PDFAnnotationHit"] as? PDFAnnotation,
                  let fieldName = annotation.fieldName else {
                return
            }
            print("👆 Annotation will hit: \(fieldName)")
        }
        
        @objc func annotationChanged(_ notification: Notification) {
            guard let annotation = notification.userInfo?["PDFAnnotationHit"] as? PDFAnnotation,
                  let fieldName = annotation.fieldName,
                  let uuid = fieldIdToUUID[fieldName] else {
                return
            }
            
            let newValue = annotation.widgetStringValue ?? ""
            
            // Only update if value actually changed
            if formValues[uuid] != newValue {
                formValues[uuid] = newValue
                print("✏️ Field \(fieldName) = '\(newValue)'")
            }
        }
    }
}

// MARK: - PDFAnnotation Extension

extension PDFAnnotation {
    var fieldName: String? {
        get {
            return value(forAnnotationKey: PDFAnnotationKey(rawValue: "/T")) as? String
        }
        set {
            if let newValue = newValue {
                setValue(newValue as NSString, forAnnotationKey: PDFAnnotationKey(rawValue: "/T"))
            } else {
                removeValue(forAnnotationKey: PDFAnnotationKey(rawValue: "/T"))
            }
        }
    }
    
    var widgetStringValue: String? {
        get {
            return value(forAnnotationKey: .widgetValue) as? String
        }
        set {
            if let newValue = newValue {
                setValue(newValue as NSString, forAnnotationKey: .widgetValue)
                removeValue(forAnnotationKey: .appearanceDictionary)
            } else {
                removeValue(forAnnotationKey: .widgetValue)
            }
        }
    }
}
