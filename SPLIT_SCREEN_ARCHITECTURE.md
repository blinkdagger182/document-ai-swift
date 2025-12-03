# Split-Screen Editor Architecture

## Overview

This document describes the implementation of the split-screen PDF editor with the "Triangle of Truth" architecture for the DocumentAI iOS app.

## Architecture Components

### 1. Triangle of Truth: DocumentViewModel

**File:** `documentAI/DocumentViewModel.swift`

The central source of truth for all form field values:

```swift
@Published var formValues: [UUID: String] = [:]
```

**Key Features:**
- Single source of truth for all field values
- UUID-based field identification (internal)
- Automatic conversion to/from fieldId-based storage
- Autosave every 5 seconds using Combine's `debounce`
- Bidirectional mapping between UUIDs and field IDs

**Autosave Implementation:**
```swift
$formValues
    .debounce(for: .seconds(5), scheduler: RunLoop.main)
    .sink { [weak self] _ in
        self?.autoSave()
    }
    .store(in: &cancellables)
```

### 2. Split-Screen Editor: SplitScreenEditorView

**File:** `documentAI/SplitScreenEditorView.swift`

Custom vertical split using GeometryReader with draggable handle:

**Features:**
- Top pane: PDF viewer (PDFKit)
- Bottom pane: Dynamic form fields (SwiftUI)
- Draggable handle between panes
- Split ratio adjustable from 20% to 80%
- Tap-to-focus: Tapping PDF field scrolls and focuses bottom form field

**Split Implementation:**
```swift
GeometryReader { geometry in
    VStack(spacing: 0) {
        // Top: PDF (height * splitRatio)
        pdfViewerPane(height: geometry.size.height * splitRatio)
        
        // Drag Handle
        dragHandle
        
        // Bottom: Form (height * (1 - splitRatio))
        formFieldsPane(height: geometry.size.height * (1 - splitRatio))
    }
}
```

### 3. PDFKit Integration: PDFKitRepresentedView

**File:** `documentAI/PDFKitRepresentedView.swift`

UIViewRepresentable wrapper for PDFKit with two-way binding:

**Features:**
- Receives `@Binding var formValues: [UUID: String]`
- Updates PDF annotations when formValues change
- Efficient redraw: only updates changed annotation bounds
- Tap gesture recognizer for field overlay detection
- Supports both AcroForm and OCR field sources

**Two-Way Binding:**
```swift
func updateUIView(_ pdfView: PDFView, context: Context) {
    for (uuid, value) in formValues {
        let annotation = findOrCreateAnnotation(for: region, on: page, fieldId: fieldId)
        
        if annotation.widgetStringValue != value {
            annotation.widgetStringValue = value
            pdfView.setNeedsDisplay(bounds) // Limited redraw
        }
    }
}
```

### 4. Field Regions: FieldRegion Model

**File:** `documentAI/Models.swift`

Represents PDF field coordinates with source tracking:

```swift
struct FieldRegion: Identifiable, Codable {
    let fieldId: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let page: Int?
    let source: FieldSource // .acroform or .ocr
}
```

**Compatibility:**
- Native AcroForm fields: extracted from PDF annotations
- OCR fallback fields: detected via backend OCR
- Both treated identically in the UI

### 5. Local Storage: LocalFormStorageService

**File:** `documentAI/LocalFormStorageService.swift`

Persistent storage for form drafts:

**Features:**
- Saves form data to local JSON files
- Keyed by documentId
- Includes metadata (fileName, savedAt timestamp)
- Automatic loading on document reopen

**Storage Location:**
```
Documents/FormData/{documentId}.json
```

## Data Flow

### 1. User Edits TextField
```
TextField (SwiftUI)
  ↓ Binding
DocumentViewModel.formValues[uuid] = newValue
  ↓ @Published
PDFKitRepresentedView.updateUIView()
  ↓
annotation.widgetStringValue = newValue
  ↓
PDF redraw (limited to annotation bounds)
```

### 2. User Taps PDF Field
```
PDFKitRepresentedView tap gesture
  ↓
Coordinator.handleTap()
  ↓
onFieldTapped(uuid)
  ↓
SplitScreenEditorView.handleFieldTapped()
  ↓
ScrollViewProxy.scrollTo(uuid)
  ↓
focusedFieldUUID = uuid
```

### 3. Autosave (Every 5 Seconds)
```
formValues changes
  ↓
Combine debounce (5 seconds)
  ↓
DocumentViewModel.autoSave()
  ↓
Convert UUID → fieldId
  ↓
LocalFormStorageService.saveFormData()
  ↓
Write to Documents/FormData/{documentId}.json
```

## Integration Points

### Backend API Response

The backend should return:

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
  "pdfURL": "https://..."
}
```

### Field Sources

**AcroForm (Native PDF Fields):**
- Extracted from PDF annotations
- `source: "acroform"`
- Preferred when available

**OCR Fallback:**
- Detected via computer vision
- `source: "ocr"`
- Used when PDF has no native form fields

Both sources are treated identically in the UI.

## Performance Optimizations

### 1. Limited Redraw
Only the changed annotation's bounds are redrawn:
```swift
pdfView.setNeedsDisplay(annotation.bounds)
```

### 2. Debounced Autosave
Prevents excessive disk writes:
```swift
.debounce(for: .seconds(5), scheduler: RunLoop.main)
```

### 3. UUID-Based Internal State
Avoids string-based lookups in hot paths.

## Usage

### Navigating to Split-Screen Editor

From `HomeView.swift`:

```swift
if viewModel.showResults {
    SplitScreenEditorView(
        components: viewModel.components,
        fieldRegions: viewModel.fieldRegions,
        documentId: viewModel.documentId,
        selectedFile: viewModel.selectedFile,
        pdfURL: viewModel.pdfURL,
        onBack: {
            viewModel.showResults = false
        }
    )
}
```

### Testing with Stub Data

The `APIService.swift` includes stub data for testing:
- 4 sample fields (text, email, select, checkbox)
- Sample field regions with coordinates
- Simulated upload progress

## Future Enhancements

1. **Field Overlay Boxes**: Add visual rectangles on PDF matching field regions
2. **Coordinate Transformation**: Convert PDF coordinates to screen coordinates for overlays
3. **Multi-page Support**: Handle field regions across multiple PDF pages
4. **Field Validation**: Real-time validation with visual feedback
5. **Undo/Redo**: History management for form edits
6. **Export Options**: Share filled PDF via system share sheet

## Files Modified/Created

### Created:
- `documentAI/DocumentViewModel.swift`
- `documentAI/PDFKitRepresentedView.swift`
- `documentAI/SplitScreenEditorView.swift`
- `documentAI/LocalFormStorageService.swift`

### Modified:
- `documentAI/Models.swift` - Added `FieldRegion` struct
- `documentAI/HomeView.swift` - Updated to use `SplitScreenEditorView`
- `documentAI/HomeViewModel.swift` - Added `fieldRegions` and `pdfURL`
- `documentAI/APIService.swift` - Updated stub to return field regions

### Deprecated (kept for reference):
- `documentAI/FillDocumentView.swift` - Old single-screen form view
- `documentAI/FillDocumentViewModel.swift` - Old view model
- `documentAI/LocalStorageService.swift` - Old storage service

## Summary

The split-screen editor implements a clean separation of concerns:
- **DocumentViewModel**: Single source of truth
- **SplitScreenEditorView**: UI layout and user interaction
- **PDFKitRepresentedView**: PDF rendering and annotation updates
- **LocalFormStorageService**: Persistent storage

The "Triangle of Truth" ensures data consistency across the PDF viewer and form fields, with automatic synchronization and efficient updates.
