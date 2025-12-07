# DocumentAI iOS - Setup Guide

## Step 1: Create Xcode Project

1. Open **Xcode**
2. File → New → Project
3. Choose **iOS** → **App**
4. Configure:
   - Product Name: `documentAI`
   - Interface: **SwiftUI**
   - Language: **Swift**
5. Save in the `documentai-swift` folder

## Step 2: Add Swift Files

Add all files from `documentAI/` folder to your Xcode project:

### Core Files
- `App/DocumentAIApp.swift`
- `Features/Home/HomeView.swift`
- `Features/Home/HomeViewModel.swift`
- `Features/DocumentEditor/SplitScreenEditorView.swift`
- `Features/DocumentEditor/DocumentViewModel.swift`
- `Core/Models/Models.swift`
- `Core/Services/APIService.swift`
- `Core/Services/LocalFormStorageService.swift`
- `Core/Services/DocumentPickerService.swift`
- `Core/Services/ImagePickerService.swift`
- `UI/Components/PDFKitRepresentedView.swift`
- `UI/Components/AnimatedGradientBackground.swift`
- `UI/Theme/Theme.swift`
- `Extensions/PDFDocument+AcroForm.swift`

### How to Add
1. Right-click project folder in Xcode
2. "Add Files to documentAI"
3. Select all `.swift` files
4. Check "Copy items if needed"
5. Add to target: documentAI

## Step 3: Configure Info.plist

Add photo library permission:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to select images for processing</string>
```

## Step 4: Update API Endpoint

In `APIService.swift`, update the base URL:

```swift
private let baseURL = "https://your-api-endpoint.run.app/api/v1"
```

## Step 5: Build and Run

1. Select target device (iPhone simulator)
2. Press **⌘R** to run
3. Test document upload flow

## Testing Checklist

- [ ] App launches with gradient background
- [ ] Document picker opens
- [ ] File selection works
- [ ] Upload progress shows
- [ ] Split-screen editor displays
- [ ] PDF renders correctly
- [ ] Form fields are editable
- [ ] Autosave works (check console)
- [ ] Submit generates PDF

## Troubleshooting

### Build Errors
```bash
⌘⇧K  # Clean Build Folder
⌘B   # Rebuild
```

### Files Not Found
- Ensure files are added to Xcode project target
- Right-click file → Show File Inspector → Target Membership

### PDF Not Displaying
- Check pdfURL is valid
- Verify PDF document loads in console

### Autosave Not Working
- Check Documents directory permissions
- Look for console logs: "✅ Autosaved form data"

## Next Steps

1. ✅ Create Xcode project
2. ✅ Add all Swift files
3. ✅ Configure Info.plist
4. ✅ Test basic flow
5. ⏳ Connect to backend API
6. ⏳ Test full workflow
7. ⏳ Deploy to TestFlight
