# documentAI iOS Project Structure

```
documentai-swift/
├── DocumentAIApp.swift              # Main app entry point
├── README.md                        # Full documentation
├── PROJECT_STRUCTURE.md             # This file
│
├── Views/
│   ├── HomeView.swift              # Main upload screen
│   ├── FillDocumentView.swift      # Form filling screen
│   └── AnimatedGradientBackground.swift  # Gradient background
│
├── ViewModels/
│   ├── HomeViewModel.swift         # Home screen logic
│   └── FillDocumentViewModel.swift # Form screen logic
│
├── Services/
│   ├── DocumentPickerService.swift # Document picker
│   ├── ImagePickerService.swift    # Image picker
│   ├── APIService.swift            # API calls (STUB)
│   └── LocalStorageService.swift   # Local persistence
│
├── Models/
│   └── Models.swift                # All data models
│
└── Theme/
    └── Theme.swift                 # Design system
```

## File Descriptions

### App Entry
- **DocumentAIApp.swift** - SwiftUI App struct, launches HomeView

### Views
- **HomeView.swift** - Main screen with upload box, file selection, progress tracking
- **FillDocumentView.swift** - Form filling screen with dynamic fields
- **AnimatedGradientBackground.swift** - Animated gradient (blue → violet)

### ViewModels (MVVM)
- **HomeViewModel.swift** - Manages upload state, file selection, API calls
- **FillDocumentViewModel.swift** - Manages form data, auto-save, PDF generation

### Services
- **DocumentPickerService.swift** - UIDocumentPickerViewController wrapper
- **ImagePickerService.swift** - PHPickerViewController wrapper
- **APIService.swift** - Network calls (upload, process, overlay) - **NEEDS IMPLEMENTATION**
- **LocalStorageService.swift** - JSON file storage for form data

### Models
- **DocumentModel** - File metadata (id, name, url, mimeType, size)
- **FieldComponent** - Form field definition (id, type, label, options)
- **FieldType** - Enum (text, textarea, select, checkbox, date, number, email, phone, button)
- **AnyCodable** - Flexible JSON handling
- **FieldMap** - Coordinate mapping (stub)
- **FormData** - [String: String] dictionary
- **ProcessResult** - API response for upload/process
- **OverlayResult** - API response for PDF generation
- **UploadProgress** - Progress tracking

### Theme
- **Theme.swift** - Complete design system:
  - Colors (primary purple, secondary green, text, backgrounds)
  - Typography (fonts, sizes, weights)
  - Spacing (xs to xxxl)
  - Corner radius (sm to xxl)
  - Shadows (card, button)
  - View modifiers (cardStyle, primaryButtonStyle)

## State Management

### HomeViewModel @Published Properties
```swift
@Published var uploading: Bool
@Published var processing: Bool
@Published var progress: Double
@Published var selectedFile: DocumentModel?
@Published var showResults: Bool
@Published var components: [FieldComponent]
@Published var fieldMap: FieldMap
@Published var formData: FormData
@Published var documentId: String
@Published var alertState: AlertState?
```

### FillDocumentViewModel @Published Properties
```swift
@Published var components: [FieldComponent]
@Published var fieldMap: FieldMap
@Published var formData: FormData
@Published var documentId: String
@Published var submitting: Bool
@Published var savedPdfUrl: URL?
@Published var alertState: FillAlertState?
```

## Navigation Flow

```
HomeView (initial)
    ↓
[User selects file]
    ↓
HomeView (file selected)
    ↓
[User taps "Upload & Process"]
    ↓
HomeView (uploading → processing)
    ↓
[API returns components]
    ↓
FillDocumentView
    ↓
[User fills form]
    ↓
[User taps "Submit & Generate PDF"]
    ↓
FillDocumentView (submitting overlay)
    ↓
[Success alert with 3 options]
    ↓
Option 1: View PDF
Option 2: Share
Option 3: Upload Another → HomeView (reset)
```

## Key Features Implementation

### 1. Animated Gradient
- Uses `LinearGradient` with animated color swap
- `withAnimation` + `repeatForever(autoreverses: true)`
- 3-second duration

### 2. Document/Image Picker
- `UIDocumentPickerViewController` for PDFs + images
- `PHPickerViewController` for photo library
- Async/await with `CheckedContinuation`
- Copies files to temp directory

### 3. Upload Progress
- Progress handler callback
- Updates `@Published var progress`
- Visual progress bar with animated width

### 4. Dynamic Form Rendering
- Switch on `FieldType` enum
- TextField, TextEditor, Picker, Toggle, DatePicker
- Two-way binding with `Binding(get:set:)`

### 5. Auto-Save
- Timer invalidation on field change
- 5-second delay before save
- JSON serialization to Documents directory

### 6. Local Storage
- `FileManager` + Documents directory
- JSON encoding/decoding
- Keyed by `documentId`

### 7. Alert Handling
- Custom `AlertState` struct with `Identifiable`
- `.alert(item:)` modifier
- Multiple action buttons

## Next Steps

1. **Create Xcode Project**
   - Use App template
   - SwiftUI interface
   - Add all .swift files

2. **Configure Permissions**
   - Add Info.plist keys for photo library

3. **Implement API Service**
   - Replace stub methods in `APIService.swift`
   - Add your backend endpoint
   - Implement multipart upload
   - Handle API responses

4. **Test Flow**
   - Select document
   - Upload and process
   - Fill form fields
   - Submit and generate PDF

5. **Add Missing Features**
   - PDF viewer
   - Share sheet
   - Error handling
   - Network retry logic

## Design System Values

### Colors
- Primary: `#8B5CF6` (purple)
- Secondary: `#10B981` (green)
- Text Primary: `#1F2937`
- Text Secondary: `#6B7280`
- Background: `#F9FAFB`
- Card: `#FFFFFF`

### Typography
- Large Title: 36pt bold
- Title: 20pt semibold
- Body: 16pt regular/medium/semibold
- Caption: 14pt regular/medium

### Spacing
- xs: 4pt
- sm: 8pt
- md: 12pt
- lg: 16pt
- xl: 24pt
- xxl: 32pt
- xxxl: 40pt

### Corner Radius
- sm: 8pt
- md: 12pt
- lg: 16pt
- xl: 20pt
- xxl: 24pt
