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
    let pdfViewSize: CGSize
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .clear
        
        // Load PDF document
        if let document = PDFDocument(url: pdfURL) {
            pdfView.document = document
            
            // Check if PDF has native form fields
            var hasNativeFields = false
            for pageIndex in 0..<document.pageCount {
                if let page = document.page(at: pageIndex),
                   !page.annotations.isEmpty {
                    hasNativeFields = true
                    print("📄 PDF has \(page.annotations.count) native annotations on page \(pageIndex)")
                    break
                }
            }
            
            if hasNativeFields {
                print("✅ PDF has native form fields - will use them directly")
            } else {
                print("⚠️ PDF has no native form fields - will create annotations")
            }
            
            // Add tap gesture recognizer for field overlays
            let tapGesture = UITapGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleTap(_:))
            )
            pdfView.addGestureRecognizer(tapGesture)
            
            context.coordinator.pdfView = pdfView
            context.coordinator.containerView = containerView
            
            // Create overlay layer for field boxes
            let overlayLayer = CALayer()
            overlayLayer.name = "fieldOverlay"
            context.coordinator.overlayLayer = overlayLayer
            
            containerView.addSubview(pdfView)
            containerView.layer.addSublayer(overlayLayer)
            
            pdfView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                pdfView.topAnchor.constraint(equalTo: containerView.topAnchor),
                pdfView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                pdfView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                pdfView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            
            // Draw field overlays after a short delay to ensure PDF is loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                context.coordinator.drawFieldOverlays()
                context.coordinator.updateNativeFields()
            }
        }
        
        return containerView
    }
    
    func updateUIView(_ containerView: UIView, context: Context) {
        guard let pdfView = context.coordinator.pdfView,
              let document = pdfView.document else { return }
        
        // First, try to update native PDF form fields
        context.coordinator.updateNativeFields()
        
        // Then update our custom annotations
        for (uuid, value) in formValues {
            // Find the field region for this UUID
            guard let fieldId = context.coordinator.uuidToFieldId(uuid),
                  let region = fieldRegions.first(where: { $0.fieldId == fieldId }),
                  let pageIndex = region.page,
                  let page = document.page(at: pageIndex) else {
                continue
            }
            
            // Find or create annotation for this field
            guard let annotation = findOrCreateAnnotation(
                for: region,
                on: page,
                fieldId: fieldId,
                pdfView: pdfView
            ) else {
                continue
            }
            
            // Update annotation value if changed
            let currentValue = annotation.contents ?? ""
            if currentValue != value {
                annotation.contents = value
                
                // Show background when there's text
                if !value.isEmpty {
                    annotation.color = UIColor.white.withAlphaComponent(0.9)
                } else {
                    annotation.color = .clear
                }
                
                // Force redraw
                page.removeAnnotation(annotation)
                page.addAnnotation(annotation)
                pdfView.setNeedsDisplay(pdfView.bounds)
            }
        }
        
        // Redraw field overlays when form values change
        context.coordinator.drawFieldOverlays()
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
        fieldId: String,
        pdfView: PDFView
    ) -> PDFAnnotation? {
        // Try to find existing annotation by field name
        if let existing = page.annotations.first(where: { $0.fieldName == fieldId }) {
            return existing
        }
        
        // Validate coordinates before creating annotation
        guard region.x.isFinite && region.y.isFinite && 
              region.width.isFinite && region.height.isFinite &&
              region.width > 0 && region.height > 0 else {
            print("⚠️ Cannot create annotation for field \(fieldId) - invalid coordinates")
            return nil
        }
        
        // Get page dimensions
        let pageBounds = page.bounds(for: .mediaBox)
        let pageWidth = pageBounds.width
        let pageHeight = pageBounds.height
        
        // Convert normalized coordinates (0-1) to PDF points
        // Backend sends normalized coordinates, PDF uses bottom-left origin
        let pdfX = region.x * pageWidth
        let pdfY = region.y * pageHeight
        let pdfWidth = region.width * pageWidth
        let pdfHeight = region.height * pageHeight
        
        let bounds = CGRect(
            x: pdfX,
            y: pdfY,
            width: pdfWidth,
            height: pdfHeight
        )
        
        print("📍 Creating annotation for \(fieldId): normalized(\(region.x), \(region.y), \(region.width), \(region.height)) -> pdf(\(pdfX), \(pdfY), \(pdfWidth), \(pdfHeight))")
        
        // Use FreeText annotation for better text rendering
        let annotation = PDFAnnotation(
            bounds: bounds,
            forType: .freeText,
            withProperties: nil
        )
        
        // Set annotation properties
        annotation.fieldName = fieldId
        annotation.font = UIFont.systemFont(ofSize: 10)
        annotation.fontColor = .black
        annotation.color = .clear  // No background initially
        annotation.contents = ""
        
        // Set alignment
        annotation.alignment = .left
        
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
        weak var containerView: UIView?
        var overlayLayer: CALayer?
        
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
        
        func drawFieldOverlays() {
            guard let pdfView = pdfView,
                  let document = pdfView.document,
                  let overlayLayer = overlayLayer else {
                return
            }
            
            // Clear existing sublayers
            overlayLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
            
            // Draw a box for each field region
            for region in fieldRegions {
                guard let pageIndex = region.page,
                      let page = document.page(at: pageIndex) else {
                    continue
                }
                
                // Validate coordinates - skip if invalid
                guard region.x.isFinite && region.y.isFinite && 
                      region.width.isFinite && region.height.isFinite &&
                      region.width > 0 && region.height > 0 else {
                    print("⚠️ Skipping field \(region.fieldId) - invalid coordinates: x=\(region.x), y=\(region.y), w=\(region.width), h=\(region.height)")
                    continue
                }
                
                // Get page dimensions
                let pageBounds = page.bounds(for: .mediaBox)
                let pageWidth = pageBounds.width
                let pageHeight = pageBounds.height
                
                // Convert normalized coordinates (0-1) to PDF points
                let pdfX = region.x * pageWidth
                let pdfY = region.y * pageHeight
                let pdfWidth = region.width * pageWidth
                let pdfHeight = region.height * pageHeight
                
                let pdfBounds = CGRect(
                    x: pdfX,
                    y: pdfY,
                    width: pdfWidth,
                    height: pdfHeight
                )
                
                let viewBounds = pdfView.convert(pdfBounds, from: page)
                
                // Validate converted bounds
                guard viewBounds.origin.x.isFinite && viewBounds.origin.y.isFinite &&
                      viewBounds.size.width.isFinite && viewBounds.size.height.isFinite &&
                      viewBounds.size.width > 0 && viewBounds.size.height > 0 else {
                    print("⚠️ Skipping field \(region.fieldId) - invalid view bounds after conversion")
                    continue
                }
                
                // Create a shape layer for the field box
                let boxLayer = CAShapeLayer()
                boxLayer.frame = viewBounds
                boxLayer.path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: viewBounds.size), cornerRadius: 4).cgPath
                
                // Check if this field has a value
                let hasValue = formValues[fieldIdToUUID[region.fieldId] ?? UUID()] != nil && 
                               !formValues[fieldIdToUUID[region.fieldId] ?? UUID()]!.isEmpty
                
                // Style the box
                boxLayer.strokeColor = hasValue ? UIColor.systemGreen.cgColor : UIColor.systemBlue.cgColor
                boxLayer.fillColor = UIColor.systemBlue.withAlphaComponent(0.1).cgColor
                boxLayer.lineWidth = 2.0
                boxLayer.lineDashPattern = [4, 4]
                
                overlayLayer.addSublayer(boxLayer)
            }
        }
        
        func uuidToFieldId(_ uuid: UUID) -> String? {
            return fieldIdToUUID.first(where: { $0.value == uuid })?.key
        }
        
        func updateNativeFields() {
            guard let pdfView = pdfView,
                  let document = pdfView.document else { return }
            
            // Try to update native PDF form fields if they exist
            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }
                
                for annotation in page.annotations {
                    // Check if this is a widget annotation (form field)
                    if annotation.type == "Widget" {
                        let fieldName = annotation.fieldName ?? ""
                        print("📝 Found native field: \(fieldName)")
                        
                        // Try to match with our field regions
                        if let uuid = fieldIdToUUID[fieldName],
                           let value = formValues[uuid] {
                            annotation.widgetStringValue = value
                            print("✅ Updated native field \(fieldName) with value: \(value)")
                        }
                    }
                }
            }
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
                
                // Get page dimensions
                let pageBounds = page.bounds(for: .mediaBox)
                let pageWidth = pageBounds.width
                let pageHeight = pageBounds.height
                
                // Convert normalized coordinates to PDF points
                let pdfX = region.x * pageWidth
                let pdfY = region.y * pageHeight
                let pdfWidth = region.width * pageWidth
                let pdfHeight = region.height * pageHeight
                
                let fieldBounds = CGRect(
                    x: pdfX,
                    y: pdfY,
                    width: pdfWidth,
                    height: pdfHeight
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
    var fieldName: String? {
        get {
            return value(forAnnotationKey: PDFAnnotationKey(rawValue: "/T")) as? String
        }
        set {
            setValue(newValue as Any?, forAnnotationKey: PDFAnnotationKey(rawValue: "/T"))
        }
    }
    
    var widgetStringValue: String? {
        get {
            return value(forAnnotationKey: .widgetValue) as? String
        }
        set {
            setValue(newValue, forAnnotationKey: .widgetValue)
        }
    }
}
