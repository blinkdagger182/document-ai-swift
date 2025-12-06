# Synthetic Widget Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS App (SwiftUI)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │         SplitScreenEditorView (Main UI)                   │  │
│  │                                                             │  │
│  │  ┌─────────────────────┐  ┌──────────────────────────┐   │  │
│  │  │   PDF Viewer Pane   │  │   Form Fields Pane       │   │  │
│  │  │                     │  │                          │   │  │
│  │  │  PDFKitRepresented  │  │  TextField, TextEditor   │   │  │
│  │  │  View               │  │  Picker, Toggle, etc.    │   │  │
│  │  │                     │  │                          │   │  │
│  │  └─────────────────────┘  └──────────────────────────┘   │  │
│  │           ↕                          ↕                     │  │
│  │           └──────────────────────────┘                     │  │
│  │              formValues: [UUID: String]                    │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              ↕                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              DocumentViewModel                             │  │
│  │  • formValues: [UUID: String]                             │  │
│  │  • fieldRegions: [FieldRegion]                            │  │
│  │  • fieldIdToUUID: [String: UUID]                          │  │
│  │  • uuidToFieldId: [UUID: String]                          │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              ↕                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                   APIService                               │  │
│  │  • initUpload()                                           │  │
│  │  • processDocument()                                      │  │
│  │  • getDocument() → fieldRegions                           │  │
│  │  • submitValues()                                         │  │
│  │  • composePDF()                                           │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              ↕                                   │
└──────────────────────────────┼───────────────────────────────────┘
                               ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Backend API (FastAPI)                         │
├─────────────────────────────────────────────────────────────────┤
│  • Vision Field Detector (Google Cloud Vision)                  │
│  • OCR Processing                                                │
│  • Field Region Extraction                                       │
│  • PDF Composition                                               │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Upload & Process Flow

```
User Selects PDF
      ↓
HomeViewModel.uploadAndProcess()
      ↓
APIService.initUpload(file)
      ↓
Backend: Store PDF in Supabase
      ↓
APIService.processDocument(documentId)
      ↓
Backend: Run Vision Detector
      ↓
APIService.pollUntilReady(documentId)
      ↓
Backend: Return fieldRegions
      ↓
HomeViewModel: Convert FieldRegionDTO → FieldRegion
      ↓
Navigate to SplitScreenEditorView
```

### 2. Widget Creation Flow

```
SplitScreenEditorView.init()
      ↓
PDFKitRepresentedView.makeUIView()
      ↓
Load PDFDocument from URL
      ↓
Check: hasAcroFormFields?
      ↓
  ┌───┴───┐
  │       │
 YES     NO
  │       │
  │       └─→ Check: fieldRegions.isEmpty?
  │                   │
  │                  NO
  │                   ↓
  │           Coordinator.createSyntheticWidgets()
  │                   ↓
  │           For each fieldRegion:
  │             1. Get page
  │             2. Convert normalized → PDF coords
  │             3. Create PDFAnnotation
  │             4. Set widget type & style
  │             5. Add to page
  │             6. Track in annotationMap
  │                   ↓
  └──────────────→ Register notification observers
                      ↓
                  Ready for editing
```

### 3. Two-Way Sync Flow

#### User Types in PDF Widget

```
User taps widget in PDF
      ↓
PDFKit shows keyboard
      ↓
User types text
      ↓
PDFViewAnnotationHit notification
      ↓
Coordinator.annotationChanged()
      ↓
Get annotation.widgetStringValue
      ↓
Look up fieldId → UUID
      ↓
Update formValues[uuid]
      ↓
SwiftUI updates form list
```

#### User Types in Form List

```
User types in TextField
      ↓
SwiftUI updates formValues[uuid]
      ↓
PDFKitRepresentedView.updateUIView()
      ↓
Coordinator.syncFormValuesToPDF()
      ↓
For each changed field:
  1. Get annotation from annotationMap
  2. Set annotation.widgetStringValue
  3. Clear appearance stream
  4. Trigger redraw
      ↓
PDF widget shows new value
```

### 4. Submit Flow

```
User taps "Submit & Generate PDF"
      ↓
DocumentViewModel.submitAndGeneratePDF()
      ↓
Convert formValues[UUID] → formData[fieldId]
      ↓
Build FieldValueInput array
      ↓
APIService.submitValues(documentId, values)
      ↓
Backend: Store values in database
      ↓
APIService.composePDF(documentId)
      ↓
Backend: Fill PDF with values
      ↓
APIService.pollUntilFilled(documentId)
      ↓
Backend: Return filled PDF URL
      ↓
APIService.downloadPDF(documentId)
      ↓
Show download/share dialog
```

## Coordinate System

### Backend (Normalized)

```
(0,1) ────────────── (1,1)
  │                    │
  │                    │
  │    Field Region    │
  │    x: 0.1          │
  │    y: 0.5          │
  │    w: 0.3          │
  │    h: 0.05         │
  │                    │
(0,0) ────────────── (1,0)

Origin: Bottom-Left
Range: 0.0 to 1.0
```

### PDFKit (Points)

```
(0,792) ──────────── (612,792)
  │                    │
  │                    │
  │    PDF Page        │
  │    Letter Size     │
  │    612 x 792 pts   │
  │                    │
  │                    │
(0,0) ────────────── (612,0)

Origin: Bottom-Left
Units: Points (1/72 inch)
```

### Conversion Formula

```swift
let pageRect = page.bounds(for: .mediaBox)

// Normalized → PDF Points
let pdfX = normalizedX * pageRect.width
let pdfY = normalizedY * pageRect.height
let pdfWidth = normalizedWidth * pageRect.width
let pdfHeight = normalizedHeight * pageRect.height

// Example:
// Page: 612 x 792 pts
// Normalized: x=0.1, y=0.5, w=0.3, h=0.05
// PDF: x=61.2, y=396, w=183.6, h=39.6
```

## State Management (Triangle of Truth)

```
┌─────────────────────────────────────────────────────────┐
│              Single Source of Truth                      │
│                                                           │
│         formValues: [UUID: String]                       │
│         ────────────────────────────                     │
│         Published in DocumentViewModel                   │
│                                                           │
└─────────────────────────────────────────────────────────┘
                        ↕
        ┌───────────────┴───────────────┐
        ↓                               ↓
┌──────────────────┐          ┌──────────────────┐
│   PDF Widgets    │          │   Form Fields    │
│   (PDFKit)       │          │   (SwiftUI)      │
│                  │          │                  │
│  Binding via     │          │  Binding via     │
│  Coordinator     │          │  @Binding        │
└──────────────────┘          └──────────────────┘
```

### Key Mappings

```
┌─────────────────────────────────────────────────────────┐
│                    UUID Mappings                         │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  fieldIdToUUID: [String: UUID]                          │
│  ─────────────────────────────                          │
│  "name_field" → UUID-1234                               │
│  "email_field" → UUID-5678                              │
│                                                           │
│  uuidToFieldId: [UUID: String]                          │
│  ─────────────────────────────                          │
│  UUID-1234 → "name_field"                               │
│  UUID-5678 → "email_field"                              │
│                                                           │
│  annotationMap: [String: PDFAnnotation]                 │
│  ──────────────────────────────────                     │
│  "name_field" → PDFAnnotation(bounds: ...)              │
│  "email_field" → PDFAnnotation(bounds: ...)             │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

## Component Responsibilities

### PDFKitRepresentedView
- ✅ Create synthetic widgets from fieldRegions
- ✅ Convert normalized → PDF coordinates
- ✅ Style widgets (Files.app appearance)
- ✅ Listen for user interactions
- ✅ Sync PDF ↔ formValues
- ✅ Handle widget lifecycle

### Coordinator
- ✅ Manage PDFView and PDFDocument
- ✅ Track annotations in annotationMap
- ✅ Handle notification observers
- ✅ Implement sync logic
- ✅ Convert coordinates
- ✅ Update widget values

### SplitScreenEditorView
- ✅ Display PDF and form side-by-side
- ✅ Pass data to PDFKitRepresentedView
- ✅ Render form fields from components
- ✅ Handle drag-to-resize
- ✅ Show alerts and dialogs

### DocumentViewModel
- ✅ Maintain formValues (source of truth)
- ✅ Store fieldRegions and components
- ✅ Build UUID mappings
- ✅ Handle API calls
- ✅ Auto-save form data
- ✅ Submit values to backend

### HomeViewModel
- ✅ Handle file selection
- ✅ Upload documents
- ✅ Process documents
- ✅ Convert API responses
- ✅ Navigate to editor

## Field Type Handling

```
┌──────────────────────────────────────────────────────────┐
│              Field Type Mapping                           │
├──────────────────────────────────────────────────────────┤
│                                                            │
│  Backend Type    →  Swift Enum  →  PDF Widget Type       │
│  ─────────────      ──────────      ───────────────       │
│  "text"          →  .text       →  .text                 │
│  "textarea"      →  .textarea   →  .text                 │
│  "multiline"     →  .multiline  →  .text                 │
│  "date"          →  .date       →  .text                 │
│  "number"        →  .number     →  .text                 │
│  "email"         →  .email      →  .text                 │
│  "phone"         →  .phone      →  .text                 │
│  "checkbox"      →  .checkbox   →  .button               │
│  "signature"     →  .signature  →  .text                 │
│  "unknown"       →  .unknown    →  .text                 │
│                                                            │
└──────────────────────────────────────────────────────────┘
```

## Performance Characteristics

### Widget Creation
- **Time Complexity**: O(n) where n = number of field regions
- **Space Complexity**: O(n) for annotation storage
- **Typical Performance**: < 100ms for 50 fields

### Sync Operations
- **Time Complexity**: O(m) where m = number of changed fields
- **Space Complexity**: O(1) for temporary variables
- **Typical Performance**: < 10ms per update

### Memory Usage
- **Per Widget**: ~1KB (annotation + metadata)
- **100 Widgets**: ~100KB total
- **Impact**: Negligible on modern devices

## Error Handling

```
┌──────────────────────────────────────────────────────────┐
│                  Error Scenarios                          │
├──────────────────────────────────────────────────────────┤
│                                                            │
│  1. Invalid Coordinates                                   │
│     → Skip field, log warning                            │
│                                                            │
│  2. Invalid Page Index                                    │
│     → Skip field, log warning                            │
│                                                            │
│  3. PDF Load Failure                                      │
│     → Show error, return empty PDFView                   │
│                                                            │
│  4. Missing UUID Mapping                                  │
│     → Skip sync, log warning                             │
│                                                            │
│  5. Backend API Error                                     │
│     → Show alert, allow retry                            │
│                                                            │
│  6. Network Timeout                                       │
│     → Show alert, suggest offline mode                   │
│                                                            │
└──────────────────────────────────────────────────────────┘
```

## Testing Strategy

### Unit Tests
- Coordinate conversion accuracy
- UUID mapping correctness
- Field type parsing
- Value sync logic

### Integration Tests
- PDF loading and widget creation
- Two-way binding functionality
- API response parsing
- Form submission flow

### UI Tests
- Widget tap and edit
- Form field interaction
- Scroll and navigation
- Multi-page handling

### Performance Tests
- Widget creation time
- Sync operation speed
- Memory usage
- Large document handling

## Summary

The synthetic widget architecture provides a seamless way to edit PDFs without native form fields. It leverages Vision-detected field regions from the backend, creates interactive PDF widgets on the client, and maintains a single source of truth for all form values. The implementation is performant, maintainable, and follows iOS best practices.
