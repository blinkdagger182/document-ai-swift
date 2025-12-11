//
//  AnnotatedPDFView.swift
//  documentAI
//
//  PDF viewer with CommonForms bounding box annotations
//

import SwiftUI
import PDFKit

struct AnnotatedPDFView: UIViewRepresentable {
    let pdfURL: URL
    let detectedFields: [DetectedField]
    @Binding var currentPage: Int
    @Binding var isZoomedIn: Bool
    var onFieldTapped: ((DetectedField) -> Void)?
    var onTap: (() -> Void)?
    
    // Track focused field for styling
    @State private var focusedFieldId: String?
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        
        print("🔧 Configuring PDFView...")
        
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.usePageViewController(false)
        pdfView.backgroundColor = UIColor.systemGray6
        pdfView.isUserInteractionEnabled = true
        pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
        pdfView.maxScaleFactor = 4.0
        
        if let document = PDFDocument(url: pdfURL) {
            pdfView.document = document
            print("📄 PDF loaded: \(document.pageCount) pages")
            
            // Add annotations for detected fields
            context.coordinator.addAnnotations(to: pdfView, fields: detectedFields)
            
            // Verify annotations were added
            if let firstPage = document.page(at: 0) {
                print("🔍 Page 0 has \(firstPage.annotations.count) annotations")
            }
        } else {
            print("❌ Failed to load PDF from: \(pdfURL.path)")
        }
        
        if let scrollView = pdfView.subviews.first as? UIScrollView {
            scrollView.isScrollEnabled = true
            scrollView.bounces = true
            scrollView.bouncesZoom = true
            scrollView.contentInsetAdjustmentBehavior = .never
        }
        
        let singleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        pdfView.addGestureRecognizer(singleTapGesture)
        
        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        pdfView.addGestureRecognizer(doubleTapGesture)
        
        singleTapGesture.require(toFail: doubleTapGesture)
        
        context.coordinator.pdfView = pdfView
        context.coordinator.parent = self
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scaleChanged(_:)),
            name: .PDFViewScaleChanged,
            object: pdfView
        )
        
        print("✅ PDFView setup complete")
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let document = pdfView.document,
           currentPage < document.pageCount,
           let page = document.page(at: currentPage),
           pdfView.currentPage != page {
            pdfView.go(to: page)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: AnnotatedPDFView
        weak var pdfView: PDFView?
        var annotationMap: [String: PDFAnnotation] = [:]
        var focusedAnnotation: PDFAnnotation?
        
        init(_ parent: AnnotatedPDFView) {
            self.parent = parent
        }
        
        func addAnnotations(to pdfView: PDFView, fields: [DetectedField]) {
            guard let document = pdfView.document else {
                print("❌ No PDF document found for annotations")
                return
            }
            
            print("📍 Adding \(fields.count) annotations to PDF")
            var annotationCount = 0
            annotationMap.removeAll()
            
            for field in fields {
                guard field.page < document.pageCount,
                      let page = document.page(at: field.page) else {
                    print("⚠️ Skipping field on invalid page \(field.page)")
                    continue
                }
                
                let annotation = createBoundingBoxAnnotation(field, page: page)
                page.addAnnotation(annotation)
                annotationMap[field.id] = annotation
                annotationCount += 1
            }
            
            print("✅ Added \(annotationCount) annotations successfully")
            
            // Force redraw
            pdfView.setNeedsDisplay(pdfView.bounds)
        }
        
        func createBoundingBoxAnnotation(_ field: DetectedField, page: PDFPage) -> PDFAnnotation {
            // CommonForms bbox format: [x1, y1, x2, y2] in NORMALIZED coordinates (0-1)
            // PDF coordinate system: bottom-left origin in POINTS
            let pageBounds = page.bounds(for: .mediaBox)
            let pageWidth = pageBounds.width
            let pageHeight = pageBounds.height
            
            print("  📐 Page bounds: \(pageBounds)")
            print("  📦 Field bbox (normalized): \(field.bbox)")
            
            // bbox is [x1, y1, x2, y2] so we need to calculate width and height
            let x1_norm = field.bbox[0]
            let y1_norm = field.bbox[1]
            let x2_norm = field.bbox[2]
            let y2_norm = field.bbox[3]
            
            // Convert to PDF coordinates
            let x1 = x1_norm * pageWidth
            let x2 = x2_norm * pageWidth
            let y1 = y1_norm * pageHeight
            let y2 = y2_norm * pageHeight
            
            // Calculate width and height
            let width = x2 - x1
            let height = y2 - y1
            
            // Flip Y coordinate (PDF origin is bottom-left)
            let x = x1
            let y = pageHeight - y2
            
            let bounds = CGRect(x: x, y: y, width: width, height: height)
            
            print("  📍 Converted bounds (points): \(bounds)")
            
            // Try using .square annotation first for visibility testing
            let annotation = PDFAnnotation(
                bounds: bounds,
                forType: .square,
                withProperties: nil
            )
            
            // Make it VERY visible for debugging
            annotation.color = UIColor.red.withAlphaComponent(0.8)
            annotation.interiorColor = UIColor.yellow.withAlphaComponent(0.3)
            
            let border = PDFBorder()
            border.lineWidth = 4.0
            border.style = .solid
            annotation.border = border
            
            // Add label if available
            if let label = field.label {
                annotation.contents = label
            }
            
            // Make annotation visible
            annotation.shouldDisplay = true
            annotation.shouldPrint = true
            
            print("  ✨ Created SQUARE annotation for field \(field.id)")
            print("     Type: \(annotation.type ?? "unknown")")
            print("     Bounds: \(annotation.bounds)")
            print("     Color: \(String(describing: annotation.color))")
            
            return annotation
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else {
                return
            }
            let pageIndex = document.index(for: currentPage)
            parent.currentPage = pageIndex
        }
        
        @objc func scaleChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else { return }
            let minScale = pdfView.scaleFactorForSizeToFit
            let currentScale = pdfView.scaleFactor
            
            DispatchQueue.main.async {
                self.parent.isZoomedIn = currentScale > minScale * 1.1
            }
        }
        
        @objc func handleSingleTap(_ gesture: UITapGestureRecognizer) {
            guard let pdfView = pdfView else { return }
            
            let location = gesture.location(in: pdfView)
            guard let page = pdfView.page(for: location, nearest: true) else {
                parent.onTap?()
                return
            }
            
            let pagePoint = pdfView.convert(location, to: page)
            
            // Check if tap hit any annotation
            var tappedAnnotation: PDFAnnotation?
            var tappedField: DetectedField?
            
            for field in parent.detectedFields {
                if let annotation = annotationMap[field.id],
                   annotation.page == page,
                   annotation.bounds.contains(pagePoint) {
                    tappedAnnotation = annotation
                    tappedField = field
                    break
                }
            }
            
            if let annotation = tappedAnnotation, let field = tappedField {
                handleFieldTap(annotation: annotation, field: field)
            } else {
                // Tap outside - dismiss focus and minimize drawer
                dismissFocus()
                parent.onTap?()
            }
        }
        
        func handleFieldTap(annotation: PDFAnnotation, field: DetectedField) {
            // Remove focus from previous
            if let previous = focusedAnnotation, previous != annotation {
                removeFocusStyle(previous)
            }
            
            // Apply focus to tapped annotation
            applyFocusStyle(annotation)
            focusedAnnotation = annotation
            
            // Notify parent
            parent.onFieldTapped?(field)
            
            print("👆 Tapped field: \(field.id) - \(field.label ?? "no label")")
        }
        
        func dismissFocus() {
            if let focused = focusedAnnotation {
                removeFocusStyle(focused)
                focusedAnnotation = nil
            }
        }
        
        func applyFocusStyle(_ annotation: PDFAnnotation) {
            annotation.color = UIColor.systemGreen
            annotation.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
            
            let border = PDFBorder()
            border.lineWidth = 3.0
            border.style = .solid
            annotation.border = border
            
            refreshAnnotation(annotation)
        }
        
        func removeFocusStyle(_ annotation: PDFAnnotation) {
            annotation.color = UIColor.systemBlue
            annotation.backgroundColor = UIColor.white.withAlphaComponent(0.8)
            
            let border = PDFBorder()
            border.lineWidth = 2.0
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
        
        // MARK: - UIGestureRecognizerDelegate
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let pdfView = pdfView else { return }
            
            let minScale = pdfView.scaleFactorForSizeToFit
            let currentScale = pdfView.scaleFactor
            
            if currentScale > minScale * 1.1 {
                UIView.animate(withDuration: 0.3) {
                    pdfView.scaleFactor = minScale
                }
            } else {
                let zoomScale = minScale * 2.0
                UIView.animate(withDuration: 0.3) {
                    pdfView.scaleFactor = zoomScale
                }
            }
        }
    }
    
    static func dismantleUIView(_ uiView: PDFView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }
}
