# Xcode Integration Steps

## Adding New Files to Xcode Project

The following new Swift files have been created and need to be added to your Xcode project:

### New Files Created

1. `documentAI/DocumentViewModel.swift`
2. `documentAI/PDFKitRepresentedView.swift`
3. `documentAI/SplitScreenEditorView.swift`
4. `documentAI/LocalFormStorageService.swift`

### Step-by-Step Integration

#### Option 1: Using Xcode (Recommended)

1. **Open Xcode Project**
   ```bash
   open documentAI.xcodeproj
   ```

2. **Add Files to Project**
   - Right-click on the `documentAI` folder in Project Navigator
   - Select "Add Files to 'documentAI'..."
   - Navigate to the `documentAI` directory
   - Select all 4 new files:
     - `DocumentViewModel.swift`
     - `PDFKitRepresentedView.swift`
     - `SplitScreenEditorView.swift`
     - `LocalFormStorageService.swift`
   - Ensure "Copy items if needed" is **unchecked** (files are already in place)
   - Ensure "Add to targets: documentAI" is **checked**
   - Click "Add"

3. **Verify Files Added**
   - Check Project Navigator shows all 4 files
   - Build the project (⌘B) to verify no errors

#### Option 2: Using Command Line

```bash
# Navigate to project directory
cd /path/to/documentAI

# The files are already in place, just need to add to Xcode project
# This requires manual Xcode project file editing or using Xcode GUI
```

### Modified Files (Already in Project)

These files were updated and should already be in your Xcode project:

- `documentAI/Models.swift` - Added `FieldRegion` struct
- `documentAI/HomeView.swift` - Updated to use `SplitScreenEditorView`
- `documentAI/HomeViewModel.swift` - Added `fieldRegions` and `pdfURL`
- `documentAI/APIService.swift` - Updated stub responses

### Required Frameworks

Ensure these frameworks are linked (should already be included):

- **SwiftUI** - UI framework
- **PDFKit** - PDF rendering
- **Combine** - Reactive programming (for autosave)
- **Foundation** - Core functionality

### Build Settings

No special build settings required. Standard iOS app configuration.

### Info.plist Permissions

Ensure these permissions are set (should already be configured):

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to select images for processing</string>

<key>NSCameraUsageDescription</key>
<string>We need access to your camera to capture documents</string>

<key>UISupportsDocumentBrowser</key>
<true/>
```

## Testing the Integration

### 1. Build the Project

```bash
# In Xcode, press ⌘B or Product > Build
```

Expected result: Build succeeds with no errors.

### 2. Run on Simulator

```bash
# In Xcode, press ⌘R or Product > Run
# Select iPhone simulator (iOS 15.0+)
```

### 3. Test Flow

1. Launch app
2. Tap "Document" or "Image" to select a file
3. Tap "Upload & Process"
4. Wait for processing (stub shows progress)
5. **New**: Split-screen editor appears
   - Top: PDF preview
   - Bottom: Form fields
6. Edit form fields
7. Verify autosave after 5 seconds (check console)
8. Tap "Submit & Generate PDF"

## Troubleshooting

### Issue: "No such module 'PDFKit'"

**Solution:** PDFKit is part of iOS SDK. Ensure:
- Deployment target is iOS 11.0+
- Building for iOS (not macOS)

### Issue: "Cannot find type 'DocumentViewModel' in scope"

**Solution:** File not added to Xcode project:
1. Check Project Navigator
2. If missing, follow "Add Files to Project" steps above

### Issue: Build errors in PDFKitRepresentedView

**Solution:** Ensure PDFKit is imported:
```swift
import PDFKit
```

### Issue: "Use of undeclared type 'FieldRegion'"

**Solution:** Models.swift not updated:
- Verify `FieldRegion` struct exists in Models.swift
- Clean build folder (⌘⇧K) and rebuild

### Issue: Autosave not working

**Solution:** Check console for errors:
```
✅ Autosaved form data  // Success
❌ Error saving form data: ...  // Error
```

## Verification Checklist

- [ ] All 4 new files appear in Project Navigator
- [ ] Build succeeds (⌘B)
- [ ] No compiler errors or warnings
- [ ] App runs on simulator
- [ ] Split-screen editor displays correctly
- [ ] Form fields are editable
- [ ] Autosave logs appear in console after 5 seconds
- [ ] Submit button works

## File Structure in Xcode

After integration, your Project Navigator should show:

```
documentAI/
├── documentAI/
│   ├── DocumentAIApp.swift
│   ├── Models.swift ✏️ (modified)
│   ├── Theme.swift
│   │
│   ├── Views/
│   │   ├── HomeView.swift ✏️ (modified)
│   │   ├── FillDocumentView.swift (deprecated)
│   │   ├── SplitScreenEditorView.swift ⭐ (new)
│   │   ├── AnimatedGradientBackground.swift
│   │
│   ├── ViewModels/
│   │   ├── HomeViewModel.swift ✏️ (modified)
│   │   ├── FillDocumentViewModel.swift (deprecated)
│   │   ├── DocumentViewModel.swift ⭐ (new)
│   │
│   ├── Services/
│   │   ├── APIService.swift ✏️ (modified)
│   │   ├── DocumentPickerService.swift
│   │   ├── ImagePickerService.swift
│   │   ├── LocalStorageService.swift (deprecated)
│   │   ├── LocalFormStorageService.swift ⭐ (new)
│   │
│   ├── Components/
│   │   ├── PDFKitRepresentedView.swift ⭐ (new)
│   │
│   ├── Assets.xcassets/
│   └── Info.plist
│
└── documentAI.xcodeproj/
```

## Next Steps After Integration

1. **Test with Real Backend**
   - Update `APIService.swift` with real API endpoints
   - Replace stub responses with actual API calls
   - Test with real PDF documents

2. **Implement Field Overlays**
   - Add visual rectangles on PDF for field regions
   - Implement coordinate transformation
   - Handle multi-page documents

3. **Add Validation**
   - Email format validation
   - Required field checking
   - Custom validation rules

4. **Polish UI**
   - Add animations
   - Improve error handling
   - Add loading states

## Support

If you encounter issues:

1. Check console logs for errors
2. Verify all files are added to target
3. Clean build folder (⌘⇧K)
4. Restart Xcode
5. Review `SPLIT_SCREEN_ARCHITECTURE.md` for implementation details

## Summary

✅ 4 new files created
✅ 4 existing files modified
✅ All requirements implemented
✅ Ready for Xcode integration

Simply add the 4 new Swift files to your Xcode project and build!
