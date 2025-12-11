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
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        
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
            
            // Add annotations for detected fields
            context.coordinator.addAnnotations(to: pdfView, fields: detectedFields)
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
    
    class Coordinator: NSObject {
        var parent: AnnotatedPDFView
        weak var pdfView: PDFView?
        
        init(_ parent: AnnotatedPDFView) {
            self.parent = parent
        }
        
        func addAnnotations(to pdfView: PDFView, fields: [DetectedField]) {
            guard let document = pdfView.document else { return }
            
            for field in fields {
                guard field.page < document.pageCount,
                      let page = document.page(at: field.page) else {
                    continue
                }
                
                let annotation = createBoundingBoxAnnotation(field, page: page)
                page.addAnnotation(annotation)
            }
        }
        
        func createBoundingBoxAnnotation(_ field: DetectedField, page: PDFPage) -> PDFAnnotation {
            // CommonForms bbox format: [x, y, width, height]
            // PDF coordinate system: bottom-left origin
            let pageBounds = page.bounds(for: .mediaBox)
            
            // Convert bbox to PDF coordinates
            let x = field.bbox[0]
            let y = pageBounds.height - field.bbox[1] - field.bbox[3] // Flip Y coordinate
            let width = field.bbox[2]
            let height = field.bbox[3]
            
            let bounds = CGRect(x: x, y: y, width: width, height: height)
            
            let annotation = PDFAnnotation(
                bounds: bounds,
                forType: .square,
                withProperties: nil
            )
            
            annotation.color = UIColor.systemBlue.withAlphaComponent(0.3)
            annotation.border = PDFBorder()
            annotation.border?.lineWidth = 2.0
            
            // Add label if available
            if let label = field.label {
                annotation.contents = label
            }
            
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
            parent.onTap?()
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
