//
//  PDFKitRepresentedView.swift
//  documentAI
//
//  Pure native AcroForm editor using PDFKit's interactive form mode
//  Behaves EXACTLY like iOS Files.app - NO synthetic widgets, NO OCR fallback
//

import SwiftUI
import PDFKit

struct PDFKitRepresentedView: UIViewRepresentable {
    let pdfURL: URL
    @Binding var formValues: [UUID: String]
    let fieldRegions: [FieldRegion]
    let fieldIdToUUID: [String: UUID]
    let onFieldTapped: (UUID) -> Void
    let pdfViewSize: CGSize
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            formValues: $formValues,
            fieldIdToUUID: fieldIdToUUID,
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
        
        // Detect and map native AcroForm widgets
        context.coordinator.mapNativeWidgets()
        
        // Listen for annotation changes (when user edits fields)
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
        
        // Sync initial values from SwiftUI to PDF
        context.coordinator.syncFormValuesToPDF()
        
        print("✅ PDFKit interactive form mode enabled")
        
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
        let fieldIdToUUID: [String: UUID]
        let onFieldTapped: (UUID) -> Void
        
        weak var pdfView: PDFView?
        
        // Map fieldName → annotation for native widgets only
        var widgetMap: [String: PDFAnnotation] = [:]
        
        init(
            formValues: Binding<[UUID: String]>,
            fieldIdToUUID: [String: UUID],
            onFieldTapped: @escaping (UUID) -> Void
        ) {
            self._formValues = formValues
            self.fieldIdToUUID = fieldIdToUUID
            self.onFieldTapped = onFieldTapped
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        // MARK: - Native Widget Detection
        
        /// Map all native AcroForm widget annotations in the PDF
        func mapNativeWidgets() {
            guard let pdfView = pdfView,
                  let document = pdfView.document else { return }
            
            widgetMap.removeAll()
            
            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }
                
                for annotation in page.annotations {
                    // Only process text widget annotations (form fields)
                    if annotation.widgetFieldType == .text,
                       let fieldName = annotation.fieldName {
                        widgetMap[fieldName] = annotation
                        print("📋 Found native widget: \(fieldName)")
                    }
                }
            }
            
            if widgetMap.isEmpty {
                print("⚠️ No native AcroForm widgets found in PDF")
            } else {
                print("✅ Mapped \(widgetMap.count) native widgets")
            }
        }
        
        // MARK: - Sync: SwiftUI → PDF
        
        /// Sync SwiftUI formValues to PDF widget annotations
        func syncFormValuesToPDF() {
            guard let pdfView = pdfView else { return }
            
            for (fieldName, annotation) in widgetMap {
                // Find UUID for this field name
                guard let uuid = fieldIdToUUID[fieldName] else { continue }
                
                // Get new value from SwiftUI state
                let newValue = formValues[uuid] ?? ""
                
                // Get current value from annotation
                let currentValue = annotation.widgetStringValue ?? ""
                
                // Update if changed
                if newValue != currentValue {
                    annotation.widgetStringValue = newValue
                    
                    // Trigger redraw
                    if let page = annotation.page {
                        let viewRect = pdfView.convert(annotation.bounds, from: page)
                        pdfView.setNeedsDisplay(viewRect)
                    }
                    
                    print("🔄 Synced \(fieldName) = '\(newValue)'")
                }
            }
        }
        
        // MARK: - Notification Handlers
        
        @objc func annotationWillHit(_ notification: Notification) {
            guard let annotation = notification.userInfo?["PDFAnnotationHit"] as? PDFAnnotation,
                  let fieldName = annotation.fieldName,
                  let uuid = fieldIdToUUID[fieldName] else {
                return
            }
            
            print("👆 User tapped field: \(fieldName)")
            onFieldTapped(uuid)
        }
        
        @objc func annotationChanged(_ notification: Notification) {
            guard let annotation = notification.userInfo?["PDFAnnotationHit"] as? PDFAnnotation,
                  let fieldName = annotation.fieldName,
                  let uuid = fieldIdToUUID[fieldName] else {
                return
            }
            
            // Get the new value from the annotation (user typed in PDFKit's native editor)
            let newValue = annotation.widgetStringValue ?? ""
            
            // Update SwiftUI state
            formValues[uuid] = newValue
            
            print("✏️ Field \(fieldName) changed to: '\(newValue)'")
        }
    }
}

// MARK: - PDFAnnotation Extension

extension PDFAnnotation {
    /// Get field name (/T key)
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
    
    /// Get/set widget string value (/V key)
    var widgetStringValue: String? {
        get {
            return value(forAnnotationKey: .widgetValue) as? String
        }
        set {
            if let newValue = newValue {
                setValue(newValue as NSString, forAnnotationKey: .widgetValue)
                // Clear appearance stream to force regeneration
                removeValue(forAnnotationKey: .appearanceDictionary)
            } else {
                removeValue(forAnnotationKey: .widgetValue)
            }
        }
    }
}
