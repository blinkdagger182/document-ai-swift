# DocumentAI Project Organization

## 📁 Folder Structure

Following Apple's best practices and MVVM architecture:

```
documentAI/
├── App/
│   └── DocumentAIApp.swift          # App entry point
│
├── Features/                         # Feature modules
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
├── Core/                             # Core business logic
│   ├── Models/
│   │   └── Models.swift             # Data models
│   │
│   └── Services/
│       ├── APIService.swift
│       ├── LocalFormStorageService.swift
│       ├── LocalStorageService.swift (deprecated)
│       ├── DocumentPickerService.swift
│       └── ImagePickerService.swift
│
├── UI/                               # Reusable UI components
│   ├── Components/
│   │   ├── PDFKitRepresentedView.swift
│   │   └── AnimatedGradientBackground.swift
│   │
│   └── Theme/
│       └── Theme.swift              # Colors, fonts, spacing
│
└── Resources/                        # Assets and resources
    ├── Assets.xcassets/
    └── Info.plist
```

## 🔄 Migration Status

### ✅ Organized Files (New Structure)

**Features/Home/**
- HomeView.swift
- HomeViewModel.swift

**Features/DocumentEditor/**
- SplitScreenEditorView.swift
- DocumentViewModel.swift

**Core/Models/**
- Models.swift

**Core/Services/**
- APIService.swift
- LocalFormStorageService.swift
- DocumentPickerService.swift
- ImagePickerService.swift

**UI/Components/**
- PDFKitRepresentedView.swift
- AnimatedGradientBackground.swift

**UI/Theme/**
- Theme.swift

### 📦 Root Level (To Be Organized)

These files are still in `documentAI/` root:
- DocumentAIApp.swift → Move to `App/`
- FillDocumentView.swift → Keep in `Features/DocumentEditor/` (deprecated)
- FillDocumentViewModel.swift → Keep in `Features/DocumentEditor/` (deprecated)
- LocalStorageService.swift → Keep in `Core/Services/` (deprecated)

## 🎯 Next Steps

### 1. Update Xcode Project

Run the update script:
```bash
python3 scripts/update_xcode_project.py
```

Or manually add files in Xcode:
1. Open `documentAI.xcodeproj`
2. Create folder groups matching the structure above
3. Drag files from Finder into appropriate groups
4. Ensure "Add to targets: documentAI" is checked

### 2. Update Import Statements

No changes needed! Swift uses module-level imports, so file location doesn't affect imports.

### 3. Clean Build

```bash
# In Xcode
⌘⇧K  # Clean Build Folder
⌘B   # Build
```

## 📋 File Organization Rules

### Features/
- **Purpose**: Feature-specific views and view models
- **Pattern**: `FeatureName/FeatureView.swift` + `FeatureViewModel.swift`
- **Example**: `Home/HomeView.swift`, `Home/HomeViewModel.swift`

### Core/
- **Purpose**: Business logic, models, services
- **Subfolders**:
  - `Models/`: Data structures, entities
  - `Services/`: API, storage, utilities
  - `Managers/`: Complex business logic coordinators

### UI/
- **Purpose**: Reusable UI components and styling
- **Subfolders**:
  - `Components/`: Reusable views (buttons, cards, etc.)
  - `Theme/`: Colors, fonts, spacing constants
  - `Modifiers/`: Custom view modifiers

### Resources/
- **Purpose**: Assets, plists, localization
- **Contents**: Images, colors, fonts, configuration files

## 🔧 Maintenance

### Adding New Files

1. **Create file in appropriate folder**
   ```bash
   # Example: New service
   touch documentAI/Core/Services/NewService.swift
   ```

2. **Run update script**
   ```bash
   python3 scripts/update_xcode_project.py
   ```

3. **Add to Xcode manually** (script will show instructions)

### Refactoring Existing Files

1. Move file in Finder to new location
2. In Xcode, delete reference (Don't move to trash)
3. Add file back from new location
4. Verify target membership

## 📊 Current Statistics

- **Total Swift Files**: 16
- **Features**: 2 (Home, DocumentEditor)
- **Services**: 5
- **UI Components**: 2
- **Models**: 1 (with multiple structs)

## 🎨 Architecture Patterns

### MVVM (Model-View-ViewModel)

```
View (SwiftUI)
  ↓ @StateObject
ViewModel (ObservableObject)
  ↓ Uses
Service Layer
  ↓ Returns
Models (Structs)
```

### Example: Home Feature

```swift
// View
HomeView.swift
  @StateObject var viewModel: HomeViewModel
  
// ViewModel
HomeViewModel.swift
  @Published var state
  Uses: APIService, DocumentPickerService
  
// Services
APIService.swift
  Returns: ProcessResult (Model)
```

## 🚀 Benefits of This Structure

1. **Scalability**: Easy to add new features
2. **Maintainability**: Clear separation of concerns
3. **Testability**: Services and ViewModels are testable
4. **Reusability**: UI components can be shared
5. **Team Collaboration**: Clear ownership boundaries

## 📝 Naming Conventions

### Files
- Views: `FeatureView.swift` (e.g., `HomeView.swift`)
- ViewModels: `FeatureViewModel.swift` (e.g., `HomeViewModel.swift`)
- Services: `PurposeService.swift` (e.g., `APIService.swift`)
- Models: `EntityName.swift` or `Models.swift` for multiple

### Folders
- PascalCase for feature folders: `DocumentEditor/`
- PascalCase for category folders: `Services/`, `Models/`

## 🔍 Finding Files

### By Feature
```
Features/Home/          → Home screen
Features/DocumentEditor/ → PDF editing
```

### By Type
```
Core/Services/    → All services
Core/Models/      → All data models
UI/Components/    → All reusable UI
```

### By Purpose
```
APIService.swift           → Backend communication
LocalFormStorageService.swift → Local persistence
PDFKitRepresentedView.swift   → PDF rendering
Theme.swift                → App styling
```

## ✅ Checklist for New Features

- [ ] Create feature folder in `Features/`
- [ ] Add `FeatureView.swift` and `FeatureViewModel.swift`
- [ ] Create models in `Core/Models/` if needed
- [ ] Create services in `Core/Services/` if needed
- [ ] Add reusable components to `UI/Components/`
- [ ] Update this documentation
- [ ] Add to Xcode project
- [ ] Write tests

## 🎓 Learning Resources

- [Apple's App Architecture](https://developer.apple.com/documentation/swiftui/app-structure)
- [MVVM in SwiftUI](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)
- [Project Organization Best Practices](https://developer.apple.com/documentation/xcode/organizing-your-code)
