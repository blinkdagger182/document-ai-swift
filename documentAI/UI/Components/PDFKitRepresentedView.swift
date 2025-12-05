//
//  PDFKitRepresentedView.swift
//  documentAI
//
//  PDFKit wrapper with two-way binding to formValues,
//  tuned to behave like iOS Files.app.
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
            fieldRegions: fieldRegions,
            fieldIdToUUID: fieldIdToUUID,
            onFieldTapped: onFieldTapped
        )
    }
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .clear
        
        if #available(iOS 16.0, *) {
            // We want form-style behavior, not markup mode
            pdfView.isInMarkupMode = false
        }
        
        // Load PDF document
        if let document = PDFDocument(url: pdfURL) {
            pdfView.document = document
            
            // Detect native AcroForm fields
            var hasNativeFields = false
            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }
                if page.annotations.contains(where: { $0.widgetFieldType == .text }) {
                    hasNativeFields = true
                    print("📄 Page \(pageIndex) has native widget annotations: \(page.annotations.count)")
                    break
                }
            }
            context.coordinator.hasNativeFields = hasNativeFields
            context.coordinator.pdfView = pdfView
            context.coordinator.containerView = containerView
            
            // Build annotation map (native or synthetic) once
            context.coordinator.installAnnotationsIfNeeded()
            
            // Tap gesture to focus a field
            let tapGesture = UITapGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleTap(_:))
            )
            pdfView.addGestureRecognizer(tapGesture)
            
            containerView.addSubview(pdfView)
            pdfView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                pdfView.topAnchor.constraint(equalTo: containerView.topAnchor),
                pdfView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                pdfView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                pdfView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
        }
        
        return containerView
    }
    
    func updateUIView(_ containerView: UIView, context: Context) {
        guard let pdfView = context.coordinator.pdfView,
              pdfView.document != nil else { return }
        
        // Keep annotation map in sync (e.g. after reload)
        context.coordinator.installAnnotationsIfNeeded()
        
        // Push SwiftUI formValues into widget annotations
        context.coordinator.syncAnnotationsWithFormValues()
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var formValues: [UUID: String]
        let fieldRegions: [FieldRegion]
        let fieldIdToUUID: [String: UUID]
        let onFieldTapped: (UUID) -> Void
        
        weak var pdfView: PDFView?
        weak var containerView: UIView?
        
        /// true if the PDF already has AcroForm fields
        var hasNativeFields: Bool = false
        
        /// fieldId (String) -> annotation
        var annotationMap: [String: PDFAnnotation] = [:]
        
        // Active inline editor
        var activeEditor: UITextField?
        var activeAnnotation: PDFAnnotation?
        var activeFieldId: String?
        
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
        
        // MARK: Annotation installation
        
        /// Ensure annotationMap is populated either from native AcroForm
        /// fields or by creating widget annotations for static PDFs.
        func installAnnotationsIfNeeded() {
            guard let pdfView = pdfView,
                  let document = pdfView.document else { return }
            
            if !annotationMap.isEmpty { return } // already done
            
            if hasNativeFields {
                // Map existing widget annotations by fieldName
                for pageIndex in 0..<document.pageCount {
                    guard let page = document.page(at: pageIndex) else { continue }
                    for annotation in page.annotations where annotation.widgetFieldType == .text {
                        if let name = annotation.fieldName {
                            annotationMap[name] = annotation
                            print("🧬 Mapped native annotation \(name)")
                        }
                    }
                }
            } else {
                // No native fields: create widget annotations from fieldRegions
                for region in fieldRegions {
                    guard let pageIndex = region.page,
                          let page = document.page(at: pageIndex) else {
                        continue
                    }
                    guard region.x.isFinite, region.y.isFinite,
                          region.width.isFinite, region.height.isFinite,
                          region.width > 0, region.height > 0 else {
                        print("⚠️ Cannot create annotation for \(region.fieldId) - invalid normalized coords")
                        continue
                    }
                    
                    let bounds = Self.normalizedToPDFRect(region: region, on: page)
                    let annotation = PDFAnnotation(
                        bounds: bounds,
                        forType: .widget,
                        withProperties: nil
                    )
                    annotation.widgetFieldType = .text
                    annotation.fieldName = region.fieldId
                    annotation.font = UIFont.systemFont(ofSize: 12)
                    annotation.fontColor = .black
                    annotation.backgroundColor = .clear
                    annotation.color = .clear
                    
                    let border = PDFBorder()
                    border.lineWidth = 0.5
                    border.style = .solid
                    annotation.border = border
                    
                    page.addAnnotation(annotation)
                    annotationMap[region.fieldId] = annotation
                    
                    print("🆕 Created synthetic widget for \(region.fieldId) at \(bounds)")
                }
            }
        }
        
        /// Push SwiftUI form values into PDF annotations & redraw them.
        func syncAnnotationsWithFormValues() {
            guard let pdfView = pdfView else { return }
            
            for (fieldId, uuid) in fieldIdToUUID {
                guard let annotation = annotationMap[fieldId] else { continue }
                let newValue = formValues[uuid] ?? ""
                let current = annotation.widgetStringValue ?? ""
                if newValue != current {
                    annotation.widgetStringValue = newValue
                    if let page = annotation.page {
                        // Force redraw of the annotation area
                        let viewBounds = pdfView.convert(annotation.bounds, from: page)
                        pdfView.setNeedsDisplay(viewBounds)
                    }
                    print("🔁 Sync \(fieldId) -> '\(newValue)'")
                }
            }
        }
        
        // MARK: - Tap handling
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let pdfView = pdfView,
                  let document = pdfView.document else { return }
            
            let locationInView = gesture.location(in: pdfView)
            guard let page = pdfView.page(for: locationInView, nearest: true) else { return }
            let pagePoint = pdfView.convert(locationInView, to: page)
            
            // 1) Check if tap hits an existing annotation
            for annotation in page.annotations {
                if annotation.bounds.contains(pagePoint),
                   let fieldName = annotation.fieldName {
                    showNativeEditor(for: annotation, fieldId: fieldName, page: page)
                    if let uuid = fieldIdToUUID[fieldName] {
                        onFieldTapped(uuid)
                    }
                    return
                }
            }
            
            // 2) Otherwise, check if tap is inside any fieldRegion (for safety)
            for region in fieldRegions {
                guard let pageIndex = region.page,
                      let regionPage = document.page(at: pageIndex),
                      regionPage == page else { continue }
                
                let pdfBounds = Self.normalizedToPDFRect(region: region, on: page)
                if pdfBounds.contains(pagePoint) {
                    let fieldId = region.fieldId
                    if let annotation = annotationMap[fieldId] {
                        showNativeEditor(for: annotation, fieldId: fieldId, page: page)
                    }
                    if let uuid = fieldIdToUUID[fieldId] {
                        onFieldTapped(uuid)
                    }
                    return
                }
            }
        }
        
        // MARK: - Native editor (Files.app style overlay)
        
        func showNativeEditor(for annotation: PDFAnnotation, fieldId: String, page: PDFPage) {
            guard let pdfView = pdfView else { return }
            
            closeNativeEditor()
            
            // Convert widget bounds (page coords) to view coords
            let viewRect = pdfView.convert(annotation.bounds, from: page)
            
            let editor = UITextField(frame: viewRect)
            editor.text = annotation.widgetStringValue ?? ""
            editor.font = UIFont.systemFont(ofSize: 12)
            editor.textColor = UIColor.black
            editor.backgroundColor = UIColor.white.withAlphaComponent(0.95)
            editor.layer.cornerRadius = 4
            editor.layer.borderWidth = 1.5
            editor.layer.borderColor = UIColor.systemBlue.cgColor
            editor.autocorrectionType = UITextAutocorrectionType.no
            editor.delegate = self
            
            let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 6, height: viewRect.height))
            editor.leftView = paddingView
            editor.leftViewMode = UITextField.ViewMode.always
            
            pdfView.addSubview(editor)
            editor.becomeFirstResponder()
            
            activeEditor = editor
            activeAnnotation = annotation
            activeFieldId = fieldId
            
            editor.addTarget(self, action: #selector(editorTextChanged(_:)), for: UIControl.Event.editingChanged)
            
            print("✏️ Opened editor for \(fieldId)")
        }
        
        func closeNativeEditor() {
            activeEditor?.removeFromSuperview()
            activeEditor = nil
            activeAnnotation = nil
            activeFieldId = nil
        }
        
        @objc func editorTextChanged(_ sender: UITextField) {
            guard let annotation = activeAnnotation,
                  let fieldId = activeFieldId,
                  let uuid = fieldIdToUUID[fieldId],
                  let pdfView = pdfView else {
                return
            }
            
            let newValue = sender.text ?? ""
            // Update annotation & force appearance stream refresh
            annotation.widgetStringValue = newValue
            formValues[uuid] = newValue
            
            if let page = annotation.page {
                // Force redraw of the annotation area
                let viewBounds = pdfView.convert(annotation.bounds, from: page)
                pdfView.setNeedsDisplay(viewBounds)
            }
            
            print("📝 \(fieldId) = \(newValue)")
        }
        
        // MARK: - UITextFieldDelegate
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            closeNativeEditor()
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
        
        // MARK: - Helpers
        
        /// Assumes backend normalized coords use TOP-LEFT origin.
        /// Converts [0,1] normalized (x, y, w, h) → PDF page rect (bottom-left origin).
        static func normalizedToPDFRect(region: FieldRegion, on page: PDFPage) -> CGRect {
            let pageBounds = page.bounds(for: .mediaBox)
            let pageWidth = pageBounds.width
            let pageHeight = pageBounds.height
            
            let normX = region.x
            let normYTop = region.y
            let normW = region.width
            let normH = region.height
            
            let width = normW * pageWidth
            let height = normH * pageHeight
            let x = normX * pageWidth
            // Flip Y from top-left to bottom-left
            let y = pageHeight - (normYTop * pageHeight) - height
            
            return CGRect(x: x, y: y, width: width, height: height)
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
                clearAppearanceStream()
            } else {
                removeValue(forAnnotationKey: .widgetValue)
                clearAppearanceStream()
            }
        }
    }
    
    /// Clears appearance dictionary so PDFKit regenerates it on next draw.
    func clearAppearanceStream() {
        removeValue(forAnnotationKey: .appearanceDictionary)
    }
}
