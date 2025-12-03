# Xcode Project Management Guide

## 🎯 Overview

This guide explains how to manage the DocumentAI Xcode project, including adding new files, organizing groups, and maintaining the project structure.

## 📁 Current Project Structure

### File System (Finder)
```
documentAI/
├── App/
├── Features/
│   ├── Home/
│   └── DocumentEditor/
├── Core/
│   ├── Models/
│   └── Services/
├── UI/
│   ├── Components/
│   └── Theme/
└── Resources/
```

### Xcode Groups (Should Match)
```
documentAI (Project)
├── documentAI (Target)
│   ├── App
│   ├── Features
│   │   ├── Home
│   │   └── DocumentEditor
│   ├── Core
│   │   ├── Models
│   │   └── Services
│   ├── UI
│   │   ├── Components
│   │   └── Theme
│   └── Resources
└── Products
```

## 🔧 One-Time Setup

### Step 1: Clean Up Old References

1. Open `documentAI.xcodeproj` in Xcode
2. In Project Navigator (⌘1), select old file references at root level
3. Right-click → Delete → **Remove Reference** (not Move to Trash)
4. Repeat for all files that have been moved to organized folders

### Step 2: Add Organized Folders

1. Right-click on `documentAI` folder in Project Navigator
2. Select **"Add Files to 'documentAI'..."**
3. Navigate to `documentAI/` folder
4. Select these folders (hold ⌘ to select multiple):
   - `App/`
   - `Features/`
   - `Core/`
   - `UI/`

5. **Important Settings:**
   - ☐ **Uncheck** "Copy items if needed"
   - ☑ **Check** "Create groups" (not folder references)
   - ☑ **Check** "Add to targets: documentAI"
   - ☐ **Uncheck** "Create folder references"

6. Click **"Add"**

### Step 3: Verify Structure

1. Expand all groups in Project Navigator
2. Verify folder structure matches file system
3. Check each file has blue folder icon (groups) not yellow (folder references)
4. Verify all files show target membership: documentAI

### Step 4: Build

```bash
⌘⇧K  # Clean Build Folder
⌘B   # Build
```

If build succeeds, setup is complete! ✅

## ➕ Adding New Files

### Method 1: Create in Xcode (Recommended)

1. Right-click on appropriate group (e.g., `Features/Home/`)
2. Select **"New File..."**
3. Choose template (Swift File, SwiftUI View, etc.)
4. Name the file
5. Ensure "Targets: documentAI" is checked
6. Click **"Create"**

File is automatically added to both file system and Xcode project! ✅

### Method 2: Add Existing File

If you created a file outside Xcode:

1. Right-click on appropriate group
2. Select **"Add Files to 'documentAI'..."**
3. Navigate to the file
4. **Important Settings:**
   - ☐ **Uncheck** "Copy items if needed" (if file is already in project folder)
   - ☑ **Check** "Add to targets: documentAI"
5. Click **"Add"**

### Method 3: Drag and Drop

1. Open Finder and Xcode side-by-side
2. Drag file from Finder into appropriate Xcode group
3. In dialog:
   - ☐ **Uncheck** "Copy items if needed"
   - ☑ **Check** "Add to targets: documentAI"
4. Click **"Finish"**

## 📂 Creating New Groups

### In Xcode

1. Right-click on parent group
2. Select **"New Group"**
3. Name the group (e.g., `NewFeature`)
4. Add files to the group

### Matching File System

To keep Xcode groups and file system in sync:

1. Create folder in Finder: `documentAI/Features/NewFeature/`
2. In Xcode, right-click `Features` group
3. Select **"Add Files to 'documentAI'..."**
4. Select the `NewFeature/` folder
5. Ensure "Create groups" is selected
6. Click **"Add"**

## 🔍 Verifying File Membership

### Check Target Membership

1. Select file in Project Navigator
2. Open File Inspector (⌥⌘1)
3. Under "Target Membership", verify "documentAI" is checked

### Check File Location

1. Select file in Project Navigator
2. Open File Inspector (⌥⌘1)
3. Under "Identity and Type", check "Location"
4. Should show relative path from project root

## 🗑️ Removing Files

### Remove Reference Only

1. Select file in Project Navigator
2. Press Delete or Right-click → Delete
3. Choose **"Remove Reference"**
4. File stays in file system, removed from Xcode only

### Delete File Completely

1. Select file in Project Navigator
2. Press Delete or Right-click → Delete
3. Choose **"Move to Trash"**
4. File deleted from both Xcode and file system

## 🔄 Moving Files

### Within Xcode

1. Drag file to new group in Project Navigator
2. File reference moves, but file system location unchanged
3. To sync file system:
   - Select file → File Inspector → Location → Click folder icon
   - Choose new location in file system

### Recommended: Move in Both Places

1. **In Finder**: Move file to new folder
2. **In Xcode**: 
   - Delete old reference (Remove Reference)
   - Add file from new location

## 🛠️ Troubleshooting

### File Shows Red (Not Found)

**Cause**: File moved in Finder but not updated in Xcode

**Fix**:
1. Select red file in Project Navigator
2. Open File Inspector (⌥⌘1)
3. Under "Location", click folder icon
4. Navigate to actual file location
5. Select file

### File Not Compiling

**Cause**: File not added to target

**Fix**:
1. Select file in Project Navigator
2. Open File Inspector (⌥⌘1)
3. Under "Target Membership", check "documentAI"

### Duplicate Files in Project

**Cause**: File added multiple times

**Fix**:
1. Select duplicate references
2. Delete → Remove Reference
3. Keep only one reference

### Groups Don't Match File System

**Cause**: Groups created without matching folders

**Fix**:
1. Create matching folders in Finder
2. Move files in Finder to match groups
3. Update file locations in Xcode (see "File Shows Red" above)

## 📋 Best Practices

### 1. Always Use Groups

- ✅ Create groups for organization
- ❌ Don't put all files at root level

### 2. Match File System

- ✅ Keep Xcode groups and Finder folders in sync
- ❌ Don't create groups without matching folders

### 3. Use Descriptive Names

- ✅ `Features/DocumentEditor/`
- ❌ `Stuff/`, `Misc/`, `Temp/`

### 4. Organize by Feature

- ✅ Group related files together
- ❌ Separate views from view models

### 5. Check Target Membership

- ✅ Always verify files are added to target
- ❌ Don't assume files are automatically included

### 6. Clean Build Regularly

```bash
⌘⇧K  # Clean Build Folder
```

### 7. Use Version Control

```bash
git status  # Check what changed
git add .   # Stage changes
git commit -m "Organized project structure"
```

## 🔧 Automation Scripts

### Check for Untracked Files

```bash
python3 scripts/update_xcode_project.py
```

### Reorganize Project

```bash
bash scripts/setup_project.sh
```

## 📊 Project Statistics

### View File Count

```bash
find documentAI -name "*.swift" -type f | wc -l
```

### View Project Structure

```bash
tree documentAI -L 3 -I 'Assets.xcassets|*.xcuserdata'
```

## 🎓 Learning Resources

- [Xcode Project Management](https://developer.apple.com/documentation/xcode/managing-files-and-folders-in-your-xcode-project)
- [Organizing Your Code](https://developer.apple.com/documentation/xcode/organizing-your-code)
- [Build System](https://developer.apple.com/documentation/xcode/build-system)

## ✅ Checklist for New Files

- [ ] File created in appropriate folder
- [ ] File added to Xcode project
- [ ] Target membership verified (documentAI)
- [ ] File compiles without errors
- [ ] File location matches group structure
- [ ] Changes committed to version control

## 🚀 Quick Commands

```bash
# Open Xcode project
open documentAI.xcodeproj

# Clean build
# In Xcode: ⌘⇧K

# Build
# In Xcode: ⌘B

# Run
# In Xcode: ⌘R

# Check project structure
tree documentAI -L 2

# Find Swift files
find documentAI -name "*.swift"

# Count Swift files
find documentAI -name "*.swift" | wc -l
```

## 📞 Getting Help

If you encounter issues:

1. Check this guide
2. Clean build folder (⌘⇧K)
3. Restart Xcode
4. Check file locations in File Inspector
5. Verify target membership
6. Review Xcode console for errors

## 🎯 Summary

**Key Points:**
- Keep Xcode groups and file system in sync
- Always check target membership
- Use "Create groups" not "folder references"
- Clean build regularly
- Commit changes to version control

**Common Workflow:**
1. Create file in Xcode (or add existing)
2. Verify target membership
3. Build to check for errors
4. Commit to version control

**Maintenance:**
- Run `scripts/update_xcode_project.py` periodically
- Keep documentation updated
- Review project structure regularly
