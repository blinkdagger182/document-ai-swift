//
//  PDFViewerComponents.swift
//  documentAI
//
//  PDF viewer wrapper with zoom and tap gestures
//

import SwiftUI
import PDFKit

struct PDFViewWrapper: UIViewRepresentable {
    
    let pdfDocument: PDFDocument?
    @Binding var currentPage: Int
    @Binding var isZoomedIn: Bool
    var onTap: (() -> Void)?
    
    init(pdfDocument: PDFDocument?, currentPage: Binding<Int> = .constant(0), isZoomedIn: Binding<Bool> = .constant(false), onTap: (() -> Void)? = nil) {
        self.pdfDocument = pdfDocument
        self._currentPage = currentPage
        self._isZoomedIn = isZoomedIn
        self.onTap = onTap
    }
    
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
        pdfView.document = pdfDocument
        
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
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.zoomOut(_:)),
            name: NSNotification.Name("ZoomOutPDF"),
            object: nil
        )
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== pdfDocument {
            pdfView.document = pdfDocument
        }
        
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
        var parent: PDFViewWrapper
        weak var pdfView: PDFView?
        
        init(_ parent: PDFViewWrapper) {
            self.parent = parent
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
        
        @objc func zoomOut(_ notification: Notification) {
            guard let pdfView = pdfView else { return }
            let minScale = pdfView.scaleFactorForSizeToFit
            
            UIView.animate(withDuration: 0.3) {
                pdfView.scaleFactor = minScale
            }
        }
    }
    
    static func dismantleUIView(_ uiView: PDFView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }
}
