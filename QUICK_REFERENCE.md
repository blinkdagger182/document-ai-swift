# Quick Reference Guide

## 🚀 Getting Started

### Add Files to Xcode
```bash
# Open Xcode project
open documentAI.xcodeproj

# Add these 4 new files via Xcode GUI:
# - documentAI/DocumentViewModel.swift
# - documentAI/PDFKitRepresentedView.swift
# - documentAI/SplitScreenEditorView.swift
# - documentAI/LocalFormStorageService.swift
```

### Build & Run
```bash
# In Xcode:
⌘B  # Build
⌘R  # Run on simulator
```

## 📋 Key Concepts

### Triangle of Truth
```swift
// Single source of truth for ALL field values
@Published var formValues: [UUID: String] = [:]
```

### Two-Way Binding
```swift
// TextField → formValues → PDF Annotation
TextField(text: Binding(
    get: { viewModel.getFieldValue(uuid: uuid) },
    set: { viewModel.updateFieldValue(uuid: uuid, value: $0) }
))
```

### Autosave
```swift
// Automatically saves 5 seconds after last edit
$formValues
    .debounce(for: .seconds(5), scheduler: RunLoop.main)
    .sink { _ in self.autoSave() }
```

## 🔧 Common Tasks

### Update API Endpoint
```swift
// In APIService.swift
private let baseURL = "https://your-api-endpoint.com"
```

### Change Autosave Interval
```swift
// In DocumentViewModel.swift
.debounce(for: .seconds(10), scheduler: RunLoop.main) // 10 seconds
```

### Adjust Split Ratio Limits
```swift
// In SplitScreenEditorView.swift
splitRatio = min(max(newRatio, 0.3), 0.7) // 30%-70% instead of 20%-80%
```

### Customize Drag Handle
```swift
// In SplitScreenEditorView.swift
.frame(height: 30) // Increase from 20px to 30px
```

## 🐛 Debugging

### Check Autosave
```swift
// Look for console logs:
✅ Autosaved form data  // Success
❌ Error saving form data: ...  // Error
```

### Verify Field Mapping
```swift
// In DocumentViewModel.init()
print("Field mappings:")
print("fieldIdToUUID: \(fieldIdToUUID)")
print("formValues: \(formValues)")
```

### Test PDF Updates
```swift
// In PDFKitRepresentedView.updateUIView()
print("Updating annotation for uuid: \(uuid), value: \(value)")
```

## 📊 Data Structures

### FieldComponent
```swift
struct FieldComponent {
    let id: String           // "field_1"
    let type: FieldType      // .text, .email, etc.
    let label: String        // "Full Name"
    let placeholder: String? // "Enter name"
    let options: [String]?   // For select fields
    let value: AnyCodable?   // Initial value
}
```

### FieldRegion
```swift
struct FieldRegion {
    let fieldId: String      // "field_1"
    let x: Double            // 100
    let y: Double            // 200
    let width: Double        // 200
    let height: Double       // 30
    let page: Int?           // 0
    let source: FieldSource  // .acroform or .ocr
}
```

### FormValues (Internal)
```swift
// UUID-based for type safety
formValues[UUID("abc-123")] = "John Doe"

// Converted to fieldId for storage/API
formData["field_1"] = "John Doe"
```

## 🎯 API Integration

### Expected Response
```json
{
  "documentId": "doc_123",
  "components": [
    {
      "id": "field_1",
      "type": "text",
      "label": "Full Name",
      "placeholder": "Enter name"
    }
  ],
  "fieldRegions": [
    {
      "fieldId": "field_1",
      "x": 100,
      "y": 200,
      "width": 200,
      "height": 30,
      "page": 0,
      "source": "acroform"
    }
  ],
  "pdfURL": "https://example.com/document.pdf"
}
```

### Update APIService
```swift
// Replace stub in uploadAndProcessDocument()
let url = URL(string: "\(baseURL)/upload")!
var request = URLRequest(url: url)
request.httpMethod = "POST"
// ... add multipart form data
let (data, _) = try await URLSession.shared.data(for: request)
let result = try JSONDecoder().decode(ProcessResult.self, from: data)
return result
```

## 🧪 Testing Checklist

- [ ] Split-screen displays correctly
- [ ] Drag handle adjusts split ratio
- [ ] TextField edits update PDF
- [ ] PDF tap scrolls to field
- [ ] Autosave logs appear after 5s
- [ ] Form data persists on reopen
- [ ] Submit generates PDF
- [ ] All field types work (text, email, select, checkbox, date)

## 📁 File Locations

### Core Files
```
documentAI/
├── DocumentViewModel.swift          ← Triangle of Truth
├── SplitScreenEditorView.swift      ← Split-screen UI
├── PDFKitRepresentedView.swift      ← PDF integration
└── LocalFormStorageService.swift    ← Autosave
```

### Storage Location
```
Documents/FormData/
└── {documentId}.json  ← Saved form data
```

## 🔍 Key Methods

### DocumentViewModel
```swift
updateFieldValue(uuid: UUID, value: String)  // Update field
getFieldValue(uuid: UUID) -> String          // Get field value
saveProgress()                               // Manual save
submitAndGeneratePDF()                       // Submit form
```

### SplitScreenEditorView
```swift
handleFieldTapped(uuid: UUID)  // Scroll & focus field
```

### PDFKitRepresentedView
```swift
updateUIView()                 // Update PDF annotations
findOrCreateAnnotation()       // Get/create annotation
```

## 💡 Tips

### Performance
- PDF updates are limited to changed annotation bounds only
- Autosave is debounced to prevent excessive writes
- UUID-based lookups are faster than string-based

### UX
- Split ratio constrained to 20%-80% for usability
- Tap-to-focus provides seamless PDF-to-form navigation
- Autosave prevents data loss

### Compatibility
- Supports both AcroForm (native) and OCR (fallback) fields
- Works with single and multi-page PDFs
- Compatible with iOS 15.0+

## 📚 Documentation

- **IMPLEMENTATION_SUMMARY.md** - Overview of what was built
- **SPLIT_SCREEN_ARCHITECTURE.md** - Detailed technical architecture
- **ARCHITECTURE_DIAGRAM.md** - Visual diagrams and flows
- **SPLIT_SCREEN_INTEGRATION.md** - Integration checklist
- **XCODE_INTEGRATION_STEPS.md** - Step-by-step Xcode setup
- **QUICK_REFERENCE.md** - This file

## 🆘 Troubleshooting

### Build Errors
```bash
# Clean build folder
⌘⇧K

# Rebuild
⌘B
```

### Files Not Found
```
# Ensure files are added to Xcode project target
# Right-click file → Show File Inspector → Target Membership
```

### PDF Not Displaying
```swift
// Check pdfURL is valid
print("PDF URL: \(viewModel.pdfURL)")

// Verify PDF document loads
if let document = PDFDocument(url: pdfURL) {
    print("PDF loaded: \(document.pageCount) pages")
}
```

### Autosave Not Working
```swift
// Check storage directory exists
print("Storage dir: \(storageDirectory)")

// Verify write permissions
try? "test".write(to: storageDirectory.appendingPathComponent("test.txt"))
```

## ✅ Success Criteria

Your implementation is working when:

1. ✅ Split-screen displays with PDF on top, form on bottom
2. ✅ Drag handle adjusts split ratio smoothly
3. ✅ Editing TextField updates PDF annotation
4. ✅ Tapping PDF field focuses TextField
5. ✅ Console shows autosave logs every 5 seconds
6. ✅ Reopening document restores form data
7. ✅ Submit button generates filled PDF

## 🎉 You're Done!

The split-screen editor is fully implemented and ready to use. Just add the files to Xcode and start testing!
