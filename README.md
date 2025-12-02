# documentAI - iOS SwiftUI App

A native iOS app built with SwiftUI that replicates the React Native HomeScreen UX flow for document processing with AI.

## Architecture

**SwiftUI + MVVM** architecture:

### Views
- `HomeView.swift` - Main upload screen
- `FillDocumentView.swift` - Form filling screen
- `AnimatedGradientBackground.swift` - Animated gradient background

### ViewModels
- `HomeViewModel.swift` - Handles document selection, upload, and processing
- `FillDocumentViewModel.swift` - Handles form editing and PDF generation

### Services
- `DocumentPickerService.swift` - Document picker integration
- `ImagePickerService.swift` - Image picker integration
- `APIService.swift` - API calls (upload, process, overlay) - **STUB**
- `LocalStorageService.swift` - Local form data persistence

### Models
- `Models.swift` - Core data models (DocumentModel, FieldComponent, etc.)

### Design System
- `Theme.swift` - Colors, typography, spacing, shadows

## Features

✅ **Document Upload**
- PDF and image file selection
- File preview with size display
- Change file option

✅ **Upload Progress**
- Real-time progress tracking
- Visual progress bar
- Upload percentage display

✅ **AI Processing**
- Simulated document processing
- Dynamic form field generation
- Field type support: text, textarea, select, checkbox, date, number, email, phone

✅ **Form Filling**
- Dynamic form rendering based on API response
- Auto-save every 5 seconds
- Manual save progress
- Form data persistence

✅ **PDF Generation**
- Submit form and generate filled PDF
- Success alert with options: View PDF, Share, Upload Another
- Local PDF storage

✅ **Design System**
- Animated gradient background (blue → violet)
- Purple primary color (#8B5CF6)
- Green secondary color (#10B981)
- Card-based UI with shadows
- Rounded corners (20-24pt)
- Clean typography

## Setup Instructions

### 1. Create Xcode Project

1. Open Xcode
2. Create new project: **App** template
3. Product Name: `documentAI`
4. Interface: **SwiftUI**
5. Language: **Swift**
6. Save in the `documentai-swift` folder

### 2. Add Files to Project

Add all `.swift` files to your Xcode project:
- DocumentAIApp.swift (replace default App file)
- HomeView.swift (replace default ContentView)
- FillDocumentView.swift
- HomeViewModel.swift
- FillDocumentViewModel.swift
- DocumentPickerService.swift
- ImagePickerService.swift
- APIService.swift
- LocalStorageService.swift
- AnimatedGradientBackground.swift
- Models.swift
- Theme.swift

### 3. Configure Info.plist

Add the following permissions:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to select images for processing</string>
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to capture documents</string>
```

### 4. Configure API Endpoint

In `APIService.swift`, update the `baseURL`:

```swift
private let baseURL = "https://your-api-endpoint.com"
```

### 5. Implement API Integration

The `APIService.swift` contains stub implementations. Replace with actual API calls:

#### Upload and Process
```swift
func uploadAndProcessDocument(file: DocumentModel, progressHandler: @escaping (Double) -> Void) async throws -> ProcessResult
```

#### Overlay PDF
```swift
func overlayPDF(document: DocumentModel, documentId: String, formData: FormData) async throws -> OverlayResult
```

## State Flow

### Home Screen States

1. **Initial State**
   - Empty upload box
   - Document/Image picker buttons

2. **File Selected**
   - File info display (icon, name, size)
   - Change button
   - Upload & Process button

3. **Uploading**
   - Progress indicator
   - Progress bar
   - Upload percentage

4. **Processing**
   - Processing indicator
   - Disabled UI

5. **Results Ready**
   - Navigate to Fill Document screen

### Fill Document Screen States

1. **Form Display**
   - Dynamic form fields
   - Auto-save every 5 seconds
   - Save Progress button

2. **Submitting**
   - Full-screen overlay
   - "Generating filled PDF..." message

3. **Success**
   - Alert with 3 options:
     - View PDF
     - Share
     - Upload Another

## Data Persistence

Form data is automatically saved to local storage:
- Location: `Documents/FormData/{documentId}.json`
- Auto-save: Every 5 seconds after field change
- Manual save: "Save Progress" button
- Restore: Automatically loaded when reopening same document

## TODO

- [ ] Implement actual API integration in `APIService.swift`
- [ ] Add PDF viewer for "View PDF" action
- [ ] Add share sheet for "Share" action
- [ ] Add error handling for network failures
- [ ] Add loading states for slow networks
- [ ] Add unit tests
- [ ] Add UI tests

## Design Matching

This SwiftUI app replicates the exact UX flow from the React Native HomeScreen:

✅ Gradient background animation
✅ Upload box with dashed border
✅ Document/Image picker buttons
✅ File info display
✅ Upload progress tracking
✅ Features card
✅ Fill document screen
✅ Dynamic form rendering
✅ Auto-save functionality
✅ Submit and generate PDF flow
✅ Success alert with multiple actions

## Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+

## License

MIT
