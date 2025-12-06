# Quick Integration Guide - Synthetic Widget Mode

## For Developers: How to Use the New Feature

### 1. Backend Requirements

Your backend must return `fieldRegions` in the document detail response:

```json
{
  "document": { ... },
  "components": [ ... ],
  "fieldMap": {
    "field_001": {
      "id": "region_001",
      "pageIndex": 0,
      "x": 0.1,
      "y": 0.5,
      "width": 0.3,
      "height": 0.05,
      "fieldType": "text",
      "label": "Full Name",
      "confidence": 0.95
    }
  }
}
```

**Key Points:**
- Coordinates must be normalized (0.0 to 1.0)
- Origin is bottom-left of page
- `pageIndex` is 0-based
- `fieldType` should match `FieldType` enum values

### 2. Supported Field Types

```swift
enum FieldType: String, Codable {
    case text
    case textarea
    case multiline
    case select
    case checkbox
    case button
    case date
    case number
    case email
    case phone
    case signature
    case unknown
}
```

### 3. Using PDFKitRepresentedView

```swift
// In your view
PDFKitRepresentedView(
    pdfURL: url,                          // URL to PDF file
    formValues: $viewModel.formValues,    // Binding to [UUID: String]
    fieldRegions: viewModel.fieldRegions, // Array of FieldRegion
    fieldIdToUUID: viewModel.fieldIdToUUID // Mapping dictionary
)
```

### 4. Setting Up ViewModel

```swift
class DocumentViewModel: ObservableObject {
    @Published var formValues: [UUID: String] = [:]
    @Published var fieldRegions: [FieldRegion] = []
    
    var fieldIdToUUID: [String: UUID] = [:]
    var uuidToFieldId: [UUID: String] = [:]
    
    init(components: [FieldComponent], fieldRegions: [FieldRegion]) {
        self.fieldRegions = fieldRegions
        
        // Build mappings
        for component in components {
            let uuid = UUID()
            fieldIdToUUID[component.id] = uuid
            uuidToFieldId[uuid] = component.id
            formValues[uuid] = ""
        }
    }
}
```

### 5. Coordinate Conversion

If you need to convert coordinates manually:

```swift
func normalizedToPDFRect(normalized: CGRect, page: PDFPage) -> CGRect {
    let pageRect = page.bounds(for: .mediaBox)
    
    let px = normalized.origin.x * pageRect.width
    let py = normalized.origin.y * pageRect.height
    let pw = normalized.width * pageRect.width
    let ph = normalized.height * pageRect.height
    
    return CGRect(x: px, y: py, width: pw, height: ph)
}
```

### 6. Testing Your Integration

```swift
// Test data
let testRegion = FieldRegion(
    id: "test_001",
    fieldId: "name_field",
    x: 0.1,      // 10% from left
    y: 0.8,      // 80% from bottom
    width: 0.3,  // 30% of page width
    height: 0.05, // 5% of page height
    page: 0,
    fieldType: .text,
    source: .ocr
)

let testRegions = [testRegion]
```

### 7. Common Patterns

#### Pattern 1: Load from Backend
```swift
func loadDocument() async {
    let response = try await apiService.getDocument(documentId: id)
    
    fieldRegions = response.fieldMap.map { (fieldId, dto) in
        FieldRegion(
            id: dto.id,
            fieldId: fieldId,
            x: dto.x,
            y: dto.y,
            width: dto.width,
            height: dto.height,
            page: dto.pageIndex,
            fieldType: FieldType(rawValue: dto.fieldType ?? "text"),
            source: .ocr
        )
    }
}
```

#### Pattern 2: Handle User Input
```swift
func updateFieldValue(uuid: UUID, value: String) {
    formValues[uuid] = value
    // Automatically syncs to PDF via binding
}
```

#### Pattern 3: Submit to Backend
```swift
func submitValues() async {
    var formData: [String: String] = [:]
    
    for (uuid, value) in formValues {
        if let fieldId = uuidToFieldId[uuid] {
            formData[fieldId] = value
        }
    }
    
    let values = fieldRegions.compactMap { region -> FieldValueInput? in
        guard let value = formData[region.fieldId], !value.isEmpty else {
            return nil
        }
        return FieldValueInput(
            fieldRegionId: region.id,
            value: value,
            source: "manual"
        )
    }
    
    try await apiService.submitValues(documentId: documentId, values: values)
}
```

### 8. Debugging Tips

#### Enable Verbose Logging
```swift
// In PDFKitRepresentedView.Coordinator
print("📍 Creating widget at: x=\(region.x), y=\(region.y)")
print("📍 PDF bounds: \(bounds)")
print("📍 Page size: \(pageRect)")
```

#### Check Widget Creation
```swift
// After createSyntheticWidgets()
print("✅ Created \(annotationMap.count) widgets")
for (fieldId, annotation) in annotationMap {
    print("  - \(fieldId): \(annotation.bounds)")
}
```

#### Verify Coordinate Mapping
```swift
// Test coordinate conversion
let testNormalized = CGRect(x: 0.5, y: 0.5, width: 0.2, height: 0.1)
let pdfRect = normalizedToPDFRect(normalized: testNormalized, page: page)
print("Normalized: \(testNormalized)")
print("PDF: \(pdfRect)")
```

### 9. Error Handling

```swift
// Check for invalid regions
for region in fieldRegions {
    guard region.x >= 0 && region.x <= 1,
          region.y >= 0 && region.y <= 1,
          region.width > 0 && region.width <= 1,
          region.height > 0 && region.height <= 1 else {
        print("⚠️ Invalid coordinates for field \(region.fieldId)")
        continue
    }
    
    guard let page = region.page, page >= 0 else {
        print("⚠️ Invalid page index for field \(region.fieldId)")
        continue
    }
}
```

### 10. Performance Optimization

```swift
// Batch widget creation
func createSyntheticWidgets() {
    let startTime = Date()
    
    // Create all widgets
    for region in fieldRegions {
        // ... create widget
    }
    
    let elapsed = Date().timeIntervalSince(startTime)
    print("⏱️ Created \(fieldRegions.count) widgets in \(elapsed)s")
}

// Optimize sync
func syncFormValuesToPDF() {
    var changedCount = 0
    
    for (fieldId, annotation) in annotationMap {
        guard let uuid = fieldIdToUUID[fieldId] else { continue }
        
        let newValue = formValues[uuid] ?? ""
        let currentValue = annotation.widgetStringValue ?? ""
        
        if newValue != currentValue {
            annotation.widgetStringValue = newValue
            changedCount += 1
        }
    }
    
    if changedCount > 0 {
        print("🔄 Synced \(changedCount) fields")
    }
}
```

## Quick Checklist

Before deploying:
- [ ] Backend returns normalized coordinates (0-1)
- [ ] Backend uses bottom-left origin
- [ ] `fieldType` values match enum
- [ ] `pageIndex` is 0-based
- [ ] UUID mappings are built correctly
- [ ] `formValues` binding is set up
- [ ] Notification observers are registered
- [ ] Error handling is in place

## Need Help?

Check these files:
- `PDFKitRepresentedView.swift` - Widget implementation
- `SplitScreenEditorView.swift` - UI integration
- `DocumentViewModel.swift` - State management
- `Models.swift` - Data structures
- `SYNTHETIC_WIDGET_IMPLEMENTATION.md` - Full documentation
