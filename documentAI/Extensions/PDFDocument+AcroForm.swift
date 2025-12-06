//
//  PDFDocument+AcroForm.swift
//  documentAI
//
//  Extension to detect native AcroForm fields in PDF documents
//

import PDFKit

extension PDFDocument {
    /// Check if the PDF contains native AcroForm interactive fields
    var hasAcroFormFields: Bool {
        for i in 0..<self.pageCount {
            guard let page = self.page(at: i) else { continue }
            if page.annotations.contains(where: { $0.widgetFieldType != nil }) {
                return true
            }
        }
        return false
    }
}
