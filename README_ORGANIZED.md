# DocumentAI - iOS App

A professional iOS app for AI-powered document processing with split-screen PDF editing.

## 🎯 Features

- **Split-Screen PDF Editor**: Custom vertical split with draggable handle
- **Two-Way Binding**: Real-time sync between form fields and PDF annotations
- **Autosave**: Automatic draft saving every 5 seconds
- **Tap-to-Focus**: Tap PDF fields to scroll and focus form inputs
- **Field Detection**: Supports both AcroForm (native) and OCR (fallback) fields
- **Responsive UI**: Efficient PDF rendering with limited redraw

## 📁 Project Structure

```
documentAI/
├── App/                              # App entry point
│   └── DocumentAIApp.swift
│
├── Features/                         # Feature modules (MVVM)
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── HomeViewModel.swift
│   │
│   └── DocumentEditor/
│       ├── SplitScreenEditorView.swift
│       ├── DocumentViewModel.swift
│       ├── FillDocumentView.swift (deprecated)
│       └── FillDocumentViewModel.swift (deprecated)
│
├── Core/                             # Business logic
│   ├── Models/
│   │   └── Models.swift
│   │
│   └── Services/
│       ├── APIService.swift
│       ├── LocalFormStorageService.swift
│       ├── DocumentPickerService.swift
│       └── ImagePickerService.swift
│
├── UI/                               # Reusable components
│   ├── Components/
│   │   ├── PDFKitRepresentedView.swift
│   │   └── AnimatedGradientBackground.swift
│   │
│   └── Theme/
│       └── Theme.swift
│
└── Resources/
    ├── Assets.xcassets/
    └── Info.plist
```

## 🚀 Getting Started

### Prerequisites

- Xcode 14.0+
- iOS 15.0+
- macOS 12.0+

### Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd documentai-swift
   ```

2. **Run setup script**
   ```bash
   bash scripts/setup_project.sh
   ```

3. **Open in Xcode**
   ```bash
   open documentAI.xcodeproj
   ```

4. **Organize Xcode project** (one-time setup)
   - In Project Navigator, delete old file references
   - Right-click `documentAI` folder → "Add Files to 'documentAI'..."
   - Select organized folders: `App/`, `Features/`, `Core/`, `UI/`
   - Uncheck "Copy items if needed"
   - Check "Create groups"
   - Check "Add to targets: documentAI"

5. **Build and run**
   ```bash
   # In Xcode
   ⌘B  # Build
   ⌘R  # Run
   ```

## 🏗️ Architecture

### MVVM Pattern

```
View (SwiftUI)
  ↓ @StateObject
ViewModel (ObservableObject)
  ↓ Uses
Service Layer
  ↓ Returns
Models (Structs)
```

### Triangle of Truth

The DocumentViewModel maintains a single source of truth:

```swift
@Published var formValues: [UUID: String] = [:]
```

All form field values flow through this dictionary, ensuring consistency between:
- SwiftUI TextFields (bottom pane)
- PDF annotations (top pane)
- Local storage (autosave)

### Data Flow

```
User edits TextField
    ↓
formValues[uuid] updated
    ↓
PDF annotation updated (two-way binding)
    ↓
Autosave after 5 seconds (debounced)
```

## 📚 Documentation

- **[PROJECT_ORGANIZATION.md](PROJECT_ORGANIZATION.md)** - Detailed folder structure
- **[SPLIT_SCREEN_ARCHITECTURE.md](SPLIT_SCREEN_ARCHITECTURE.md)** - Technical architecture
- **[ARCHITECTURE_DIAGRAM.md](ARCHITECTURE_DIAGRAM.md)** - Visual diagrams
- **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** - Implementation overview
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Quick reference guide

## 🔧 Development

### Adding New Features

1. Create feature folder in `Features/`
2. Add `FeatureView.swift` and `FeatureViewModel.swift`
3. Create models in `Core/Models/` if needed
4. Create services in `Core/Services/` if needed
5. Add to Xcode project
6. Update documentation

### Code Style

Following `cursorules.yaml`:
- MVVM architecture with SwiftUI
- Protocol-oriented programming
- Value types (structs) over classes
- async/await for concurrency
- Combine for reactive programming
- Strong type system with proper optionals

### Testing

```bash
# Run tests in Xcode
⌘U
```

## 🔌 Backend Integration

### API Response Format

```json
{
  "documentId": "string",
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

### Update API Endpoint

In `Core/Services/APIService.swift`:

```swift
private let baseURL = "https://your-api-endpoint.com"
```

## 🧪 Testing

### Manual Testing Checklist

- [ ] Upload PDF document
- [ ] Split-screen displays correctly
- [ ] Drag handle adjusts split ratio
- [ ] Edit form fields
- [ ] Verify PDF annotations update
- [ ] Check autosave logs (console)
- [ ] Reopen document to verify draft restoration
- [ ] Submit form

### Unit Tests

```bash
# Run in Xcode
⌘U
```

## 📱 Supported Platforms

- iPhone (iOS 15.0+)
- iPad (iOS 15.0+)
- Portrait and landscape orientations

## 🎨 UI/UX

- **Design System**: Custom theme with consistent colors, fonts, spacing
- **Dark Mode**: Supported
- **Dynamic Type**: Supported
- **Accessibility**: VoiceOver compatible
- **Animations**: Smooth transitions and gestures

## 🔐 Security

- Sensitive data encrypted
- Keychain for credentials
- App Transport Security enabled
- Input validation
- Secure file storage

## 📊 Performance

- Lazy loading for views
- Efficient PDF rendering (limited redraw)
- Debounced autosave (prevents excessive writes)
- Background task handling
- Memory management

## 🐛 Troubleshooting

### Build Errors

```bash
# Clean build folder
⌘⇧K

# Rebuild
⌘B
```

### Files Not Found

Ensure files are added to Xcode project target:
1. Select file in Project Navigator
2. Show File Inspector (⌥⌘1)
3. Check "Target Membership: documentAI"

### PDF Not Displaying

Check console for errors:
```swift
print("PDF URL: \(viewModel.pdfURL)")
```

## 📝 License

[Your License Here]

## 👥 Contributors

[Your Team Here]

## 🙏 Acknowledgments

- Apple's SwiftUI framework
- PDFKit for PDF rendering
- Combine for reactive programming

## 📞 Support

For issues and questions:
- GitHub Issues: [Your Repo]
- Email: [Your Email]
- Documentation: See `/docs` folder

## 🗺️ Roadmap

### Phase 1: Core Functionality ✅
- [x] Split-screen editor
- [x] Two-way binding
- [x] Autosave
- [x] Tap-to-focus

### Phase 2: Enhanced UX
- [ ] Field overlay boxes on PDF
- [ ] Visual feedback for focused field
- [ ] Field validation with error messages
- [ ] Progress indicator for autosave

### Phase 3: Advanced Features
- [ ] Multi-page PDF support
- [ ] Undo/Redo functionality
- [ ] Export/Share filled PDF
- [ ] Offline mode with sync

### Phase 4: Polish
- [ ] Animations for split handle
- [ ] Haptic feedback
- [ ] Accessibility improvements
- [ ] Comprehensive test coverage

## 🚀 Deployment

### TestFlight

```bash
# Archive for distribution
# Product → Archive
```

### App Store

1. Update version in Xcode
2. Archive build
3. Upload to App Store Connect
4. Submit for review

## 📈 Analytics

- User engagement tracking
- Error logging
- Performance monitoring
- Crash reporting

## 🔄 CI/CD

- Automated builds
- Unit test execution
- Code quality checks
- Deployment automation

---

**Built with ❤️ using Swift and SwiftUI**
