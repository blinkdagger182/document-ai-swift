# DocumentAI - iOS SwiftUI App

Native iOS app for document processing with AI-powered form detection and filling.

## Features

- **Document Upload**: PDF and image file selection
- **Split-Screen Editor**: PDF viewer + form fields side by side
- **Hybrid Detection**: AcroForm detection + OCR fallback
- **Auto-Save**: Form data persists automatically
- **PDF Generation**: Submit and generate filled PDFs

## Architecture

SwiftUI + MVVM with split-screen PDF editing.

```
┌─────────────────────────────────────┐
│         PDF Viewer (Top)            │
│   [Interactive form fields]         │
├─────────────────────────────────────┤
│         ═══ Drag Handle ═══         │
├─────────────────────────────────────┤
│       Form Fields (Bottom)          │
│   [TextField, Picker, Toggle...]    │
│   [Submit & Generate PDF]           │
└─────────────────────────────────────┘
```

## Quick Start

### 1. Create Xcode Project
- File → New → Project → App
- Name: `documentAI`
- Interface: SwiftUI

### 2. Add Files
Add all `.swift` files from `documentAI/` folder to your Xcode project.

### 3. Configure
Update `APIService.swift` with your backend URL:
```swift
private let baseURL = "https://your-api.run.app/api/v1"
```

### 4. Run
Press ⌘R to build and run.

## Project Structure

```
documentAI/
├── App/                    # App entry point
├── Features/
│   ├── Home/              # Upload screen
│   └── DocumentEditor/    # Split-screen editor
├── Core/
│   ├── Models/            # Data models
│   └── Services/          # API, storage
├── UI/
│   ├── Components/        # PDFKit, backgrounds
│   └── Theme/             # Colors, fonts
└── Extensions/            # PDF utilities
```

## Key Components

### Views
- `HomeView` - Document upload and selection
- `SplitScreenEditorView` - PDF + form split view

### ViewModels
- `HomeViewModel` - Upload logic
- `DocumentViewModel` - Form editing, autosave

### Services
- `APIService` - Backend communication
- `LocalFormStorageService` - Form persistence

## Documentation

- [Architecture](docs/ARCHITECTURE.md) - System design
- [Setup Guide](docs/SETUP.md) - Installation steps
- [Testing Guide](docs/TESTING.md) - Test checklist

## Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+

## License

MIT
