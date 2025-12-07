# DocumentAI iOS - Testing Guide

## Unit Tests

Located in `documentAITests/`:
- `DocumentDetectionResponseTests.swift`
- `IntegrationTests.swift`
- `PDFKitRepresentedViewTests.swift`

### Run Tests
```bash
⌘U  # Run all tests in Xcode
```

## Manual Testing Checklist

### Home Screen
- [ ] Gradient background animates
- [ ] Document picker button works
- [ ] Image picker button works
- [ ] File info displays after selection
- [ ] "Change" button allows reselection
- [ ] Upload progress bar animates
- [ ] Processing state shows correctly

### Split-Screen Editor
- [ ] PDF loads in top pane
- [ ] Form fields render in bottom pane
- [ ] Drag handle adjusts split ratio
- [ ] Split ratio constrained to 20%-80%
- [ ] Tapping PDF field scrolls to form field
- [ ] Tapping PDF field focuses TextField

### Form Editing
- [ ] Text fields are editable
- [ ] Checkbox toggles work
- [ ] Date picker works
- [ ] Select/Picker works
- [ ] Changes sync to PDF annotations
- [ ] Autosave triggers after 5 seconds
- [ ] Manual save button works

### PDF Interaction
- [ ] AcroForm PDFs show native fields
- [ ] Non-AcroForm PDFs show fallback alert
- [ ] QuickLook opens for fallback
- [ ] Field highlights appear on tap

### Submit Flow
- [ ] Submit button triggers API call
- [ ] Loading overlay shows
- [ ] Success alert appears
- [ ] "View PDF" option works
- [ ] "Share" option works
- [ ] "Upload Another" resets state

## Test PDFs

### AcroForm PDF (Native Fields)
Use any PDF with native form fields (e.g., IRS W-4 form)

### Non-AcroForm PDF (OCR Fallback)
Use any scanned document or image-based PDF

## API Testing

### Mock Mode
The `APIService.swift` includes stub implementations for testing without backend.

### Live Mode
Update `baseURL` to your deployed API:
```swift
private let baseURL = "https://documentai-api-xxx.run.app/api/v1"
```

## Debugging

### Console Logs
Look for these indicators:
- `✅` Success operations
- `📋` Widget mapping
- `✨` Synthetic widget creation
- `👆` User interactions
- `✏️` Value changes
- `⚠️` Warnings
- `❌` Errors

### Common Issues

**Widgets not appearing?**
- Check fieldRegions array is not empty
- Verify page indices are valid (0-based)
- Check coordinate values are 0-1 range

**Typing not working?**
- Ensure fieldIdToUUID mapping exists
- Check formValues binding
- Verify annotation has fieldName set

**Sync not working?**
- Check notification observers registered
- Verify UUID mapping correct
- Ensure updateUIView called

## Performance Testing

### Memory
- Monitor memory usage with large PDFs
- Check for leaks in Instruments

### Responsiveness
- PDF should not freeze during edits
- Autosave should not block UI
- Scrolling should be smooth

## Accessibility Testing

- [ ] VoiceOver reads field labels
- [ ] Dynamic Type scales correctly
- [ ] Color contrast meets guidelines
- [ ] Touch targets are adequate size
