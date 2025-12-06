# How to Add Files to Xcode and Build to iPhone 16

## Step 1: Add Missing Files to Xcode

The following files need to be added to the Xcode project:

1. **`documentAI/Extensions/PDFDocument+AcroForm.swift`**
2. **`documentAI/Features/DocumentEditor/QuickLookPDFView.swift`**

### Instructions:

1. Open `documentAI.xcodeproj` in Xcode
2. In the Project Navigator (left sidebar), right-click on the `documentAI` folder
3. Select **"Add Files to documentAI..."**
4. Navigate to the project folder and select these two files:
   - `documentAI/Extensions/PDFDocument+AcroForm.swift`
   - `documentAI/Features/DocumentEditor/QuickLookPDFView.swift`
5. **IMPORTANT:** Uncheck "Copy items if needed" (files are already in the right place)
6. **IMPORTANT:** Check "Add to targets: documentAI"
7. Click **"Add"**

## Step 2: Build to Your iPhone 16

Your iPhone 16 details:
- **Device Name:** Rizsaber
- **UDID:** 33E929C3-43A2-59E0-B5AF-59D9105A5FF1
- **Model:** iPhone18,1 (iPhone 16)
- **Developer Mode:** ✅ Enabled

### Instructions:

1. Connect your iPhone 16 ("Rizsaber") to your Mac via USB or ensure it's on the same network
2. In Xcode, select your device from the device dropdown (top toolbar)
   - Click the device selector next to the scheme name
   - Select "Rizsaber" from the list
3. Click the **Play** button (▶️) or press **Cmd+R** to build and run
4. If prompted, enter your Mac password to allow codesigning
5. On your iPhone, you may need to trust the developer certificate:
   - Go to **Settings > General > VPN & Device Management**
   - Tap on your developer profile
   - Tap **"Trust"**

## Alternative: Build from Command Line

After adding the files to Xcode, you can also build from the terminal:

```bash
# Build for device
xcodebuild -project documentAI.xcodeproj \
  -scheme documentAI \
  -configuration Debug \
  -destination 'platform=iOS,id=33E929C3-43A2-59E0-B5AF-59D9105A5FF1' \
  build
```

## Troubleshooting

### If you see "No such module 'PDFKit'" or similar errors:
- Clean the build folder: **Product > Clean Build Folder** (Shift+Cmd+K)
- Rebuild: **Product > Build** (Cmd+B)

### If the device doesn't appear:
- Make sure your iPhone is unlocked
- Trust the computer if prompted on your iPhone
- Check that Developer Mode is enabled on your iPhone:
  - **Settings > Privacy & Security > Developer Mode**

### If codesigning fails:
- Go to **Signing & Capabilities** tab in Xcode
- Select your Apple ID team
- Xcode will automatically manage signing

## What the App Does

After building, the app will:

1. **For PDFs with native AcroForm fields:**
   - Display interactive fields with blue highlights
   - Allow inline editing (tap to edit)
   - Behave exactly like iOS Files.app

2. **For PDFs without native fields:**
   - Show an alert: "This PDF has no interactive fields"
   - Offer to open in QuickLook (Files Mode)
   - Use Apple's ML form detector to find fillable areas

## Files Added

### PDFDocument+AcroForm.swift
Extension that detects if a PDF has native interactive form fields.

### QuickLookPDFView.swift
SwiftUI wrapper for QLPreviewController that uses Apple's built-in form detection (same as Files.app).

---

**Ready to test!** 🚀
