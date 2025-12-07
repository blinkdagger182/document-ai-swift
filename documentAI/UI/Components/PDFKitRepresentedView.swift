//
//  PDFKitRepresentedView.swift
//  documentAI
//
//  Hybrid PDF editor supporting both native AcroForm and synthetic widgets
//  Mode selection driven by backend acroformDetected flag
//

import SwiftUI
import PDFKit

struct PDFKitRepresentedView: UIViewRepresentable {
    let pdfURL: URL
    @Binding var formValues: [UUID: String]
    let detectedFields: [FieldRegion]  // Renamed from fieldRegions
    let fieldIdToUUID: [String: UUID]
    let acroformDetected: Bool  // NEW: Backend-driven mode flag
    let onFieldTapped: ((UUID) -> Void)?  // NEW: Tap callback
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            formValues: $formValues,
            detectedFields: detectedFields,
            fieldIdToUUID: fieldIdToUUID,
            acroformDetected: acroformDetected,
            onFieldTapped: onFieldTapped
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

        // Mode selection based on backend acroformDetected flag
        if acroformDetected {
            // Native AcroForm mode - use PDFKit's built-in interaction
            print("✅ AcroForm detected by backend - enabling native mode")
            context.coordinator.enableNativeMode()
        } else if !detectedFields.isEmpty {
            // Synthetic widget mode - create annotations from detected fields
            print("✅ Creating synthetic widgets from \(detectedFields.count) detected fields")
            context.coordinator.createSyntheticWidgets()
        } else {
            print("⚠️ No AcroForm fields or detected fields available")
        }
        
        // Add tap gesture recognizer for synthetic annotations
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tapGesture.delegate = context.coordinator
        pdfView.addGestureRecognizer(tapGesture)
        
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
        // Prevent duplicate annotation creation - only sync values
        context.coordinator.syncFormValuesToPDF()
    }
    
    static func dismantleUIView(_ pdfView: PDFView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    // MARK: - Coordinator
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        @Binding var formValues: [UUID: String]
        weak var pdfView: PDFView?
        weak var document: PDFDocument?
        
        let detectedFields: [FieldRegion]
        let fieldIdToUUID: [String: UUID]
        let acroformDetected: Bool
        let onFieldTapped: ((UUID) -> Void)?
        
        // Map fieldId → annotation for both native and synthetic widgets
        var annotationMap: [String: PDFAnnotation] = [:]
        // Track synthetic annotations for cleanup
        var syntheticAnnotations: Set<PDFAnnotation> = []
        // Track focused annotation for styling
        var focusedAnnotation: PDFAnnotation?
        // Track if widgets have been created to prevent duplicates
        var widgetsCreated: Bool = false
        
        init(
            formValues: Binding<[UUID: String]>,
            detectedFields: [FieldRegion],
            fieldIdToUUID: [String: UUID],
            acroformDetected: Bool,
            onFieldTapped: ((UUID) -> Void)?
        ) {
            self._formValues = formValues
            self.detectedFields = detectedFields
            self.fieldIdToUUID = fieldIdToUUID
            self.acroformDetected = acroformDetected
            self.onFieldTapped = onFieldTapped
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        // MARK: - Native Mode
        
        func enableNativeMode() {
            // Map existing AcroForm widgets to formValues
            // Do NOT create any synthetic overlays
            mapNativeWidgets()
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
            guard !widgetsCreated else {
                print("⚠️ Widgets already created, skipping")
                return
            }
            
            annotationMap.removeAll()
            syntheticAnnotations.removeAll()
            
            var successCount = 0
            var failureCount = 0
            
            for region in detectedFields {
                do {
                    try createWidget(for: region, in: document)
                    successCount += 1
                } catch {
                    print("⚠️ Failed to create widget for \(region.fieldId): \(error)")
                    failureCount += 1
                    // Continue with remaining fields
                }
            }
            
            widgetsCreated = true
            print("✅ Created \(successCount) widgets, \(failureCount) failures")
            
            // Force redraw
            pdfView?.setNeedsDisplay(pdfView?.bounds ?? .zero)
        }
        
        private func createWidget(for region: FieldRegion, in document: PDFDocument) throws {
            // Determine page index (default to 0 if not specified)
            let pageIndex = region.page ?? 0
            guard pageIndex < document.pageCount,
                  let page = document.page(at: pageIndex) else {
                throw WidgetCreationError.invalidPageIndex(pageIndex)
            }
            
            // Validate normalized coordinates
            guard isValidNormalizedCoordinates(region) else {
                throw WidgetCreationError.invalidCoordinates(region.fieldId)
            }
            
            // Convert normalized coordinates to PDF coordinates using exact formula
            let bounds = convertNormalizedToPDF(field: region, page: page)
            
            // Validate converted bounds
            guard isValidBounds(bounds, page: page) else {
                print("⚠️ Invalid bounds for field \(region.fieldId), skipping")
                throw WidgetCreationError.invalidBounds(region.fieldId)
            }
            
            // Create synthetic widget annotation
            let annotation = PDFAnnotation(bounds: bounds, forType: .widget, withProperties: nil)
            
            // Configure widget type based on field type
            let fieldType = region.fieldType ?? .text
            annotation.widgetFieldType = fieldType == .checkbox ? .button : .text
            annotation.fieldName = region.fieldId
            
            // Style like Files.app
            styleAnnotation(annotation, fieldType: fieldType)
            
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
        
        enum WidgetCreationError: Error {
            case invalidPageIndex(Int)
            case invalidCoordinates(String)
            case invalidBounds(String)
        }

        // MARK: - Coordinate Conversion (EXACT FORMULA)
        
        /// Convert normalized coordinates to PDF coordinates using exact formula from requirements
        /// y_pdf = pageHeight - (y_norm * pageHeight) - (h_norm * pageHeight)
        func convertNormalizedToPDF(field: FieldRegion, page: PDFPage) -> CGRect {
            let pageRect = page.bounds(for: .mediaBox)
            let pageWidth = pageRect.width
            let pageHeight = pageRect.height
            
            // Apply exact formula from requirements:
            // x_pdf = x_norm * pageWidth
            // y_pdf = pageHeight - (y_norm * pageHeight) - (h_norm * pageHeight)
            // width_pdf = w_norm * pageWidth
            // height_pdf = h_norm * pageHeight
            let x_pdf = CGFloat(field.x) * pageWidth
            let y_pdf = pageHeight - (CGFloat(field.y) * pageHeight) - (CGFloat(field.height) * pageHeight)
            let width_pdf = CGFloat(field.width) * pageWidth
            let height_pdf = CGFloat(field.height) * pageHeight
            
            return CGRect(x: x_pdf, y: y_pdf, width: width_pdf, height: height_pdf)
        }
        
        // MARK: - Coordinate Validation
        
        func isValidNormalizedCoordinates(_ field: FieldRegion) -> Bool {
            guard field.x >= 0 && field.x <= 1 else { return false }
            guard field.y >= 0 && field.y <= 1 else { return false }
            guard field.width > 0 && field.width <= 1 else { return false }
            guard field.height > 0 && field.height <= 1 else { return false }
            guard field.x + field.width <= 1 else { return false }
            guard field.y + field.height <= 1 else { return false }
            return true
        }
        
        func isValidBounds(_ bounds: CGRect, page: PDFPage) -> Bool {
            let pageRect = page.bounds(for: .mediaBox)
            return bounds.minX >= 0 &&
                   bounds.minY >= 0 &&
                   bounds.maxX <= pageRect.width &&
                   bounds.maxY <= pageRect.height &&
                   bounds.width > 0 &&
                   bounds.height > 0
        }

        // MARK: - Files.app Styling
        
        func styleAnnotation(_ annotation: PDFAnnotation, fieldType: FieldType) {
            // Default state (unfocused) - Files.app style
            annotation.backgroundColor = UIColor.white.withAlphaComponent(0.9)
            annotation.color = UIColor.systemGray4
            
            // Border (1pt, solid, gray)
            let border = PDFBorder()
            border.lineWidth = 1.0
            border.style = .solid
            annotation.border = border
            
            // Font (system font like Files.app)
            if fieldType != .checkbox {
                annotation.font = UIFont.systemFont(ofSize: 12, weight: .regular)
                annotation.fontColor = UIColor.black
            }
        }
        
        func applyFocusStyle(_ annotation: PDFAnnotation) {
            // Focused state - highlight border (blue, 2pt)
            annotation.color = UIColor.systemBlue
            annotation.backgroundColor = UIColor.white
            
            let border = PDFBorder()
            border.lineWidth = 2.0
            border.style = .solid
            annotation.border = border
            
            // Force redraw
            refreshAnnotation(annotation)
        }
        
        func removeFocusStyle(_ annotation: PDFAnnotation) {
            // Return to default state
            annotation.color = UIColor.systemGray4
            annotation.backgroundColor = UIColor.white.withAlphaComponent(0.9)
            
            let border = PDFBorder()
            border.lineWidth = 1.0
            border.style = .solid
            annotation.border = border
            
            refreshAnnotation(annotation)
        }
        
        func refreshAnnotation(_ annotation: PDFAnnotation) {
            annotation.removeValue(forAnnotationKey: .appearanceDictionary)
            
            if let page = annotation.page, let pdfView = pdfView {
                let viewRect = pdfView.convert(annotation.bounds, from: page)
                pdfView.setNeedsDisplay(viewRect)
            }
        }

        // MARK: - Two-Way Binding
        
        func syncFormValuesToPDF() {
            guard let pdfView = pdfView else { return }
            
            for (fieldId, annotation) in annotationMap {
                guard let uuid = fieldIdToUUID[fieldId] else { continue }
                
                let newValue = formValues[uuid] ?? ""
                let currentValue = annotation.widgetStringValue ?? ""
                
                if newValue != currentValue {
                    annotation.widgetStringValue = newValue
                    refreshAnnotation(annotation)
                }
            }
        }
        
        // MARK: - Tap Handling
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let pdfView = pdfView else { return }
            
            let location = gesture.location(in: pdfView)
            
            // Convert tap location to PDF page coordinates
            guard let page = pdfView.page(for: location, nearest: true) else { return }
            let pagePoint = pdfView.convert(location, to: page)
            
            // Check if tap hit any synthetic annotation
            var tappedAnnotation: PDFAnnotation?
            for annotation in syntheticAnnotations {
                if annotation.page == page && annotation.bounds.contains(pagePoint) {
                    tappedAnnotation = annotation
                    break
                }
            }
            
            if let annotation = tappedAnnotation {
                handleAnnotationTap(annotation)
            } else {
                // Tap outside all annotations - dismiss focus
                dismissFocus()
            }
        }
        
        func handleAnnotationTap(_ annotation: PDFAnnotation) {
            guard let fieldName = annotation.fieldName,
                  let uuid = fieldIdToUUID[fieldName] else { return }
            
            // Remove focus from previous annotation
            if let previous = focusedAnnotation, previous != annotation {
                removeFocusStyle(previous)
            }
            
            // Apply focus to tapped annotation
            applyFocusStyle(annotation)
            focusedAnnotation = annotation
            
            // Notify parent to scroll form panel
            onFieldTapped?(uuid)
            
            print("👆 Tapped field: \(fieldName)")
        }
        
        func dismissFocus() {
            if let focused = focusedAnnotation {
                removeFocusStyle(focused)
                focusedAnnotation = nil
            }
        }
        
        // MARK: - UIGestureRecognizerDelegate
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
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
            
            // Only update if value actually changed (preserves special characters)
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
