#!/usr/bin/env python3
"""
Add new Swift files to Xcode project
"""

import sys
import os
import uuid

def add_files_to_pbxproj(pbxproj_path, files_to_add):
    """Add files to the Xcode project file"""
    
    with open(pbxproj_path, 'r') as f:
        content = f.read()
    
    # Generate UUIDs for new files
    file_refs = {}
    build_files = {}
    
    for file_path in files_to_add:
        file_name = os.path.basename(file_path)
        file_ref_uuid = uuid.uuid4().hex[:24].upper()
        build_file_uuid = uuid.uuid4().hex[:24].upper()
        
        file_refs[file_path] = {
            'ref_uuid': file_ref_uuid,
            'build_uuid': build_file_uuid,
            'name': file_name
        }
    
    # Find the PBXBuildFile section
    build_file_section_start = content.find('/* Begin PBXBuildFile section */')
    build_file_section_end = content.find('/* End PBXBuildFile section */')
    
    if build_file_section_start == -1 or build_file_section_end == -1:
        print("❌ Could not find PBXBuildFile section")
        return False
    
    # Add build file entries
    build_file_entries = []
    for file_path, info in file_refs.items():
        entry = f"\t\t{info['build_uuid']} /* {info['name']} in Sources */ = {{isa = PBXBuildFile; fileRef = {info['ref_uuid']} /* {info['name']} */; }};\n"
        build_file_entries.append(entry)
    
    # Insert build file entries
    insert_pos = build_file_section_end
    content = content[:insert_pos] + ''.join(build_file_entries) + content[insert_pos:]
    
    # Find the PBXFileReference section
    file_ref_section_start = content.find('/* Begin PBXFileReference section */')
    file_ref_section_end = content.find('/* End PBXFileReference section */')
    
    if file_ref_section_start == -1 or file_ref_section_end == -1:
        print("❌ Could not find PBXFileReference section")
        return False
    
    # Add file reference entries
    file_ref_entries = []
    for file_path, info in file_refs.items():
        rel_path = file_path.replace('documentAI/', '')
        entry = f"\t\t{info['ref_uuid']} /* {info['name']} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {info['name']}; sourceTree = \"<group>\"; }};\n"
        file_ref_entries.append(entry)
    
    # Insert file reference entries
    insert_pos = file_ref_section_end
    content = content[:insert_pos] + ''.join(file_ref_entries) + content[insert_pos:]
    
    # Find the PBXSourcesBuildPhase section
    sources_section_start = content.find('/* Begin PBXSourcesBuildPhase section */')
    sources_section_end = content.find('/* End PBXSourcesBuildPhase section */')
    
    if sources_section_start == -1 or sources_section_end == -1:
        print("❌ Could not find PBXSourcesBuildPhase section")
        return False
    
    # Find the files array in PBXSourcesBuildPhase
    files_array_start = content.find('files = (', sources_section_start)
    files_array_end = content.find(');', files_array_start)
    
    if files_array_start == -1 or files_array_end == -1:
        print("❌ Could not find files array in PBXSourcesBuildPhase")
        return False
    
    # Add source file entries
    source_entries = []
    for file_path, info in file_refs.items():
        entry = f"\t\t\t\t{info['build_uuid']} /* {info['name']} in Sources */,\n"
        source_entries.append(entry)
    
    # Insert source entries
    insert_pos = files_array_end
    content = content[:insert_pos] + ''.join(source_entries) + content[insert_pos:]
    
    # Write back
    with open(pbxproj_path, 'w') as f:
        f.write(content)
    
    return True

if __name__ == '__main__':
    pbxproj_path = 'documentAI.xcodeproj/project.pbxproj'
    
    files_to_add = [
        'documentAI/Extensions/PDFDocument+AcroForm.swift',
        'documentAI/Features/DocumentEditor/QuickLookPDFView.swift'
    ]
    
    print("📝 Adding files to Xcode project...")
    for f in files_to_add:
        print(f"  - {f}")
    
    if add_files_to_pbxproj(pbxproj_path, files_to_add):
        print("✅ Files added successfully!")
        print("\n💡 Note: You may need to clean and rebuild the project")
    else:
        print("❌ Failed to add files")
        sys.exit(1)
