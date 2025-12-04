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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                context.coordinator.drawFieldOverlays()
            }
        }
        
        return containerView
    }
    
    func updateUIView(_ containerView: UIView, context: Context) {
        guard let pdfView = context.coordinator.pdfView,
              let document = pdfView.document else { return }
        
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
                fieldId: fieldId,
                pdfView: pdfView
            )
            
            // Update annotation value if changed
            if annotation.widgetStringValue != value {
                annotation.widgetStringValue = value
                
                // Force redraw only for this annotation's bounds
                pdfView.setNeedsDisplay(annotation.bounds)
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
    ) -> PDFAnnotation {
        // Try to find existing annotation by field name
        if let existing = page.annotations.first(where: { $0.fieldName == fieldId }) {
            return existing
        }
        
        // Convert backend coordinates to PDF coordinates
        // Backend sends coordinates in PDF points (origin bottom-left)
        let pageBounds = page.bounds(for: .mediaBox)
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
        annotation.border = PDFBorder()
        annotation.border?.lineWidth = 1.0
        
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
                
                // Convert PDF coordinates to view coordinates
                let pdfBounds = CGRect(
                    x: region.x,
                    y: region.y,
                    width: region.width,
                    height: region.height
                )
                
                let viewBounds = pdfView.convert(pdfBounds, from: page)
                
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
