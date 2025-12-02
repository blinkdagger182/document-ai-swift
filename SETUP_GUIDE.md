# documentAI iOS - Quick Setup Guide

## Step 1: Create Xcode Project

1. Open **Xcode**
2. File → New → Project
3. Choose **iOS** → **App**
4. Configure:
   - Product Name: `documentAI`
   - Team: (your team)
   - Organization Identifier: `com.yourcompany`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: None
   - Uncheck "Include Tests"
5. Save in the `documentai-swift` folder

## Step 2: Add Swift Files

In Xcode, add all the generated `.swift` files:

### Required Files (13 total)
1. ✅ DocumentAIApp.swift (replace default App file)
2. ✅ HomeView.swift (replace ContentView.swift)
3. ✅ FillDocumentView.swift
4. ✅ HomeViewModel.swift
5. ✅ FillDocumentViewModel.swift
6. ✅ DocumentPickerService.swift
7. ✅ ImagePickerService.swift
8. ✅ APIService.swift
9. ✅ LocalStorageService.swift
10. ✅ AnimatedGradientBackground.swift
11. ✅ Models.swift
12. ✅ Theme.swift

### How to Add Files
- Right-click on project folder
- Add Files to "documentAI"
- Select all `.swift` files
- Check "Copy items if needed"
- Add to target: documentAI

## Step 3: Configure Info.plist

Add photo library permission:

1. Select project in navigator
2. Select target → Info tab
3. Add new key: `NSPhotoLibraryUsageDescription`
4. Value: `We need access to your photo library to select images for processing`

Or edit Info.plist directly:
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to select images for processing</string>
```

## Step 4: Update API Endpoint

Open `APIService.swift` and update:

```swift
private let baseURL = "https://your-api-endpoint.com"
```

Replace with your actual backend URL (will be provided later for document-ai-fastapi integration).

## Step 5: Build and Run

1. Select target device (iPhone simulator or physical device)
2. Press **⌘R** or click Run button
3. App should launch with gradient background and upload screen

## Step 6: Test Basic Flow

### Test Document Selection
1. Tap "Document" button
2. Select a PDF or image
3. File info should display

### Test Upload (Stub)
1. Tap "Upload & Process"
2. Progress bar should animate 0-100%
3. Should navigate to Fill Document screen

### Test Form Filling (Stub)
1. Fill in the stub form fields
2. Tap "Save Progress" (should show alert)
3. Tap "Submit & Generate PDF"
4. Should show success alert with 3 options

## Step 7: Implement Real API Integration

Replace stub methods in `APIService.swift`:

### Upload and Process
```swift
func uploadAndProcessDocument(
    file: DocumentModel,
    progressHandler: @escaping (Double) -> Void
) async throws -> ProcessResult {
    // TODO: Implement multipart upload
    // TODO: Call your backend endpoint
    // TODO: Parse response into ProcessResult
}
```

### Overlay PDF
```swift
func overlayPDF(
    document: DocumentModel,
    documentId: String,
    formData: FormData
) async throws -> OverlayResult {
    // TODO: Send form data to backend
    // TODO: Download generated PDF
    // TODO: Return local PDF URL
}
```

## Troubleshooting

### Build Errors

**Error: "Cannot find type 'DocumentModel' in scope"**
- Solution: Make sure all files are added to the target

**Error: "Missing Info.plist key"**
- Solution: Add NSPhotoLibraryUsageDescription to Info.plist

**Error: "Module compiled with Swift X.X cannot be imported"**
- Solution: Clean build folder (⌘⇧K) and rebuild

### Runtime Issues

**Picker not showing**
- Check Info.plist permissions
- Check device/simulator has photos

**Upload not working**
- Check API endpoint URL
- Check network connectivity
- Check backend is running

**Form data not saving**
- Check Documents directory permissions
- Check console for error logs

## Project Structure in Xcode

Organize files in groups:

```
documentAI/
├── App/
│   └── DocumentAIApp.swift
├── Views/
│   ├── HomeView.swift
│   ├── FillDocumentView.swift
│   └── AnimatedGradientBackground.swift
├── ViewModels/
│   ├── HomeViewModel.swift
│   └── FillDocumentViewModel.swift
├── Services/
│   ├── DocumentPickerService.swift
│   ├── ImagePickerService.swift
│   ├── APIService.swift
│   └── LocalStorageService.swift
├── Models/
│   └── Models.swift
└── Theme/
    └── Theme.swift
```

## Next Steps

1. ✅ Create Xcode project
2. ✅ Add all Swift files
3. ✅ Configure Info.plist
4. ✅ Test basic flow with stubs
5. ⏳ Wait for document-ai-fastapi backend
6. ⏳ Integrate real API endpoints
7. ⏳ Test full upload → process → fill → generate flow
8. ⏳ Add PDF viewer
9. ⏳ Add share functionality
10. ⏳ Deploy to TestFlight

## Backend Integration (Coming Next)

You mentioned you'll provide a prompt for `document-ai-fastapi` folder next. Once that's ready:

1. Update `APIService.swift` with real endpoints
2. Test upload and process flow
3. Test overlay PDF generation
4. Verify form data structure matches backend expectations

## Support

If you encounter issues:
1. Check console logs in Xcode
2. Verify all files are added to target
3. Clean build folder and rebuild
4. Check Info.plist permissions
5. Verify API endpoint is accessible

Ready to integrate with your backend once document-ai-fastapi is complete! 🚀
