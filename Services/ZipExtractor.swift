//
//  ZipExtractor.swift
//  offlineweb
//
//  Created by Robin Lovoj on 09/11/25.
//

import Foundation
#if canImport(ZIPFoundation)
import ZIPFoundation
#endif

class ZipExtractor {
    static func extract(
        zipFile: URL,
        to destination: URL,
        onProgress: ((String, Int, Int) -> Void)? = nil
    ) throws {
        let fileManager = FileManager.default
        
        // Create destination directory
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        
        #if canImport(ZIPFoundation)
        // Using ZipFoundation
        guard let archive = Archive(url: zipFile, accessMode: .read) else {
            throw NSError(domain: "ZipExtractor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open ZIP archive"])
        }
        
        // Get total entries for progress calculation
        let totalEntries = archive.reduce(0) { count, _ in count + 1 }
        var currentEntry = 0
        
        print("📦 Extracting ZIP archive with \(totalEntries) entries...")
        
        for entry in archive {
            currentEntry += 1
            let entryPath = entry.path
            
            // Skip macOS junk files
            if entryPath.contains("__MACOSX") || entryPath.contains("/._") {
                continue
            }
            
            // Report progress with full path (like Android logs)
            onProgress?(entryPath, currentEntry, totalEntries)
            
            // Build full destination path
            let entryURL = destination.appendingPathComponent(entryPath)
            
            // Log extraction (like Android format)
            if currentEntry % 100 == 0 || currentEntry == totalEntries {
                print("📦 Extracting: fileName=\(entryPath), extractedCount=\(currentEntry), totalFiles=\(totalEntries)")
            }
            
            if entry.type == .directory {
                try fileManager.createDirectory(at: entryURL, withIntermediateDirectories: true)
            } else {
                // Create parent directory if needed
                try fileManager.createDirectory(at: entryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                
                // Extract file
                try archive.extract(entry, to: entryURL)
                
                // Log important files
                if entryPath.hasSuffix(".glb") {
                    print("✅ GLB Extracted: \(entryURL.path)")
                }
                
                // Log dist folder structure (verify it's being created)
                if entryPath.hasPrefix("dist/") && currentEntry % 500 == 0 {
                    print("📁 Dist file extracted: \(entryPath) -> \(entryURL.path)")
                }
            }
        }
        
        print("✅ ZIP extraction complete!")
        #else
        // Error: ZipFoundation package required
        throw NSError(
            domain: "ZipExtractor",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: """
                Please add ZipFoundation package:
                
                1. In Xcode: File > Add Package Dependencies
                2. Enter URL: https://github.com/weichsel/ZIPFoundation
                3. Select version: Up to Next Major Version
                4. Click Add Package
                5. The code will automatically use ZipFoundation once added
                """
            ]
        )
        #endif
    }
}

