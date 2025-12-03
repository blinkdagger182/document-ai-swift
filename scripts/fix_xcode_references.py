#!/usr/bin/env python3
"""
Fix Xcode project file references to point to organized folder structure
"""

import re
import sys
from pathlib import Path

# File mappings: old path -> new path
FILE_MAPPINGS = {
    'DocumentAIApp.swift': 'App/DocumentAIApp.swift',
    'HomeView.swift': 'Features/Home/HomeView.swift',
    'HomeViewModel.swift': 'Features/Home/HomeViewModel.swift',
    'FillDocumentView.swift': 'Features/DocumentEditor/FillDocumentView.swift',
    'FillDocumentViewModel.swift': 'Features/DocumentEditor/FillDocumentViewModel.swift',
    'DocumentViewModel.swift': 'Features/DocumentEditor/DocumentViewModel.swift',
    'SplitScreenEditorView.swift': 'Features/DocumentEditor/SplitScreenEditorView.swift',
    'Models.swift': 'Core/Models/Models.swift',
    'APIService.swift': 'Core/Services/APIService.swift',
    'LocalFormStorageService.swift': 'Core/Services/LocalFormStorageService.swift',
    'LocalStorageService.swift': 'Core/Services/LocalStorageService.swift',
    'DocumentPickerService.swift': 'Core/Services/DocumentPickerService.swift',
    'ImagePickerService.swift': 'Core/Services/ImagePickerService.swift',
    'PDFKitRepresentedView.swift': 'UI/Components/PDFKitRepresentedView.swift',
    'AnimatedGradientBackground.swift': 'UI/Components/AnimatedGradientBackground.swift',
    'Theme.swift': 'UI/Theme/Theme.swift',
}

def fix_pbxproj():
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    pbxproj_path = project_root / 'documentAI.xcodeproj' / 'project.pbxproj'
    
    if not pbxproj_path.exists():
        print(f"❌ Error: {pbxproj_path} not found")
        sys.exit(1)
    
    print(f"📝 Reading {pbxproj_path}")
    with open(pbxproj_path, 'r') as f:
        content = f.read()
    
    original_content = content
    changes_made = 0
    
    # Fix file paths
    for old_file, new_path in FILE_MAPPINGS.items():
        # Pattern: path = "OldFile.swift";
        pattern = f'path = "{old_file}";'
        replacement = f'path = "{new_path}";'
        
        if pattern in content:
            content = content.replace(pattern, replacement)
            changes_made += 1
            print(f"  ✓ Updated {old_file} → {new_path}")
    
    if changes_made == 0:
        print("✅ No changes needed - project file already up to date")
        return
    
    # Backup original
    backup_path = pbxproj_path.with_suffix('.pbxproj.backup')
    print(f"\n💾 Creating backup at {backup_path}")
    with open(backup_path, 'w') as f:
        f.write(original_content)
    
    # Write updated content
    print(f"✍️  Writing updated project file")
    with open(pbxproj_path, 'w') as f:
        f.write(content)
    
    print(f"\n✅ Successfully updated {changes_made} file references")
    print(f"📦 Backup saved to {backup_path}")
    print("\n🚀 Next: Build the project in Xcode (⌘B)")

if __name__ == '__main__':
    fix_pbxproj()
