#!/usr/bin/env python3
"""
Automatically update Xcode project with new Swift files
"""

import os
import sys
import subprocess
from pathlib import Path

def find_swift_files(directory):
    """Find all Swift files in directory"""
    swift_files = []
    for root, dirs, files in os.walk(directory):
        # Skip hidden directories and build folders
        dirs[:] = [d for d in dirs if not d.startswith('.') and d not in ['build', 'DerivedData']]
        
        for file in files:
            if file.endswith('.swift'):
                file_path = os.path.join(root, file)
                swift_files.append(file_path)
    
    return swift_files

def get_project_files_from_pbxproj(pbxproj_path):
    """Extract currently referenced files from project.pbxproj"""
    referenced_files = set()
    
    try:
        with open(pbxproj_path, 'r') as f:
            content = f.read()
            # Simple extraction - look for .swift file references
            for line in content.split('\n'):
                if '.swift' in line and 'path =' in line:
                    # Extract filename from path = "filename.swift";
                    parts = line.split('path = ')
                    if len(parts) > 1:
                        filename = parts[1].split(';')[0].strip('"')
                        referenced_files.add(filename)
    except Exception as e:
        print(f"Error reading pbxproj: {e}")
    
    return referenced_files

def main():
    # Get project root
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    
    # Paths
    documentai_dir = project_root / 'documentAI'
    xcodeproj = project_root / 'documentAI.xcodeproj'
    pbxproj = xcodeproj / 'project.pbxproj'
    
    if not xcodeproj.exists():
        print(f"❌ Xcode project not found at {xcodeproj}")
        sys.exit(1)
    
    print("🔍 Scanning for Swift files...")
    swift_files = find_swift_files(documentai_dir)
    
    print(f"📁 Found {len(swift_files)} Swift files")
    
    # Get currently referenced files
    referenced = get_project_files_from_pbxproj(pbxproj)
    
    # Find new files
    new_files = []
    for file_path in swift_files:
        filename = os.path.basename(file_path)
        if filename not in referenced:
            new_files.append(file_path)
    
    if not new_files:
        print("✅ All Swift files are already in the Xcode project")
        return
    
    print(f"\n📝 Found {len(new_files)} new files to add:")
    for file in new_files:
        rel_path = os.path.relpath(file, project_root)
        print(f"  - {rel_path}")
    
    print("\n⚠️  Manual Action Required:")
    print("Please add these files to Xcode manually:")
    print("1. Open documentAI.xcodeproj in Xcode")
    print("2. Right-click on documentAI folder → 'Add Files to documentAI...'")
    print("3. Select the files listed above")
    print("4. Uncheck 'Copy items if needed'")
    print("5. Check 'Add to targets: documentAI'")
    print("6. Click 'Add'")
    
    # Alternative: Use xcodebuild if available
    print("\n💡 Tip: You can also drag and drop the files from Finder into Xcode")

if __name__ == '__main__':
    main()
