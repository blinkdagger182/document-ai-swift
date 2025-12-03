#!/usr/bin/env python3
"""
Reorganize Xcode project.pbxproj to match organized folder structure
"""

import re
import sys
from pathlib import Path

def reorganize_pbxproj():
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    pbxproj_path = project_root / 'documentAI.xcodeproj' / 'project.pbxproj'
    
    if not pbxproj_path.exists():
        print(f"❌ Error: {pbxproj_path} not found")
        sys.exit(1)
    
    print(f"📝 Reading {pbxproj_path}")
    with open(pbxproj_path, 'r') as f:
        lines = f.readlines()
    
    # Backup
    backup_path = pbxproj_path.with_suffix('.pbxproj.backup')
    print(f"💾 Creating backup at {backup_path}")
    with open(backup_path, 'w') as f:
        f.writelines(lines)
    
    # Update file references to include paths
    updates = {
        'B1000001 /* DocumentAIApp.swift */': 'B1000001 /* DocumentAIApp.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = App/DocumentAIApp.swift; sourceTree = "<group>"; };',
        'B1000002 /* HomeView.swift */': 'B1000002 /* HomeView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Features/Home/HomeView.swift; sourceTree = "<group>"; };',
        'B1000004 /* HomeViewModel.swift */': 'B1000004 /* HomeViewModel.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Features/Home/HomeViewModel.swift; sourceTree = "<group>"; };',
        'B1000003 /* FillDocumentView.swift */': 'B1000003 /* FillDocumentView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Features/DocumentEditor/FillDocumentView.swift; sourceTree = "<group>"; };',
        'B1000005 /* FillDocumentViewModel.swift */': 'B1000005 /* FillDocumentViewModel.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Features/DocumentEditor/FillDocumentViewModel.swift; sourceTree = "<group>"; };',
        'FC03BDB52EDFE96500CA1203 /* DocumentViewModel.swift */': 'FC03BDB52EDFE96500CA1203 /* DocumentViewModel.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Features/DocumentEditor/DocumentViewModel.swift; sourceTree = "<group>"; };',
        'FC03BDB82EDFE96500CA1203 /* SplitScreenEditorView.swift */': 'FC03BDB82EDFE96500CA1203 /* SplitScreenEditorView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Features/DocumentEditor/SplitScreenEditorView.swift; sourceTree = "<group>"; };',
        'B1000011 /* Models.swift */': 'B1000011 /* Models.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Core/Models/Models.swift; sourceTree = "<group>"; };',
        'B1000008 /* APIService.swift */': 'B1000008 /* APIService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Core/Services/APIService.swift; sourceTree = "<group>"; };',
        'FC03BDB62EDFE96500CA1203 /* LocalFormStorageService.swift */': 'FC03BDB62EDFE96500CA1203 /* LocalFormStorageService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Core/Services/LocalFormStorageService.swift; sourceTree = "<group>"; };',
        'B1000009 /* LocalStorageService.swift */': 'B1000009 /* LocalStorageService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Core/Services/LocalStorageService.swift; sourceTree = "<group>"; };',
        'B1000006 /* DocumentPickerService.swift */': 'B1000006 /* DocumentPickerService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Core/Services/DocumentPickerService.swift; sourceTree = "<group>"; };',
        'B1000007 /* ImagePickerService.swift */': 'B1000007 /* ImagePickerService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Core/Services/ImagePickerService.swift; sourceTree = "<group>"; };',
        'FC03BDB72EDFE96500CA1203 /* PDFKitRepresentedView.swift */': 'FC03BDB72EDFE96500CA1203 /* PDFKitRepresentedView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = UI/Components/PDFKitRepresentedView.swift; sourceTree = "<group>"; };',
        'B1000010 /* AnimatedGradientBackground.swift */': 'B1000010 /* AnimatedGradientBackground.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = UI/Components/AnimatedGradientBackground.swift; sourceTree = "<group>"; };',
        'B1000012 /* Theme.swift */': 'B1000012 /* Theme.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = UI/Theme/Theme.swift; sourceTree = "<group>"; };',
    }
    
    new_lines = []
    changes = 0
    
    for line in lines:
        updated = False
        for key, replacement in updates.items():
            if key in line and 'PBXFileReference' in line:
                # Replace the entire line
                indent = len(line) - len(line.lstrip())
                new_lines.append(' ' * indent + replacement + '\n')
                changes += 1
                updated = True
                print(f"  ✓ Updated {key.split('/*')[1].split('*/')[0].strip()}")
                break
        
        if not updated:
            new_lines.append(line)
    
    print(f"\n✍️  Writing updated project file")
    with open(pbxproj_path, 'w') as f:
        f.writelines(new_lines)
    
    print(f"✅ Successfully updated {changes} file references")
    print(f"\n🚀 Now building the project...")

if __name__ == '__main__':
    reorganize_pbxproj()
